//
//  EditAccount.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//


import Foundation
import SwiftUI

struct EditAccount: View {
    @Binding var account: Account?
    
    @State private var name: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var isPickerPresented = false
    @State var isSelected: (Bool, Bool) = (false, false)
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        if let account {
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
                        } else if let base64String = account.image,
                                  let imageData = Data(base64Encoded: base64String),
                                  let image = UIImage(data: imageData) {
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
                    
                    
                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(name.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(name.isEmpty)
                    
                    Spacer()
                }
                .padding(.top)
                .navigationTitle("Edit Profile")
                .onAppear {
                    name = account.name
                }
            }
        }
    }
    
    func saveChanges() {
        if name.isEmpty { return }
        guard let account else { return }
        
        self.account?.name = name
        if let selectedImage {
            let imageData = selectedImage.jpgData() ?? Data()
            self.account?.image = imageData.base64EncodedString()
        }
        
        presentationMode.wrappedValue.dismiss()
        print("Account Updated for \(account.name)")
    }
}
