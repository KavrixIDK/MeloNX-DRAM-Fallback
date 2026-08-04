//
//  IsJITEnabled.swift
//  MeloNX
//
//  Created by Stossy11 on 10/02/2025.
//

import Foundation
import Darwin
import MachO
import Metal

@_silgen_name("vm_remap") func vm_remap(
    _ target_task: mach_port_t,
    _ target_address: UnsafeMutablePointer<mach_vm_address_t>,
    _ size: mach_vm_size_t,
    _ mask: mach_vm_offset_t,
    _ flags: Int32,
    _ src_task: mach_port_t,
    _ src_address: mach_vm_address_t,
    _ copy: boolean_t,
    _ cur_protection: UnsafeMutablePointer<vm_prot_t>,
    _ max_protection: UnsafeMutablePointer<vm_prot_t>,
    _ inheritance: vm_inherit_t
) -> kern_return_t

@_silgen_name("vm_protect") func vm_protect(
    _ target_task: mach_port_t,
    _ address: mach_vm_address_t,
    _ size: mach_vm_size_t,
    _ set_maximum: boolean_t,
    _ new_protection: vm_prot_t
) -> kern_return_t

@_silgen_name("sys_icache_invalidate")
func sys_icache_invalidate(_ start: UnsafeMutableRawPointer, _ size: Int)

let CS_DEBUGGED = 0x10000000

@_silgen_name("csops")
func csops(pid: Int32, ops: Int32, useraddr: UnsafeMutableRawPointer?, usersize: Int32) -> Int32

func jitEnabled(_ runDualMapped: Bool = false) -> Bool {
    if checkAppEntitlement("dynamic-codesigning") {
        return allocateTest()
    }
    
    if #available(iOS 19, *) {
        return checkDebugged() && RyujinxController.attemptToMapDualMapping()
    } else {
        return checkDebugged() && allocateTest()
    }
}

func checkDebugged() -> Bool {
    var flags: Int = 0
    if checkAppEntitlement("dynamic-codesigning") {
        return true
    }
    return csops(pid: getpid(), ops: 0, useraddr: &flags, usersize: Int32(MemoryLayout.size(ofValue: flags))) == 0 && (flags & Int(CS_DEBUGGED)) != 0
}

func checkMemoryPermissions(at address: UnsafeRawPointer) -> Bool {
    var region: vm_address_t = vm_address_t(UInt(bitPattern: address))
    var regionSize: vm_size_t = 0
    var info = vm_region_basic_info_64()
    var infoCount = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_64>.size / MemoryLayout<integer_t>.size)
    var objectName: mach_port_t = UInt32(MACH_PORT_NULL)
    
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
            vm_region_64(mach_task_self_, &region, &regionSize, VM_REGION_BASIC_INFO_64, $0, &infoCount, &objectName)
        }
    }
    
    if result != KERN_SUCCESS {
        // print("Failed to reach \(address)")
        return false
    }
    
    return info.protection & VM_PROT_EXECUTE != 0
}

func testDualMappedExecution() -> Bool {
    let pageSize = UInt(vm_page_size)

    let rawMmap = mmap(nil, Int(pageSize), PROT_READ | PROT_EXEC, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0)
    guard let rxBase = rawMmap, rxBase != MAP_FAILED else {
        return false
    }

    defer { munmap(rxBase, Int(pageSize)) }

    let bufRX = mach_vm_address_t(UInt(bitPattern: rxBase))
    var bufRW: mach_vm_address_t = 0
    var curProt: vm_prot_t = 0
    var maxProt: vm_prot_t = 0

    let remapResult = vm_remap(
        mach_task_self_,
        &bufRW,
        mach_vm_size_t(pageSize),
        0,
        VM_FLAGS_ANYWHERE,
        mach_task_self_,
        bufRX,
        0,
        &curProt,
        &maxProt,
        VM_INHERIT_NONE
    )
    guard remapResult == KERN_SUCCESS else {
        return false
    }

    defer { munmap(UnsafeMutableRawPointer(bitPattern: UInt(bufRW)), Int(pageSize)) }

    let protectResult = vm_protect(
        mach_task_self_,
        bufRW,
        mach_vm_size_t(pageSize),
        0,
        VM_PROT_READ | VM_PROT_WRITE
    )
    guard protectResult == KERN_SUCCESS else {
        return false
    }

    let code: [UInt8] = [
        0x40, 0x05, 0x80, 0xD2,  // mov x0, #42
        0xC0, 0x03, 0x5F, 0xD6   // ret
    ]

    guard let rwPtr = UnsafeMutableRawPointer(bitPattern: UInt(bufRW)) else {
        return false
    }

    rwPtr.copyMemory(from: code, byteCount: code.count)
    
    sys_icache_invalidate(rxBase, Int(pageSize))

    let result = execute_function_pointer(rxBase)

    return result == 42
}

func allocateTest() -> Bool {
    let pageSize = sysconf(_SC_PAGESIZE)
    let code: [UInt32] = [0x52800540, 0xD65F03C0]
    
    guard let jitMemory = mmap(nil, pageSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0), jitMemory != MAP_FAILED else {
        return false
    }
    
    defer {
        munmap(jitMemory, pageSize)
    }
    
    
    memcpy(jitMemory, code, code.count)
    
    _ = mprotect(jitMemory, pageSize, PROT_READ | PROT_EXEC)
    
    let checkMem = checkMemoryPermissions(at: jitMemory)
    
    return checkMem
}

// thank you nikki (nythepegasus)
extension FileManager {
    func filePath(atPath path: String, withLength length: Int) -> String? {
        guard let file = try? contentsOfDirectory(atPath: path).filter({ $0.count == length }).first else { return nil }
        return "\(path)/\(file)"
    }
}

enum DeviceCpu {
    case mseries
    case aseries
}

struct ChipInfo {
    let series: DeviceCpu
    let number: Int
}


public extension ProcessInfo {
    var hasTXMClassic: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac ? false :
        { if let boot = FileManager.default.filePath(atPath: "/System/Volumes/Preboot", withLength: 36), let file = FileManager.default.filePath(atPath: "\(boot)/boot", withLength: 96) { return access("\(file)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0 } else { return (FileManager.default.filePath(atPath: "/private/preboot", withLength: 96).map { access("\($0)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0 }) ?? false } }()
    }
    
    var hasTXM: Bool {
        if #available(iOS 27, *) {
            let lastNonTXM = 12 // A12
            let chipInfo = parseChipInfo()
            
            if let info = chipInfo, info.series == .aseries {
                return info.number > lastNonTXM
            }
            
            return true
        }
        
        if #available(iOS 26.6, *), !hasTXMClassic {
            let firstTXM = 15 // A15
            let iPadTXM = 2 // M2
            let chipInfo = parseChipInfo()
            
            if let info = chipInfo {
                if info.series == .mseries {
                    return info.number >= iPadTXM
                } else {
                    return info.number >= firstTXM
                }
            }
            
            return false
        }
        
        return hasTXMClassic
    }
    
    private func parseChipInfo() -> ChipInfo? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        
        let name = device.name.uppercased()
        
        let pattern = "APPLE\\s+([MA])(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
            let letterRange = Range(match.range(at: 1), in: name),
            let numberRange = Range(match.range(at: 2), in: name),
            let number = Int(name[numberRange])
        else { return nil }
        
        switch name[letterRange] {
        case "M":
            return ChipInfo(series: .mseries, number: number)
        case "A":
            return ChipInfo(series: .aseries, number: number)
        default:
            return nil
        }
    }
}

