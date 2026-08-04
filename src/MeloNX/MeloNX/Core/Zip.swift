//
//  Zip.swift
//  MeloNX
//
//  Created by Stossy11 on 13/7/2026.
//

import Foundation

@_silgen_name("zip_extract")
private func c_zip_extract(
    _ zipPath: UnsafePointer<CChar>?,
    _ destPath: UnsafePointer<CChar>?,
    _ overwrite: Int32
) -> Int32

@_silgen_name("zip_entry_count")
private func c_zip_entry_count(_ zipPath: UnsafePointer<CChar>?) -> Int32

@_silgen_name("zip_get_last_error")
private func c_zip_get_last_error() -> UnsafePointer<CChar>?

@_silgen_name("zip_free_string")
private func c_zip_free_string(_ ptr: UnsafePointer<CChar>?)

public enum ZipError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case zipSlip(String)
    case failure(String)
    
    public var description: String {
        switch self {
        case .fileNotFound(let msg), .zipSlip(let msg), .failure(let msg):
            return msg
        }
    }
}

public enum Zip {
    public static func extract(zipPath: String, destination: String, overwrite: Bool = true) throws {
        let result = zipPath.withCString { zipPtr in
            destination.withCString { destPtr in
                c_zip_extract(zipPtr, destPtr, overwrite ? 1 : 0)
            }
        }
        
        if result != 0 {
            throw makeError(forCode: result)
        }
    }
    
    public static func entryCount(zipPath: String) throws -> Int {
        let result = zipPath.withCString { zipPtr in
            c_zip_entry_count(zipPtr)
        }
        
        if result < 0 {
            throw makeError(forCode: result)
        }
        return Int(result)
    }
    
    private static func makeError(forCode code: Int32) -> ZipError {
        let message = lastErrorMessage()
        switch code {
        case -1: return .fileNotFound(message)
        case -2: return .zipSlip(message)
        default:  return .failure(message)
        }
    }
    
    private static func lastErrorMessage() -> String {
        guard let ptr = c_zip_get_last_error() else { return "Unknown error" }
        defer { c_zip_free_string(ptr) }
        return String(cString: ptr)
    }
}
