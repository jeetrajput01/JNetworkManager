//
//  ContentViewVM.swift
//  Observation Framework
//
//  Created by Jeet on 08/07/24.
//

import Foundation
import Combine
import JNetworkManager

@Observable
class ContentViewViewModel {

    var isShowLoader:Bool = false
    
    var errorMessage:String = ""
    
    
    
}



//MARK: -  new async/await
extension ContentViewViewModel {
    
    @MainActor
    func getAllData() {
        
        Task {
            
            self.isShowLoader = true
            
            defer {
                self.isShowLoader = false
                
                if self.errorMessage == "" {
                  print("APi call successfully.")
                } else {
                    print(self.errorMessage)
                }
    
            }
            
            let userUrl = apiUrl.user.route
            let todoUrl = apiUrl.todos.route
            
            let (userData, todoData) = await (
                JNetworkManager.makeAsyncRequest(url: userUrl, method: .get, parameter: nil, type: [userModel].self),
                JNetworkManager.makeAsyncRequest(url: todoUrl, method: .get, parameter: nil, type: [toDoModel].self)
            )
            
            switch userData {
            case .success(let userData):
                dump(userData)
            case .failure(let failure):
                self.handle(error: failure)
            }
            
            switch todoData {
            case .success(let todoData):
                break
            case .failure(let failure):
                self.handle(error: failure)
            }
            
        }
        
    }
    
    @MainActor
    func getBrandData() {
        
        Task {
            
            self.isShowLoader = true
            
            defer {
                self.isShowLoader = false
            }
    
            let brandResponse = await JNetworkManager.makeAsyncRequest(url: apiUrl.brand.route, method: .get, parameter: nil, type: [brandModel].self)
            
            switch brandResponse {
            case .success(let success):
                dump(success)
            case .failure(let failure):
                self.handle(error: failure)
            }
        }
          
    }
    
}



//MARK: - Error handle
extension ContentViewViewModel {
    
    private func handle(error: Error) {
        if let networkError = error as? NetworkError {
            self.errorMessage = networkError.localizedDescription
            switch networkError {
            case .invalidURL:
                print(networkError.localizedDescription)
            case .responseError(let statusCode):
                print("\(networkError.localizedDescription), \(statusCode)")
            case .unknown:
                print(networkError.localizedDescription)
            case .authentication:
                print(networkError.localizedDescription)
            case .timeout:
                print(networkError.localizedDescription)
            case .noInternet:
                print(networkError.localizedDescription)
            }
        }
    }
    
}
