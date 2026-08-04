//
//  FirmwareView.swift
//  MeloNX
//
//  Created by Stossy11 on 6/7/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct FirmwareView: View {
    var goForward: () -> Void
    
    var fileImporter: FileImporterManager = .shared
    let ryujinxController: RyujinxController = .shared
    let fileManager: FileManager = .default
    
    @State var fwAdded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center) {
                Spacer()
                    .frame(height: 110)
                
                Image(systemName: "folder.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 120))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 120)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .blue.opacity(0.6),
                                        .red.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 6)
                
                Text("Import Firmware")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding()
                
                Text("Import Encryption Firmware via \(AppEnvironment.shared.needsAsCopy ? "Zip or XCI" : "Zip, Folder or XCI").\nRequired to be dumped from a Modded Nintendo Switch.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                ContinueButton(text: "Import", action: importFirmware, success: fwAdded, enabled: .constant(!fwAdded))
                    .padding()
            }
        }
        .padding()
        .onAppear(perform: checkForFirmware)
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
            Color.clear
                .frame(height: 80)
                .ignoresSafeArea()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                        .frame(width: .infinity, height: .infinity)
                )
                .overlay(alignment: .bottom) {
                    ContinueButton(text: "Finish!", action: goForward, enabled: .constant(true))
                        .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                            view
                                .padding(.bottom)
                        }
                }
        }
    }
    
    func importFirmware() {
        fileImporter.importFiles(types: [.item, .folder], allowMultiple: false) { result in
            ryujinxController.handleFirmwareImport(result: result)
            checkForFirmware()
        }
    }
    
    func checkForFirmware() {
        fwAdded = ryujinxController.firmwareInstalled
    }
}
