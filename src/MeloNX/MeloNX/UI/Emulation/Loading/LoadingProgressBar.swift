//
//  LoadingProgressBar.swift
//  MeloNX
//
//  Created by Stossy11 on 07/11/2025.
//

import SwiftUI
import UIKit
 
final class LoadingProgressBarView: UIView {
    var clumpWidth: CGFloat = 40 {
        didSet {
            guard clumpWidth != oldValue else { return }
            setNeedsLayout()
        }
    }
    
    var totalProgress: Int = 1 {
        didSet { updateProgressFill(animated: false) }
    }
    
    var currentProgress: Int = 0 {
        didSet { updateProgressFill(animated: true) }
    }
    
    var isShaderOrPTC: Bool = false {
        didSet {
            guard isShaderOrPTC != oldValue else { return }
            refreshState()
        }
    }
    
    var isAnimating: Bool = false {
        didSet {
            guard isAnimating != oldValue else { return }
            refreshState()
        }
    }
    
    private let trackView = UIView()
    private let clumpView = UIView()
    private let progressView = UIView()
    
    private var isRunningIndeterminateAnimation = false
    private var lastAnimatedBoundsWidth: CGFloat = -1
    private var lastAnimatedClumpWidth: CGFloat = -1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        clipsToBounds = true
        layer.cornerRadius = 10
        
        trackView.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
        addSubview(trackView)
        
        clumpView.backgroundColor = .systemBlue
        clumpView.alpha = 0
        addSubview(clumpView)
        
        progressView.backgroundColor = .systemBlue
        progressView.isHidden = true
        addSubview(progressView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        trackView.frame = bounds
        
        clumpView.frame.size = CGSize(width: clumpWidth, height: bounds.height)
        if !isRunningIndeterminateAnimation {
            clumpView.frame.origin.x = -clumpWidth
        }
        
        updateProgressFill(animated: false)
        
        if isAnimating && !isShaderOrPTC {
            startIndeterminateAnimationIfNeeded()
        }
    }
    
    private func refreshState() {
        if isAnimating && !isShaderOrPTC {
            clumpView.alpha = 1
            startIndeterminateAnimationIfNeeded()
        } else {
            clumpView.alpha = 0
            stopIndeterminateAnimation()
        }
        
        progressView.isHidden = !isShaderOrPTC
        if isShaderOrPTC {
            updateProgressFill(animated: false)
        }
    }
    
    private func startIndeterminateAnimationIfNeeded() {
        guard bounds.width > 0 else { return }
        
        if isRunningIndeterminateAnimation, lastAnimatedBoundsWidth == bounds.width, lastAnimatedClumpWidth == clumpWidth {
            return
        }
        
        isRunningIndeterminateAnimation = true
        lastAnimatedBoundsWidth = bounds.width
        lastAnimatedClumpWidth = clumpWidth
        
        clumpView.layer.removeAnimation(forKey: "indeterminate")
        
        let startX = -clumpWidth
        let endX = bounds.width
        clumpView.frame.origin.x = startX
        
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = startX + clumpWidth / 2
        animation.toValue = endX + clumpWidth / 2
        animation.duration = 1.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        clumpView.layer.add(animation, forKey: "indeterminate")
    }
    
    private func stopIndeterminateAnimation() {
        isRunningIndeterminateAnimation = false
        lastAnimatedBoundsWidth = -1
        lastAnimatedClumpWidth = -1
        clumpView.layer.removeAnimation(forKey: "indeterminate")
        clumpView.frame.origin.x = -clumpWidth
    }
    
    private func updateProgressFill(animated: Bool) {
        guard isShaderOrPTC, bounds.width > 0 else { return }
        
        let ratio = CGFloat(currentProgress) / CGFloat(max(totalProgress, 1))
        let width = bounds.width * ratio
        
        let apply = {
            self.progressView.frame = CGRect(x: 0, y: 0, width: width, height: self.bounds.height)
        }
        
        if animated {
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveLinear, animations: apply)
        } else {
            apply()
        }
    }
}
 
struct LoadingProgressBar: UIViewRepresentable {
    let screenGeometry: GeometryProxy
    @Binding var isAnimating: Bool
    @Binding var isShaderOrPTC: Bool
    @Binding var currentProgress: Int
    @Binding var totalProgress: Int
    let clumpWidth: CGFloat
    
    private var containerWidth: CGFloat {
        min(screenGeometry.size.width * 0.35, 350)
    }
    
    private var barHeight: CGFloat {
        min(screenGeometry.size.height * 0.015, 12)
    }
    
    func makeUIView(context: Context) -> LoadingProgressBarView {
        LoadingProgressBarView()
    }
    
    func updateUIView(_ uiView: LoadingProgressBarView, context: Context) {
        uiView.isShaderOrPTC = isShaderOrPTC
        uiView.clumpWidth = clumpWidth
        uiView.totalProgress = totalProgress
        uiView.currentProgress = currentProgress
        uiView.isAnimating = isAnimating
    }
    
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LoadingProgressBarView, context: Context) -> CGSize? {
        CGSize(width: containerWidth, height: barHeight)
    }
}
