//
//  ControllerRow.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct ControllerRow: View {
    let index: Int
    let controllerId: String
    @ObservedObject var controllerManager: ControllerManager
    @EnvironmentObject var ryujinxController: RyujinxController

    private var controller: BaseController? {
        controllerManager.controllerAndIndexForString(controllerId)?.0
    }

    private var controllerIndex: Int? {
        controllerManager.controllerAndIndexForString(controllerId)?.1
    }

    var body: some View {
        guard let controller else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.accentColor)

                    Text("Player \(index + 1): \(controller.name)")
                        .lineLimit(1)

                    Spacer()

                    Button {
                        controllerManager.toggleController(controller)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)

            }
            .contextMenu {
                ForEach(ControllerType.allCases) { type in
                    if ryujinxController.settings.controllerType(for: index) == type {
                        Button {
                            updateControllerType(to: type)
                        } label: {
                            Label(type.displayName, systemImage: "checkmark")
                        }
                    } else {
                        Button(type.displayName) {
                            updateControllerType(to: type)
                        }
                        .tag(type.rawValue)
                    }
                }
            }
        )
    }

    private func updateControllerType(to type: ControllerType) {
        switch index {
        case 0: ryujinxController.settings.controllerType1 = type
        case 1: ryujinxController.settings.controllerType2 = type
        case 2: ryujinxController.settings.controllerType3 = type
        case 3: ryujinxController.settings.controllerType4 = type
        case 4: ryujinxController.settings.controllerType5 = type
        case 5: ryujinxController.settings.controllerType6 = type
        case 6: ryujinxController.settings.controllerType7 = type
        default: break
        }
    }
}
