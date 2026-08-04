//
//  NativeToggleRow.swift
//  MeloNX
//
//  Created by Stossy11 on 8/5/2026.
//

import SwiftUI

struct NativeToggleRow: View {
    let icon: String
    let label: String
    let infoMessage: String?
    let isOn: Binding<Bool>
    
    init(_ label: String, icon: String, isOn: Binding<Bool>, info: String? = nil) {
        self.label = label
        self.icon = icon
        self.isOn = isOn
        self.infoMessage = info
    }
    
    var body: some View {
        Toggle(isOn: isOn) {
            NativeLabelRow(label, icon: icon, info: infoMessage)
        }
    }
}

struct NativeLabelRow: View {
    let icon: String
    let label: String
    let infoMessage: String?
    
    init(_ label: String, icon: String, info: String? = nil) {
        self.label = label
        self.icon = icon
        self.infoMessage = info
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Label(label, systemImage: icon)
            if let msg = infoMessage {
                InfoButton(title: label, message: msg)
                    .padding(.leading, 4)
            }
        }
    }
}
