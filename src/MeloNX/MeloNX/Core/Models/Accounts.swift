//
//  Accounts.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//

import Foundation
import UIKit

struct Profiles: Codable {
    var id: String { profiles.map(\.user_id).joined() }
    var profiles: [Account]
    var last_opened: String
}

struct Account: Codable, Identifiable {
    var id: String { user_id }
    var user_id: String
    var name: String
    var account_state: String
    var last_modified_timestamp: Int
    var image: String?
}

struct Avatar: Identifiable {
    var id: String { name }
    var icon: UIImage
    var name: String
}
