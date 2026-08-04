//
//  InfoButton.swift
//  MeloNX
//
//  Created by Stossy11 on 22/12/2025.
//

import SwiftUI

struct InfoButton: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .buttonStyle(.plain)
        .alert(title, isPresented: $isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
