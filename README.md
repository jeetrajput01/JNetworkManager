# JNetworkManager
Network manager wrapper for alamofire

**JNetworkManager** is a Swift package that simplifies making asynchronous network requests using Alamofire. It provides a set of utility functions to handle standard and multipart requests with ease, while managing error handling and response parsing seamlessly.

## Features
- **Asynchronous Requests:** Easily make asynchronous API calls with support for Codable types.
- **File Uploads:** Upload multipart form data, including files and parameters, with progress tracking.
- **Error Handling:** Comprehensive error handling for network-related issues, including timeouts and invalid URLs.
- **Customizable Timeout:** Set custom timeout intervals for requests.

## Usage
**Making an Asynchronous Request**
```swift
let result = await NetworkManager.makeAsyncRequest(url: "https://api.example.com/data", method: .get)
switch result {
case .success(let data):
    print("Data received: \(data)")
case .failure(let error):
    print("Error occurred: \(error.localizedDescription)")
}
```
**Uploading Files**
```swift
let mediaObject = mediaObject(type: .other, data: fileData, filename: "file.txt", mimeType: "text/plain")
let result = await NetworkManager.makeAsyncUploadRequest(url: "https://api.example.com/upload", method: .post, parameter: ["key": "value"], mediaObj: ["file": mediaObject])

switch result {
case .success(let response):
    print("Upload successful: \(response)")
case .failure(let error):
    print("Upload failed: \(error.localizedDescription)")
}
```

## Error Handling
The package provides a comprehensive error handling mechanism. It differentiates between various error types, including:
- No Internet Connection
- Authentication Errors
- Timeout Errors
- Invalid URLs

## Contributing
Contributions are welcome! Please feel free to submit issues and pull requests.

## License
This project is licensed under the MIT License.
