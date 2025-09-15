//
//  CurlGenerator.swift
//  QuickReports
//
//  Created by differenz53 on 15/09/25.
//


import Foundation


/// Utility to generate Postman/Terminal-ready cURL commands for any URLRequest type.
public struct CurlGenerator {
    
    /// Generate a cURL string from a standard `URLRequest` (GET, POST with JSON body, etc.)
    public static func from(urlRequest: URLRequest) -> String {
        var components = ["curl"]

        // Method
        if let method = urlRequest.httpMethod {
            components.append("-X \(method)")
        }

        // Headers
        if let headers = urlRequest.allHTTPHeaderFields {
            for (key, value) in headers {
                components.append("-H '\(key): \(value)'")
            }
        }

        // Body (JSON, urlencoded, etc.)
        if let httpBody = urlRequest.httpBody,
           let bodyString = String(data: httpBody, encoding: .utf8),
           !bodyString.isEmpty {
            let escaped = bodyString.replacingOccurrences(of: "'", with: "\\'")
            components.append("-d '\(escaped)'")
        }

        // URL
        if let url = urlRequest.url {
            components.append("'\(url.absoluteString)'")
        }

        return components.joined(separator: " \\\n\t")
    }
    
    /// Generate a cURL string for a form-data or multipart request
    public static func fromMultipart(
        url: String,
        method: String,
        headers: [String: String],
        parameters: [String: Any]?,
        mediaObjects: [String: [mediaObject]]?
    ) -> String {
        
        var components = ["curl"]
        
        // Method
        components.append("-X \(method)")
        
        // Headers
        for (key, value) in headers {
            components.append("-H '\(key): \(value)'")
        }
        
        // Parameters (simple fields)
        if let params = parameters {
            for (key, value) in params {
                components.append("-F '\(key)=\(value)'")
            }
        }
        
        // Media files
        if let mediaObjects = mediaObjects {
            for (fieldName, files) in mediaObjects {
                for file in files {
                    components.append("-F '\(fieldName)=@\(file.filename);type=\(file.mimeType)'")
                }
            }
        }
        
        // URL
        components.append("'\(url)'")
        
        return components.joined(separator: " \\\n\t")
    }
}

