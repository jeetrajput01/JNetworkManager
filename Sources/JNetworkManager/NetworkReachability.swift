//
//  NetworkManager.swift
//  
//
//  Created by Jeet on 25/09/24.
//

import SystemConfiguration

class NetworkReachability {

    static var shared = NetworkReachability()
    
    func isInternetAvailable() -> Bool {
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

