//
//  LoadingProgressBar.swift
//  MeloNX
//
//  Created by Stossy11 on 07/11/2025.
//

import SwiftUI

struct LoadingProgressBar: View {
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
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: containerWidth, height: barHeight)
            
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue)
                .frame(width: clumpWidth, height: barHeight)
                .offset(x: isAnimating ? containerWidth : -clumpWidth)
                .animation(
                    Animation.linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .opacity(isAnimating && !isShaderOrPTC ? 1 : 0)
            
            if isShaderOrPTC {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
                    .frame(
                        width: containerWidth * CGFloat(currentProgress) / CGFloat(max(totalProgress, 1)),
                        height: barHeight
                    )
                    .animation(.linear(duration: 0.1), value: currentProgress)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: containerWidth, height: barHeight)
    }
}
