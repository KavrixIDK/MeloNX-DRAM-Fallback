//
//  Pre26Slider.swift
//  MeloNX
//
//  Created by Stossy11 on 3/1/2026.
//

import SwiftUI

struct Pre26Slider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    
    var trackHeight: CGFloat = 6
    var thumbSize: CGFloat = 24
    
    private func normalizedValue(width: CGFloat) -> CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * width
    }
    
    private func steppedValue(from locationX: CGFloat, width: CGFloat) -> Float {
        let percent = min(max(locationX / width, 0), 1)
        let rawValue = range.lowerBound + Float(percent) * (range.upperBound - range.lowerBound)
        let stepped = (rawValue / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)
                
                // Filled Track
                Capsule()
                    .fill(Color.blue)
                    .frame(width: normalizedValue(width: width),
                           height: trackHeight)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 2)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: normalizedValue(width: width) - thumbSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                value = steppedValue(
                                    from: gesture.location.x,
                                    width: width
                                )
                            }
                    )
            }
            .frame(height: max(trackHeight, thumbSize))
        }
        .frame(height: 40)
    }
}

