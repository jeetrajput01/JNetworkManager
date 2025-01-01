import XCTest
@testable import JNetworkManager

final class JNetworkManagerTests: XCTestCase {
    func testExample() async throws {
        
        // Act
        let result = await JNetworkManager.makeAsyncRequest(
            url: "https://jsonplaceholder.typicode.com/posts",
            method: .get,
            parameter: nil,
            type: [Post].self
        )
        
        // Assert
        switch result {
        case .success(let posts):
            XCTAssertGreaterThan(posts.count, 0, "Posts should not be empty")
        case .failure(let error):
            XCTFail("Request failed with error: \(error)")
        }

    }
    
    func testAnyAnyCodable() async throws {
        
        let result = await JNetworkManager.makeAsyncRequest(
            url: "https://jsonplaceholder.typicode.com/posts",
            method: .get,
            parameter: nil,
            type: AnyCodable.self
        )
        
        switch result {
        case .success(let success):
            if let value = success.value as? [[String:Any]] {
                let arrPosts = value.compactMap(Post.init)
                XCTAssertGreaterThan(arrPosts.count, 0, "Posts should not be empty")
            }
        case .failure(let failure):
            XCTFail("Request failed with error: \(failure)")
        }
        
        
    }
    
}

struct Post: Codable {
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
