//
//  AccountSelector.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//

import SwiftUI

fileprivate var coolwow: CGFloat {
    if UIDevice.current.userInterfaceIdiom == .phone {
        return (UIScreen.main.bounds.width > UIScreen.main.bounds.height) ? 0.8 : 1.2
    } else {
        return 1.2
    }
}

struct AccountSelector: View {
    @State var callback: (Bool) -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var profiles: Profiles? = nil
    let profilePath = URL.documentsDirectory.appendingPathComponent("system").appendingPathComponent("Profiles.json")
    
    var body: some View {
        Group {
            if let profiles {
                VStack {
                    HStack {
                        Text("Select a user.")
                            .font(.title3)
                            .onTapGesture {
                                callback(true)
                            }
                            .padding(.leading, 20)
                        
                        Spacer()
                    }
                    Divider()
                    
                    Spacer()
                    
                    
                    CenterScrollView(profiles.profiles) { profile in
                        Button {
                            if profiles.last_opened != profile.user_id {
                                Ryujinx.closeUser(userId: profiles.last_opened)
                                
                                Ryujinx.openUser(userId: profile.user_id)
                            }
                            
                            if profiles.last_opened == profile.user_id {
                                callback(true)
                            }
                            
                            loadAccounts()
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(colorScheme == .light ? Color(UIColor.systemGray) : Color(UIColor.systemGray4))
                                    .frame(width: coolwow * 150, height: coolwow * 200)
                                    .overlay {
                                        VStack {
                                            if let base64String = profile.image,
                                               let imageData = Data(base64Encoded: base64String),
                                               let image = UIImage(data: imageData) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: coolwow * 150, height: coolwow * 150)
                                            }
                                            
                                            Spacer(minLength: 0)
                                            
                                            Text(profile.name)
                                                .multilineTextAlignment(.center)
                                            
                                            Spacer(minLength: 0)
                                        }
                                    }
                                    .border(profiles.last_opened == profile.user_id ? Color.blue : Color.gray, width: 1.5)
                            }
                            .foregroundStyle(Color.primary)
                        }
                    }
                    
                    Spacer()
                    
                    Divider()
                    HStack {
                        
                        Image(systemName: "formfitting.gamecontroller")
                            .font(.title3)
                            .padding(.leading, 18)
                            .padding(.top, 5)
                        
                        Spacer()
                        
                        Text("Cancel")
                            .font(.title3)
                            .onTapGesture {
                                callback(false)
                            }
                            .padding(.trailing, 20)
                        
                        Text("OK")
                            .font(.title3)
                            .onTapGesture {
                                callback(true)
                            }
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
        .onAppear() {
            loadAccounts()
        }
    }
    
    func loadAccounts() {
        do {
            let data = try Data(contentsOf: profilePath)
            profiles = try JSONDecoder().decode(Profiles.self, from: data)
        } catch {
            print("Failed to load profiles: \(error)")
            callback(false)
        }
    }
}



struct CenterScrollView<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let itemContent: (Item) -> ItemView
    let spacing: CGFloat
    let itemWidth: CGFloat
    let showsIndicators: Bool
    
    init(
        _ items: [Item],
        itemWidth: CGFloat = coolwow * 150,
        spacing: CGFloat = 10,
        showsIndicators: Bool = false,
        @ViewBuilder itemContent: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.itemContent = itemContent
        self.spacing = spacing
        self.itemWidth = itemWidth
        self.showsIndicators = showsIndicators
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: showsIndicators) {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    HStack(spacing: spacing) {
                        ForEach(items) { item in
                            itemContent(item)
                                .frame(width: itemWidth)
                        }
                    }
                    .padding(.horizontal, geometry.size.width / 2 - (itemWidth * CGFloat(items.count)) / 2)
                } else {
                    HStack(spacing: spacing) {
                        ForEach(items) { item in
                            itemContent(item)
                                .frame(width: itemWidth)
                        }
                    }
                    .padding(.horizontal, geometry.size.width / 2 - ((itemWidth * CGFloat(items.count)) + 50) / 2)
                }
            }
        }
    }
}
