//
//  TodoModel.swift
//  Observation Framework
//
//  Created by Jeet on 08/07/24.
//

import Foundation

// MARK: - TodoModel
struct toDoModel: Codable {
    var userId, id: Int
    var title: String
    var completed: Bool

    enum CodingKeys: String, CodingKey {
        case userId
        case id, title, completed
    }
}
