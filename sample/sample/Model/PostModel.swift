//
//  Post.swift
//  JNetworkManager
//
//  Created by differenz53 on 01/01/25.
//


struct PostModel: Codable {
    let id: Int
    let title: String
    let body: String
    
    init(id: Int, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
    
    init(dict: [String:Any]) {
        self.id = dict["id"] as? Int ?? 0
        self.title = dict["title"] as? String ?? ""
        self.body = dict["body"] as? String ?? ""
    }
    
}
