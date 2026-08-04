//
//  MetalView.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//

import SwiftUI
import MetalKit

class MetalView: MTKView {
    @ObservedObject var menuViewShower: InGameConfigView_MenuView = .shared
    private var activeTouches: [UITouch] = []
    private var ignoredTouches: Set<UITouch> = []

    private var aspectRatio: AspectRatio = .fixed16x9

    func setAspectRatio() {
        self.aspectRatio = RyujinxController.shared.currentSettings.aspectRatio
        Ryujinx.setViewSize(self.bounds)
        updateUnboundedPresentTargetFps()
    }

    private func updateUnboundedPresentTargetFps() {
        Ryujinx.setUnboundedPresentTargetFps(for: window?.screen)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateUnboundedPresentTargetFps()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateUnboundedPresentTargetFps()
    }
    
    private func transformToTargetCoordinates(_ point: CGPoint) -> CGPoint {
        return point
    }

    private func getNextAvailableIndex() -> Int {
        return activeTouches.endIndex
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        menuViewShower.triggerButton()
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else { return }
        
        setAspectRatio()
        
        for touch in touches {
            let location = touch.location(in: self)
            let index = getNextAvailableIndex()
            activeTouches.append(touch)
            print("Touch location: \(location)")
            let transformed = transformToTargetCoordinates(location)
            Ryujinx.touchBegan(transformed, index: index)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else {
            for touch in touches {
                ignoredTouches.remove(touch)
                if let index = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: index)
                }
            }
            return
        }
        
        for touch in touches {
            if ignoredTouches.remove(touch) != nil {
                continue
            }
            
            if let touchIndex = activeTouches.firstIndex(where: { $0 == touch }) {
                Ryujinx.touchEnded(index: touchIndex)
                
                if let arrayIndex = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: arrayIndex)
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        menuViewShower.triggerButton()
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else { return }
        
        setAspectRatio()
        
        for touch in touches {
            if ignoredTouches.contains(touch), !activeTouches.contains(touch) {
                continue
            }
            
            
            guard let touchIndex = activeTouches.firstIndex(where: { $0 == touch }) else {
                continue
            }
            
            let location = touch.location(in: self)
            let transformed = transformToTargetCoordinates(location)
            Ryujinx.touchMoved(transformed, index: touchIndex)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else {
            for touch in touches {
                ignoredTouches.remove(touch)
                if let index = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: index)
                }
            }
            return
        }
        
        for touch in touches {
            if ignoredTouches.remove(touch) != nil {
                continue
            }
            
            if let touchIndex = activeTouches.firstIndex(where: { $0 == touch }) {
                Ryujinx.touchEnded(index: touchIndex)
                activeTouches.remove(at: touchIndex)
            }
        }
    }
    

    func resetTouchTracking() {
        activeTouches.removeAll()
        ignoredTouches.removeAll()
    }
}



struct MetalViewRepresentable: UIViewRepresentable {
    var showView: Bool
    
    init(showView: Bool = true) {
        self.showView = showView
    }
    
    func makeUIView(context: Context) -> UIView {
        if showView {
            return Self.createView()
        } else { return MetalView() }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
    
    @discardableResult
    static func createView() -> UIView {
        if Ryujinx.emulationView == nil {
            let view = MetalView()
            
            guard let metalLayer = view.layer as? CAMetalLayer else {
                fatalError("[Swift] Error: MTKView's layer is not a CAMetalLayer")
            }
            
            UIApplication.shared.isIdleTimerDisabled = true
            
            //metalLayer.presentsWithTransaction = false
            //metalLayer.allowsNextDrawableTimeout = false
            
            if metalLayer.device == nil {
                metalLayer.device = MTLCreateSystemDefaultDevice()
            }
            
            let layerPtr = Unmanaged.passUnretained(metalLayer).toOpaque()
            
            Ryujinx.setNativeWindow(layerPtr)
            Ryujinx.setUnboundedPresentTargetFps(for: view.window?.screen)
            
            Ryujinx.emulationView = view
            return view
        }
        
        return Ryujinx.emulationView!
    }
}
