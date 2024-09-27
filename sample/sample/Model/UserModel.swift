//
//  UserModel.swift
//  Observation Framework
//
//  Created by Jeet on 08/07/24.
//

import Foundation

//MARK: - userModel
struct userModel: Codable {
    var id: Int
    var name, username, email: String
}

// MARK: - Address
struct Address: Codable {
    var street, suite, city, zipcode: String
    var geo: Geo
}

// MARK: - Geo
struct Geo: Codable {
    var lat, lng: String
}

// MARK: - Company
struct Company: Codable {
    var name, catchPhrase, bs: String
}
