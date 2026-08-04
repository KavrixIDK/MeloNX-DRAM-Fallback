//
//  WelcomeView.swift
//  MeloNX
//
//  Created by Stossy11 on 7/7/2026.
//

import SwiftUI
import Foundation

// https://git.ryujinx.app/api/v1/repos/projects/MeloNX/releases/tags/2.3.1/

struct WelcomeView: View {
    var goForward: () -> Void
    
    @State var versionInformation: WhatsNewDoc?
    
    var versionNumber: String {
        " " + Bundle.main.versionNumber
    }
    
    var body: some View {
        Group {
            if let versionInformation {
                welcomeWithVerInfoView(versionInformation)
            } else {
                welcomeView
            }
        }
        .task {
            let versionInformation = try? await fetchRelease(tag: Bundle.main.versionNumber)
            
            guard let body = versionInformation?.body else { self.versionInformation = nil; return }
            self.versionInformation = parseWhatsNew(from: body)
        }
    }
    
    func welcomeWithVerInfoView(_ versionInformation: WhatsNewDoc) -> some View {
        ScrollView {
            VStack(alignment: .center) {
                Image(appIconBundle: .main)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .blue.opacity(0.6),
                                        .red.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 6)
                    .padding(.top, 60)
                
                Text("Welcome to MeloNX")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding()
            }
            
            Divider()
            
            Text(versionInformation.title + " In" + versionNumber)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top)
            
            VStack(alignment: .leading) {
                ForEach(versionInformation.sections) { info in
                    VStack(alignment: .leading) {
                        HStack {
                            Spacer()
                        }
                        
                        Text(info.heading)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding()
                        
                        
                        let text = "- " + info.bullets.joined(separator: "\n- ")
                        
                        Text(text)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.bottom)
                            .padding(.horizontal)
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
                    .frame(width: .infinity)
                    .padding()
                }
            }
            .padding(.bottom, 120)
        }
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
                        .shadow(radius: 20, x: 0, y: -20)
                )
                .overlay(alignment: .bottom) {
                    ContinueButton(text: "Continue", action: goForward, enabled: .constant(true))
                        .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                            view
                                .padding(.bottom)
                        }
                }
        }
    }
    
    var welcomeView: some View {
        VStack(alignment: .center) {
            Spacer()
                .frame(height: 110)
            
            Image(appIconBundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .overlay(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .blue.opacity(0.6),
                                    .red.opacity(0.6)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 6)
                .padding(.top, 60)
            
            Text("Welcome to MeloNX" + versionNumber)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding()
            
            Spacer()
        }
        .padding()
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
                        .shadow(radius: 20, x: 0, y: -20)
                )
                .overlay(alignment: .bottom) {
                    ContinueButton(text: "Continue", action: goForward, enabled: .constant(true))
                        .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                            view
                                .padding(.bottom)
                        }
                }
        }
    }
    
    func fetchRelease(owner: String = "projects", repo: String = "MeloNX", tag: String? = nil, instance: String = "git.ryujinx.app") async throws -> ForgejoRelease {
        let url = URL(string: "https://\(instance)/api/v1/repos/\(owner)/\(repo)/releases/tags/\(tag ?? Bundle.main.versionNumber)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ForgejoRelease.self, from: data)
    }
    
    func parseWhatsNew(from markdown: String) -> WhatsNewDoc {
        let lines = markdown.components(separatedBy: .newlines)
        
        var title = ""
        var sections: [MarkdownSection] = []
        
        var currentHeading: String?
        var currentBullets: [String] = []
        
        func flushSection() {
            if let heading = currentHeading {
                sections.append(MarkdownSection(heading: heading, bullets: currentBullets))
            } else if !currentBullets.isEmpty {
                sections.append(MarkdownSection(heading: "Misc", bullets: currentBullets))
            }
            currentHeading = nil
            currentBullets = []
        }
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            
            if line.hasPrefix("# ") {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("## ") {
                flushSection()
                currentHeading = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let bullet = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentBullets.append(bullet)
            }
        }
        
        flushSection()
        
        return WhatsNewDoc(title: title, sections: sections)
    }
}

struct ForgejoRelease: Codable {
    let id: Int
    let tagName: String
    let targetCommitish: String
    let name: String
    let body: String
    let url: String
    let htmlUrl: String
    let tarballUrl: String
    let zipballUrl: String
    let draft: Bool
    let prerelease: Bool
    let createdAt: Date
    let publishedAt: Date
    let author: ForgejoUser?
    let assets: [ForgejoAsset]
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case name
        case body
        case url
        case htmlUrl = "html_url"
        case tarballUrl = "tarball_url"
        case zipballUrl = "zipball_url"
        case draft
        case prerelease
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case author
        case assets
    }
}

struct ForgejoUser: Codable {
    let id: Int
    let login: String
    let fullName: String?
    let email: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case fullName = "full_name"
        case email
        case avatarUrl = "avatar_url"
    }
}

struct ForgejoAsset: Codable {
    let id: Int
    let name: String
    let size: Int
    let downloadCount: Int
    let browserDownloadUrl: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case downloadCount = "download_count"
        case browserDownloadUrl = "browser_download_url"
        case createdAt = "created_at"
    }
}

struct MarkdownSection: Identifiable {
    let id = UUID()
    let heading: String
    let bullets: [String]
}

struct WhatsNewDoc: Identifiable {
    let id = UUID()
    let title: String
    let sections: [MarkdownSection]
}
