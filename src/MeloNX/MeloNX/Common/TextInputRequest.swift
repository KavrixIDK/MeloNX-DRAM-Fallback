//
//  TextInputRequest.swift
//  MeloNX
//
//  Created by Stossy11 on 23/4/2026.
//

import Foundation

struct TextInputRequest: Decodable {
    let title: String
    let message: String
    let placeholder: String
    let callbackId: String
    
    enum CodingKeys: String, CodingKey {
        case title = "Title", message = "Message", placeholder = "Placeholder", callbackId = "CallbackId"
    }
}
