//
//  AvatarGridView.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//

import SwiftUI

struct AvatarGridView: View {
    @State private var avatars: [Avatar] = []
    @State private var selectedColor: Color = .white
    @State private var showColorPicker = false
    @State private var showImagePicker = false
    @Environment(\.presentationMode) var presentationMode
    
    var onAvatarTap: (UIImage) -> Void
    
    private let minItemWidth: CGFloat = 50
    
    var body: some View {
        NavigationStack {
            let columns = [
                GridItem(.adaptive(minimum: minItemWidth), spacing: 16)
            ]
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(avatars) { avatar in
                        Button(action: {
                            if let newImage = avatar.icon.withBackground(color: UIColor(selectedColor)) {
                                onAvatarTap(newImage)
                            } else {
                                onAvatarTap(avatar.icon)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 50, height: 50)
                                    
                                    Image(uiImage: avatar.icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .onAppear() {
                avatars = Ryujinx.getFirmwareIcons()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ColorPicker("Select Color", selection: $selectedColor)
                        .padding()
                }
            }
            .popover(isPresented: $showColorPicker) {
                VStack {
                    Button("Done") {
                        showColorPicker = false
                    }
                    .padding()
                }
            }
        }
    }
}

extension UIImage {
    func withBackground(color: UIColor) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(color.cgColor)
        context.fill(rect)
        
        draw(in: rect)
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}
