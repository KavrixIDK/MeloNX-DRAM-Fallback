//
//  KeyboardConfigView.swift
//  MeloNX
//
//  Created by Stossy11 on 23/6/2026.
//

import SwiftUI

func pullKeyboardConfig() -> KeyboardConfigNative {
    guard let data = try? Data(contentsOf: .keyboardConfigURL) else {
        return Ryujinx.defaultKeyboard
    }
    
    let decoder = JSONDecoder()
    guard let decoded = try? decoder.decode(KeyboardConfigNative.self, from: data) else {
        return Ryujinx.defaultKeyboard
    }
    
    return decoded
}

func writeKeyboardConfig(_ config: KeyboardConfigNative)  {
    let encoder = JSONEncoder()
    
    guard let data = try? encoder.encode(config) else { return }
    
    FileManager.default.createFile(atPath: URL.keyboardConfigURL.path, contents: data)
}

struct KeyboardConfigView: View {
    @State var keyboardConfig: KeyboardConfigNative = Ryujinx.defaultKeyboard
    @Environment(\.dismiss) var dismiss
 
    var body: some View {
        NavigationStack {
            List {
                Section("Right Joycon") {
                    KeyboardRightJoyconView(keyboardConfig: $keyboardConfig)
                }
                
                Section("Right Stick") {
                    KeyboardRightJoyconStickView(keyboardConfig: $keyboardConfig)
                }
                
                Section("Left Joycon") {
                    KeyboardLeftJoyconView(keyboardConfig: $keyboardConfig)
                }
                
                Section("Left Stick") {
                    KeyboardLeftJoyconStickView(keyboardConfig: $keyboardConfig)
                }
                
            }
            .navigationTitle("Keyboard Mapping")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.keyboardConfig = Ryujinx.defaultKeyboard
                        writeKeyboardConfig(self.keyboardConfig)
                        dismiss()
                    } label: {
                        Text("Reset")
                    }
                }
            }
            .onAppear() {
                self.keyboardConfig = pullKeyboardConfig()
            }
            .onDisappear {
                Ryujinx.setKeyboardConfig(self.keyboardConfig)
                writeKeyboardConfig(self.keyboardConfig)
            }
        }
    }
}


struct KeyboardLeftJoyconView: View {
    @Binding var keyboardConfig: KeyboardConfigNative
    
    var body: some View {
        Picker("DPad Up", selection: $keyboardConfig.LeftJoycon.DpadUp) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("DPad Down", selection: $keyboardConfig.LeftJoycon.DpadDown) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("DPad Left", selection: $keyboardConfig.LeftJoycon.DpadLeft) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        
        Picker("DPad Right", selection: $keyboardConfig.LeftJoycon.DpadRight) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Minus", selection: $keyboardConfig.LeftJoycon.ButtonMinus) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("L", selection: $keyboardConfig.LeftJoycon.ButtonL) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Zl", selection: $keyboardConfig.LeftJoycon.ButtonZl) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Sl", selection: $keyboardConfig.LeftJoycon.ButtonSl) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Sr", selection: $keyboardConfig.LeftJoycon.ButtonSr) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
    }
}

struct KeyboardLeftJoyconStickView: View {
    @Binding var keyboardConfig: KeyboardConfigNative
    
    var body: some View {
        Picker("Stick Up", selection: $keyboardConfig.LeftJoyconStick.StickUp) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Stick Down", selection: $keyboardConfig.LeftJoyconStick.StickDown) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Stick Left", selection: $keyboardConfig.LeftJoyconStick.StickLeft) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        
        Picker("Stick Right", selection: $keyboardConfig.LeftJoyconStick.StickRight) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Stick Button", selection: $keyboardConfig.LeftJoyconStick.StickButton) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
    }
}

struct KeyboardRightJoyconView: View {
    @Binding var keyboardConfig: KeyboardConfigNative
    
    var body: some View {
        Picker("A", selection: $keyboardConfig.RightJoycon.ButtonA) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("B", selection: $keyboardConfig.RightJoycon.ButtonB) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("X", selection: $keyboardConfig.RightJoycon.ButtonX) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        
        Picker("Y", selection: $keyboardConfig.RightJoycon.ButtonY) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Plus", selection: $keyboardConfig.RightJoycon.ButtonPlus) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("R", selection: $keyboardConfig.RightJoycon.ButtonR) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Zr", selection: $keyboardConfig.RightJoycon.ButtonZr) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Sl", selection: $keyboardConfig.RightJoycon.ButtonSl) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Sr", selection: $keyboardConfig.RightJoycon.ButtonSr) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
    }
}

struct KeyboardRightJoyconStickView: View {
    @Binding var keyboardConfig: KeyboardConfigNative
    
    var body: some View {
        Picker("Stick Up", selection: $keyboardConfig.RightJoyconStick.StickUp) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Stick Down", selection: $keyboardConfig.RightJoyconStick.StickDown) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Stick Left", selection: $keyboardConfig.RightJoyconStick.StickLeft) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        
        Picker("Stick Right", selection: $keyboardConfig.RightJoyconStick.StickRight) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
        
        Picker("Stick Button", selection: $keyboardConfig.RightJoyconStick.StickButton) {
            ForEach(Key.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .pickerStyle(.menu)
    }
}
