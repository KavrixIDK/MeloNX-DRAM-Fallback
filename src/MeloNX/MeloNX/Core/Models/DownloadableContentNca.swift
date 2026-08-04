//
//  DownloadableContentNca.swift
//  MeloNX
//
//  Created by Stossy11 on 1/6/2026.
//

import Foundation


struct DownloadableContentNca: Codable, Hashable {
    var fullPath: String
    var titleId: UInt64
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case fullPath = "path"
        case titleId = "title_id"
        case enabled = "is_enabled"
    }
}

struct DownloadableContentContainer: Codable, Hashable, Identifiable {
    var id: String { containerPath }
    var containerPath: String
    var downloadableContentNcaList: [DownloadableContentNca]
    
    var filename: String {
        (containerPath as NSString).lastPathComponent
    }
    
    var isEnabled: Bool {
        downloadableContentNcaList.first?.enabled == true
    }

    enum CodingKeys: String, CodingKey {
        case containerPath = "path"
        case downloadableContentNcaList = "dlc_nca_list"
    }
}
