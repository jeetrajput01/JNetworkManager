//
//  File.swift
//  
//
//  Created by differenz53 on 02/10/24.
//

import Foundation
#warning("Need to add class decription")
class CacheManager {
    
    static let shared = CacheManager()
    private var cache: [String: (data: Data, timestamp: Date)] = [:]
    private let maxCacheSize: Int = 100 // Max number of entries in cache
    
    func getCachedResponse(for key: String) -> Data? {
        return cache[key]?.data
    }
    
    func isCacheValid(for key: String, expiryTime: TimeInterval) -> Bool {
        guard let entry = cache[key] else { return false }
        return abs(entry.timestamp.timeIntervalSinceNow) <= expiryTime
    }

    func cacheResponse(data: Data, for key: String) {
        // Cache the data and set the timestamp
        cache[key] = (data: data, timestamp: Date())
        
        // Enforce cache size limit
        if cache.count > maxCacheSize {
            // Remove oldest or least recently used entries
            clearOldestCacheEntries()
        }
    }
    
    func clearOldestCacheEntries() {
        // Sort the cache entries by timestamp (oldest first)
        let sortedCache = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        
        // Calculate how many entries need to be removed to maintain the cache size
        let excessCount = cache.count - maxCacheSize
        
        // Remove the oldest entries
        for (index, entry) in sortedCache.enumerated() where index < excessCount {
            cache.removeValue(forKey: entry.key)
        }
    }
    
}
