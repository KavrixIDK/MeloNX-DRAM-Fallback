//
//  LabeledRow.swift
//  MeloNX
//
//  Created by Stossy11 on 8/5/2026.
//

import SwiftUI

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
