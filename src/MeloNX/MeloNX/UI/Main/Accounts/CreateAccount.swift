//
//  CreateAccount.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//

import Foundation
import SwiftUI
import PhotosUI

struct CreateAccount: View {
    @State private var name: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var isPickerPresented = false
    @State var isSelected: (Bool, Bool) = (false, false)
    @Environment(\.presentationMode) var presentationMode
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Menu {
                    Button {
                        isSelected = (true, false)
                    } label: {
                        Label("Firmware Icons", image: "square.and.arrow.down")
                    }
                    
                    Button {
                        isSelected = (false, true)
                    } label: {
                        Label("Photos", image: "photo.circle")
                    }
                } label: {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 100, height: 100)
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .sheet(isPresented: $isSelected.0) {
                    AvatarGridView { avatar in
                        selectedImage = avatar
                    }
                }
                .sheet(isPresented: $isSelected.1) {
                    PhotoPicker(selectedImage: $selectedImage)
                }
                
                
                TextField("Enter Name", text: $name)
                    .padding()
                    .background(Color(.darkGray))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button(action: createAccount) {
                    Text("Create")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(name.isEmpty || selectedImage == nil ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(name.isEmpty || selectedImage == nil)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Create Profile")
        }
    }
    
    func createAccount() {
        if name.isEmpty { return }
        guard let selectedImage else { return }
        
        presentationMode.wrappedValue.dismiss()
        Ryujinx.createAccount(name: name, image: selectedImage.jpgData() ?? Data())
        print("Account Created for \(name)")
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                   Task { @MainActor in
                        let resized = self.resizeImage(image: image, targetSize: CGSize(width: 256, height: 256))
                        self.parent.selectedImage = resized
                    }
                }
            }
        }

        private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }
}
