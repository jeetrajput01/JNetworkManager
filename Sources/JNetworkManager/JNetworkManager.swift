// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  JNetworkManager.swift
//
//
//   Created by Jeet on 25/09/24.
//

import Foundation
import Alamofire
import SystemConfiguration

public enum NetworkError: Error {
    case invalidURL
    case responseError(_ statusCode:Int)
    case unknown
    case authentication
    case timeout
    case noInternet
}


extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("Invalid URL", comment: "Invalid URL")
        case .responseError(let statusCode):
            return NSLocalizedString("Unexpected status code = \(statusCode)", comment: "Invalid response")
        case .unknown:
            return NSLocalizedString("Unknown error", comment: "Unknown error")
        case .authentication:
            return NSLocalizedString("Authentication is expired", comment: "Authentication error")
        case .timeout:
            return NSLocalizedString("Request timeout", comment: "Request timeout")
        case .noInternet:
            return NSLocalizedString("No Internet connecting", comment: "No Internet connecting")
        }
    }
}

public struct mediaObject {
    public var data: Data
    public var filename: String
    public var mimeType: String

    public init(data: Data, filename: String, mimeType: String) {
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
}
 
public class JNetworkManager {
    
    /// Asynchronously makes an API request using a generic `Codable` type for the response.
    ///
    /// This method performs an HTTP request with the specified parameters, decodes the response into the specified `Codable` type,
    /// and returns the result as a Swift `Result` type, which can either be success or failure.
    ///
    /// - Parameters:
    ///   - url: The URL string for the API request.
    ///   - method: The HTTP method to use for the request (e.g., GET, POST).
    ///   - parameter: The request parameters, provided as a dictionary of `[String: Any]`, optional.
    ///   - headers: The HTTP headers to include in the request, provided as a dictionary of `[String: String]`. The default is an empty dictionary.
    ///   - timeoutInterval: The timeout interval for the request in seconds. The default value is 30 seconds.
    ///   - type: The type conforming to `Codable` that the response should be decoded into.
    /// - Returns: An asynchronous result of type `Result<T, Error>`, where `T` is the specified `Codable` type. The result will either contain the decoded data on success, or an error on failure.
    public class func makeAsyncRequest<T:Codable>(url: String, method: HTTPMethod, parameter: [String:Any]?, headers: [String: String] = [:], timeoutInterval: TimeInterval = 30, type: T.Type) async -> Result<T,Error> {
        
        guard self.isInternetAvailable() else {
            return .failure(NetworkError.noInternet)
        }
        
        switch createURLRequest(url: url, method: method, headers: headers,parameters: parameter, timeoutInterval: timeoutInterval) {
        case .success(let urlRequest):
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    
                    AF.request(urlRequest)
                        .responseData(queue: .global(qos: .background)) { response in
                            
                            switch response.result {
                                
                            case .success(let responseData):
                                do {
                                    
                                    print(responseData.prettyPrintedJSONString ?? "")
                                    guard let httpResponse = response.response else {
                                        continuation.resume(returning: .failure(NetworkError.unknown))
                                        return
                                    }
                                    if httpResponse.statusCode == 200 {
                                        let data = try JSONDecoder().decode(T.self, from: responseData)
                                        continuation.resume(returning: .success(data))
                                    } else if httpResponse.statusCode == 401 {
                                        continuation.resume(returning: .failure(NetworkError.authentication))
                                    } else {
                                        continuation.resume(returning: .failure(NetworkError.responseError(httpResponse.statusCode)))
                                    }
                                    
                                } catch {
                                    print(error.localizedDescription)
                                    continuation.resume(returning: .failure(NetworkError.unknown))
                                }
                                
                            case .failure(let error):
                                print(error.localizedDescription)
                                if let afError = error.asAFError {
                                    if afError.isSessionTaskError || afError.isExplicitlyCancelledError {
                                        
                                        print("Request timed out.")
                                        continuation.resume(returning: .failure(NetworkError.timeout))
                                    } else {
                                        // Handle other AFErrors
                                        if let responseData = response.data {
                                            print("Failure response: \(responseData.prettyPrintedJSONString ?? String(decoding: responseData, as: UTF8.self))")
                                        }
                                        continuation.resume(returning: .failure(NetworkError.invalidURL))
                                    }
                                } else {
                                    // Handle non-AFError cases
                                    if let responseData = response.data {
                                        print("Failure response: \(responseData.prettyPrintedJSONString ?? String(decoding: responseData, as: UTF8.self))")
                                    }
                                    continuation.resume(returning: .failure(error))
                                }
                            }
                            
                        }
                }
                
            } catch {
                print(error.localizedDescription)
                return .failure(NetworkError.unknown)
                
            }
        case .failure(let error):
            return .failure(error)
        }
        
    }
    
    /// Asynchronously uploads a multipart form request with parameters and multiple media objects, and decodes the response into a specified `Codable` type.
    ///
    /// This function allows for the upload of files along with other parameters using a multipart form data request.
    /// It tracks the upload progress via a closure and returns the response as a `Result` type, which can be either success or failure.
    ///
    /// - Parameters:
    ///   - url: The URL string for the API request.
    ///   - method: The HTTP method to use for the request (e.g., POST, PUT).
    ///   - parameter: The request parameters, provided as a dictionary of `[String: Any]`, optional.
    ///   - mediaObjects: A dictionary where the key is a string and the value is an array of `mediaObject` instances to upload.
    ///   - headers: The HTTP headers to include in the request, provided as a dictionary of `[String: String]`. The default is an empty dictionary.
    ///   - timeoutInterval: The timeout interval for the request in seconds. The default value is 30 seconds.
    ///   - type: The type conforming to `Codable` that the response should be decoded into.
    ///   - progressHandler: A closure to handle progress updates, with the progress fraction passed as a `Double` (0.0 to 1.0). Optional.
    /// - Returns: An asynchronous result of type `Result<T, Error>`, where `T` is the specified `Codable` type. The result will either contain the decoded data on success, or an error on failure.
    @Sendable
    public class func makeAsyncUploadRequest<T: Codable>(url: String, method: HTTPMethod, parameter: [String: Any]?, mediaObjects: [String: [mediaObject]]? = nil, headers: [String: String] = [:], timeoutInterval: TimeInterval = 30, type: T.Type, progressHandler: ((Double) -> Void)? = nil) async -> Result<T, Error> {
        
        guard self.isInternetAvailable() else {
            return .failure(NetworkError.noInternet)
        }
        
        switch createURLRequest(url: url, method: method, headers: headers, timeoutInterval: timeoutInterval) {
            
        case .success(let urlRequest):
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    
                    AF.upload(multipartFormData: { multipartFormData in
                        
                        // Append parameters
                        if let params = parameter {
                            for (key, value) in params {
                                if let data = "\(value)".data(using: .utf8) {
                                    multipartFormData.append(data, withName: key)
                                }
                            }
                        }
                        
                        // Append multiple media objects
                        if let mediaObjects = mediaObjects {
                            for (key, mediaArray) in mediaObjects {
                                for media in mediaArray {
                                    multipartFormData.append(media.data, withName: key, fileName: media.filename, mimeType: media.mimeType)
                                }
                            }
                        }
                        
                    }, with: urlRequest)
                    .uploadProgress { progress in
                        progressHandler?(progress.fractionCompleted)
                    }
                    .responseData(queue: .global(qos: .background)) { response in
                        
                        switch response.result {
                            
                        case .success(let responseData):
                            do {
                                print(responseData.prettyPrintedJSONString ?? "")
                                guard let httpResponse = response.response else {
                                    continuation.resume(returning: .failure(NetworkError.unknown))
                                    return
                                }
                                if httpResponse.statusCode == 200 {
                                    let decodedData = try JSONDecoder().decode(T.self, from: responseData)
                                    continuation.resume(returning: .success(decodedData))
                                } else if httpResponse.statusCode == 401 {
                                    continuation.resume(returning: .failure(NetworkError.authentication))
                                } else {
                                    continuation.resume(returning: .failure(NetworkError.responseError(httpResponse.statusCode)))
                                }
                            } catch {
                                continuation.resume(returning: .failure(NetworkError.unknown))
                            }
                            
                        case .failure(let error):
                            handleAFError(error, response: response, continuation: continuation)
                        }
                    }
                }
            } catch {
                return .failure(NetworkError.unknown)
            }
        case .failure(let error):
            return .failure(error)
        }
        
    }

}

//MARK: - Without generic
extension JNetworkManager {
    
    /// Asynchronously performs an API request and returns the response as a generic result.
    ///
    /// This function sends an HTTP request to the specified URL using the provided HTTP method and parameters.
    /// It returns a `Result` type containing either the JSON response on success or an error on failure.
    /// The response is parsed into a generic `Any` type, which can be further cast to the desired type.
    ///
    /// - Parameters:
    ///   - url: The URL string for the API request.
    ///   - method: The HTTP method to use for the request (e.g., GET, POST).
    ///   - parameter: The request parameters, provided as a dictionary of `[String: Any]`, optional.
    ///   - headers: The HTTP headers to include in the request, provided as a dictionary of `[String: String]`. The default is an empty dictionary.
    ///   - timeoutInterval: The timeout interval for the request in seconds. The default value is 30 seconds.
    /// - Returns: An asynchronous result of type `Result<Any, Error>`. The result will either contain the parsed response on success, or an error on failure.
    public class func makeAsyncRequest(url: String, method: HTTPMethod, parameter: [String:Any]?,headers: [String: String] = [:],timeoutInterval: TimeInterval = 30) async -> Result<Any,Error> {
        
        guard self.isInternetAvailable() else {
            return .failure(NetworkError.noInternet)
        }
        
        switch createURLRequest(url: url, method: method, headers: headers,parameters: parameter, timeoutInterval: timeoutInterval) {
        case .success(let urlRequest):
            do {
                return try await withCheckedThrowingContinuation { continuation in
                  
                    AF.request(urlRequest)
                        .responseData(queue: .global(qos: .background)) { response in
                            
                            switch response.result {
                                
                            case .success(let responseData):
                                do {
                                    print(responseData.prettyPrintedJSONString ?? "")
                                    guard let httpResponse = response.response else {
                                        continuation.resume(returning: .failure(NetworkError.unknown))
                                        return
                                    }
                                    if httpResponse.statusCode == 200 {
                                        let response = try JSONSerialization.jsonObject(with: responseData)
                                        continuation.resume(returning: .success(response))
                                        
                                    } else if httpResponse.statusCode == 401 {
                                        continuation.resume(returning: .failure(NetworkError.authentication))
                                    } else {
                                        continuation.resume(returning: .failure(NetworkError.responseError(httpResponse.statusCode)))
                                    }
                                    
                                } catch {
                                    
                                    if let responseString = String(data: responseData, encoding: .utf8) {
                                        continuation.resume(returning: .success(responseString))
                                    } else {
                                        print("Parsing error: \(error.localizedDescription)")
                                        continuation.resume(returning: .failure(NetworkError.unknown))
                                    }
                                   
                                }
                                
                            case .failure(let error):
                                print(error.localizedDescription)
                                if let afError = error.asAFError {
                                    if afError.isSessionTaskError || afError.isExplicitlyCancelledError {
                                       
                                        print("Request timed out.")
                                        continuation.resume(returning: .failure(NetworkError.timeout))
                                    } else {
                                        // Handle other AFErrors
                                        if let responseData = response.data {
                                            print("Failure response: \(responseData.prettyPrintedJSONString ?? String(decoding: responseData, as: UTF8.self))")
                                        }
                                        continuation.resume(returning: .failure(NetworkError.invalidURL))
                                    }
                                } else {
                                    // Handle non-AFError cases
                                    if let responseData = response.data {
                                        print("Failure response: \(responseData.prettyPrintedJSONString ?? String(decoding: responseData, as: UTF8.self))")
                                    }
                                    continuation.resume(returning: .failure(error))
                                }
                            }
                            
                        }
                }
                
            } catch {
                print(error.localizedDescription)
                return .failure(NetworkError.unknown)
                
            }
        case .failure(let error):
            return .failure(error)
        }
        
        
    }
    
    /// Asynchronously uploads a multipart form request with parameters and a single media object, returning the response as a result.
    ///
    /// This function allows for the upload of a file (media object) alongside additional parameters using a multipart form data request.
    /// It provides a progress handler to monitor the upload progress and returns the server response in a `Result` type, which can be either success or failure.
    ///
    /// - Parameters:
    ///   - url: The URL string for the API request.
    ///   - method: The HTTP method to use for the request (e.g., POST, PUT).
    ///   - parameter: The request parameters, provided as a dictionary of `[String: Any]`, optional.
    ///   - mediaObj: A dictionary where the key is a string and the value is a `mediaObject` instance to upload.
    ///   - headers: The HTTP headers to include in the request, provided as a dictionary of `[String: String]`. The default is an empty dictionary.
    ///   - timeoutInterval: The timeout interval for the request in seconds. The default value is 30 seconds.
    ///   - progressHandler: A closure to handle progress updates, with the progress fraction passed as a `Double` (0.0 to 1.0). Optional.
    /// - Returns: An asynchronous result of type `Result<Any, Error>`. The result will either contain the parsed response on success, or an error on failure.
    @Sendable
    public class func makeAsyncUploadRequest(url: String, method: HTTPMethod, parameter: [String: Any]?, mediaObj: [String: mediaObject]?, headers: [String: String] = [:], timeoutInterval: TimeInterval = 30, progressHandler: ((Double) -> Void)? = nil) async -> Result<Any, Error> {
        
        guard self.isInternetAvailable() else {
            return .failure(NetworkError.noInternet)
        }
        
        switch createURLRequest(url: url, method: method, headers: headers, timeoutInterval: timeoutInterval) {
            
        case .success(let urlRequest):
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    
                    // Perform the upload
                    AF.upload(multipartFormData: { multipartFormData in
                        
                        // Append parameters
                        if let params = parameter {
                            for (key, value) in params {
                                if let data = "\(value)".data(using: .utf8) {
                                    multipartFormData.append(data, withName: key)
                                }
                            }
                        }
                        
                        // Append media objects
                        if let mediaObjects = mediaObj {
                            for (key, media) in mediaObjects {
                                multipartFormData.append(media.data, withName: key, fileName: media.filename, mimeType: media.mimeType)
                            }
                        }
                   
                    }, with: urlRequest)
                    .uploadProgress { progress in
                        progressHandler?(progress.fractionCompleted)
                    }
                    .responseData(queue: .global(qos: .background)) { response in
                        
                        switch response.result {
                            
                        case .success(let responseData):
                            do {
                                print(responseData.prettyPrintedJSONString ?? "")
                                guard let httpResponse = response.response else {
                                    continuation.resume(returning: .failure(NetworkError.unknown))
                                    return
                                }
                                if httpResponse.statusCode == 200 {
                                    let response = try JSONSerialization.jsonObject(with: responseData)
                                    continuation.resume(returning: .success(response))
                                } else if httpResponse.statusCode == 401 {
                                    continuation.resume(returning: .failure(NetworkError.authentication))
                                } else {
                                    continuation.resume(returning: .failure(NetworkError.responseError(httpResponse.statusCode)))
                                }
                            } catch {
                                continuation.resume(returning: .failure(NetworkError.unknown))
                            }
                            
                        case .failure(let error):
                            handleAFError(error, response: response, continuation: continuation)
                        }
                    }
                }
            } catch {
                return .failure(NetworkError.unknown)
            }
        case .failure(let error):
            return .failure(error)
            
        }
        
        
    }

    /// Asynchronously uploads a multipart form request with parameters and multiple media objects, returning the response as a result.
    ///
    /// This function allows for the upload of files (media objects) alongside additional parameters using a multipart form data request.
    /// It tracks the upload progress via a closure and returns the response in a `Result` type, which can be either success or failure.
    ///
    /// - Parameters:
    ///   - url: The URL string for the API request.
    ///   - method: The HTTP method to use for the request (e.g., POST, PUT).
    ///   - parameter: The request parameters, provided as a dictionary of `[String: Any]`, optional.
    ///   - mediaObjects: A dictionary where the key is a string and the value is an array of `mediaObject` instances to upload, optional.
    ///   - headers: The HTTP headers to include in the request, provided as a dictionary of `[String: String]`. The default is an empty dictionary.
    ///   - timeoutInterval: The timeout interval for the request in seconds. The default value is 30 seconds.
    ///   - progressHandler: A closure to handle progress updates, with the progress fraction passed as a `Double` (0.0 to 1.0). Optional.
    /// - Returns: An asynchronous result of type `Result<Any, Error>`. The result will either contain the parsed response on success, or an error on failure.
    @Sendable
    public class func makeAsyncUploadRequest(url: String, method: HTTPMethod, parameter: [String: Any]?, mediaObjects: [String: [mediaObject]]? = nil, headers: [String: String] = [:], timeoutInterval: TimeInterval = 30, progressHandler: ((Double) -> Void)? = nil) async -> Result<Any, Error> {
        
        guard self.isInternetAvailable() else {
            return .failure(NetworkError.noInternet)
        }
        
        switch createURLRequest(url: url, method: method, headers: headers, timeoutInterval: timeoutInterval) {
            
        case .success(let urlRequest):
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    
                    AF.upload(multipartFormData: { multipartFormData in
                        
                        // Append parameters
                        if let params = parameter {
                            for (key, value) in params {
                                if let data = "\(value)".data(using: .utf8) {
                                    multipartFormData.append(data, withName: key)
                                }
                            }
                        }
                        
                        // Append media objects
                        if let mediaObjects = mediaObjects {
                            for (key, mediaArray) in mediaObjects {
                                for media in mediaArray {
                                    multipartFormData.append(media.data, withName: key, fileName: media.filename, mimeType: media.mimeType)
                                }
                            }
                        }
                        
                    }, with: urlRequest)
                    .uploadProgress { progress in
                        progressHandler?(progress.fractionCompleted)
                    }
                    .responseData(queue: .global(qos: .background)) { response in
                        
                        switch response.result {
                            
                        case .success(let responseData):
                            do {
                                print(responseData.prettyPrintedJSONString ?? "")
                                guard let httpResponse = response.response else {
                                    continuation.resume(returning: .failure(NetworkError.unknown))
                                    return
                                }
                                if httpResponse.statusCode == 200 {
                                    let response = try JSONSerialization.jsonObject(with: responseData)
                                    continuation.resume(returning: .success(response))
                                } else if httpResponse.statusCode == 401 {
                                    continuation.resume(returning: .failure(NetworkError.authentication))
                                } else {
                                    continuation.resume(returning: .failure(NetworkError.responseError(httpResponse.statusCode)))
                                }
                            } catch {
                                continuation.resume(returning: .failure(NetworkError.unknown))
                            }
                            
                        case .failure(let error):
                            handleAFError(error, response: response, continuation: continuation)
                        }
                    }
                }
            } catch {
                return .failure(NetworkError.unknown)
            }
        case .failure(let error):
            return .failure(error)
            
        }
        
    }

}


//MARK: - Error handling
extension JNetworkManager {
    
    /// Handles errors returned by Alamofire during network requests.
    ///
    /// This function processes `AFError` instances and checks for specific error conditions, such as session task errors or explicit cancellations.
    /// It extracts error information from the `AFDataResponse` and resumes the given continuation with an appropriate failure result.
    ///
    /// - Parameters:
    ///   - error: The `AFError` instance representing the error that occurred during the request.
    ///   - response: The `AFDataResponse<Data>` that contains the response data and metadata associated with the failed request.
    ///   - continuation: A `CheckedContinuation<Result<Any, Error>, Error>` used to resume the asynchronous operation with the error result.
    private class func handleAFError(_ error: AFError, response: AFDataResponse<Data>, continuation: CheckedContinuation<Result<Any, Error>, Error>) {
        print("Request failed: \(error.localizedDescription)")
        if error.isSessionTaskError || error.isExplicitlyCancelledError {
            print("Request timed out.")
            continuation.resume(returning: .failure(NetworkError.timeout))
        } else {
            if let responseData = response.data, let errorString = String(data: responseData, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            continuation.resume(returning: .failure(NetworkError.unknown))
        }
    }
    
    /// Handles errors returned by Alamofire during network requests for a generic response type.
    ///
    /// This function processes `AFError` instances and checks for specific error conditions, such as session task errors or explicit cancellations.
    /// It extracts error information from the `AFDataResponse` and resumes the given continuation with an appropriate failure result.
    ///
    /// - Parameters:
    ///   - error: The `AFError` instance representing the error that occurred during the request.
    ///   - response: The `AFDataResponse<Data>` that contains the response data and metadata associated with the failed request.
    ///   - continuation: A `CheckedContinuation<Result<T, Error>, Error>` used to resume the asynchronous operation with the error result for a generic type `T`.
    private class func handleAFError<T>(_ error: AFError, response: AFDataResponse<Data>, continuation: CheckedContinuation<Result<T, Error>, Error>) {
        print("Request failed: \(error.localizedDescription)")
        
        if error.isSessionTaskError || error.isExplicitlyCancelledError {
            print("Request timed out.")
            continuation.resume(returning: .failure(NetworkError.timeout))
        } else {
            if let responseData = response.data, let errorString = String(data: responseData, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            continuation.resume(returning: .failure(NetworkError.unknown))
        }
    }

}


//MARK: - Create URLRequest
extension JNetworkManager {
    
    /// Creates a URL request with the specified parameters.
    ///
    /// This function constructs a `URLRequest` object using the provided URL string, HTTP method, headers, and timeout interval.
    /// It validates the URL and handles any errors that occur during the creation of the request.
    ///
    /// - Parameters:
    ///   - url: A string representing the URL for the request.
    ///   - method: The HTTP method to be used for the request (e.g., GET, POST).
    ///   - headers: A dictionary of HTTP headers to include in the request, represented as `[String: String]`.
    ///   - timeoutInterval: The timeout interval for the request in seconds.
    ///   - Parameters: The request parameters, provided as a dictionary of `[String: Any]`, optional.
    /// - Returns: A `Result` containing either the created `URLRequest` on success or an `Error` on failure.
    private class func createURLRequest(url: String, method: HTTPMethod, headers: [String: String],parameters: [String: Any]? = nil, timeoutInterval: TimeInterval) -> Result<URLRequest, Error> {
        guard let url = URL(string: url) else {
            return .failure(NetworkError.invalidURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.allHTTPHeaderFields = headers

        if let parameters = parameters {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
                urlRequest.httpBody = jsonData
            } catch {
                return .failure(NetworkError.unknown)
            }
        }
        
        return .success(urlRequest)
    }
    
}

//MARK: - Check internet connectivity
extension JNetworkManager {
    public class func isInternetAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafeMutablePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }

        var flags = SCNetworkReachabilityFlags()
        if let reachability = defaultRouteReachability {
            SCNetworkReachabilityGetFlags(reachability, &flags)
        }

        func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
            return flags.contains(.reachable) && !flags.contains(.connectionRequired)
        }

        return isNetworkReachable(with: flags)
    }
}
