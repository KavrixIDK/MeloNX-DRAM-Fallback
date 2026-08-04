//
//  SliderRow.swift
//  MeloNX
//
//  Created by Stossy11 on 8/5/2026.
//

import SwiftUI

struct SliderRow: View {
    let label: String
    let value: Binding<Float>
    let range: ClosedRange<Float>
    let step: Float
    let minLabel: String
    let maxLabel: String
    let format: String
    let extended: String?
    @ObservedObject private var settings = NativeSettingsManager.shared

    init(_ label: String,
         value: Binding<Float>,
         range: ClosedRange<Float>,
         step: Float,
         minLabel: String,
         maxLabel: String,
         format: String = "%.2f",
         extended: String? = nil) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.format = format
        self.extended = extended
    }

    var displayValue: String {
        let v = String(format: format, value.wrappedValue) + "x"
        if let ext = extended { return "\(v) \(ext)" }
        return v
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(displayValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            if settings.disableLiquidGlass.value {
                Pre26Slider(value: value, range: range, step: step)
            } else {
                Slider(value: value, in: range, step: step)
            }
            HStack {
                Text(minLabel).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(maxLabel).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
    }
}
