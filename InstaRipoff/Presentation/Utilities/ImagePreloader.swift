//
//  ImagePreloader.swift
//  InstaRipoff
//
//  Created on 24/10/2025.
//

import SwiftUI

@MainActor
class ImagePreloader: ObservableObject {
    static let shared = ImagePreloader()
    
    private var preloadedImages: [String: UIImage] = [:]
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    private var loadingPriority: [String: Int] = [:]
    private var currentPriority: Int = 0
    
    private let maxCachedImages = 40
    private let maxConcurrentLoads = 8
    
    private init() {}
    
    /// Preload an image from a URL with priority
    func preload(url: String, priority: Int = 0) {
        // Skip if already preloaded
        guard preloadedImages[url] == nil else {
            // Update priority if already loaded
            loadingPriority[url] = priority
            return
        }
        
        // Skip if currently loading
        guard preloadTasks[url] == nil else {
            return
        }
        
        // Respect concurrent load limit
        if preloadTasks.count >= maxConcurrentLoads {
            return
        }
        
        // Create preload task
        let task = Task {
            await loadImage(url: url, priority: priority)
        }
        preloadTasks[url] = task
    }
    
    /// Preload multiple images with descending priority
    func preload(urls: [String]) {
        for (index, url) in urls.enumerated() {
            // Higher priority for items closer to current position
            let priority = currentPriority - index
            preload(url: url, priority: priority)
        }
        currentPriority += 1
    }
    
    /// Batch preload with explicit priorities
    func preloadBatch(urls: [(url: String, priority: Int)]) {
        for item in urls {
            preload(url: item.url, priority: item.priority)
        }
    }
    
    private func loadImage(url: String, priority: Int) async {
        guard let imageUrl = URL(string: url) else {
            preloadTasks[url] = nil
            return
        }
        
        do {
            // Use URLSession with caching enabled
            var request = URLRequest(url: imageUrl)
            request.cachePolicy = .returnCacheDataElseLoad
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Verify it's a successful response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                preloadTasks[url] = nil
                return
            }
            
            // Cache the image with priority
            preloadedImages[url] = image
            loadingPriority[url] = priority
            print("✅ Preloaded [P\(priority)]: \(url.suffix(35))")
            
            // Trim cache if needed
            if preloadedImages.count > maxCachedImages {
                trimCacheByPriority()
            }
        } catch {
            // Silent fail for preloading (not critical)
            if !(error.localizedDescription.contains("cancelled")) {
                print("⚠️ Preload failed: \(url.suffix(30))")
            }
        }
        
        preloadTasks[url] = nil
    }
    
    /// Get a preloaded image if available
    func getPreloaded(url: String) -> UIImage? {
        return preloadedImages[url]
    }
    
    /// Check if an image is preloaded
    func isPreloaded(url: String) -> Bool {
        return preloadedImages[url] != nil
    }
    
    /// Clear all preloaded images to free memory
    func clearCache() {
        preloadedImages.removeAll()
        preloadTasks.values.forEach { $0.cancel() }
        preloadTasks.removeAll()
    }
    
    /// Trim cache based on priority (remove lowest priority items)
    private func trimCacheByPriority() {
        guard preloadedImages.count > maxCachedImages else { return }
        
        // Sort by priority (keep highest priority)
        let sortedByPriority = loadingPriority.sorted { $0.value > $1.value }
        let toRemove = sortedByPriority.suffix(preloadedImages.count - maxCachedImages)
        
        var removedCount = 0
        for (url, _) in toRemove {
            preloadedImages.removeValue(forKey: url)
            loadingPriority.removeValue(forKey: url)
            removedCount += 1
        }
        
        if removedCount > 0 {
            print("🧹 Trimmed \(removedCount) low-priority images (kept \(preloadedImages.count))")
        }
    }
    
    /// Clear old images beyond a certain limit to manage memory
    func trimCache(keepRecent: Int = 40) {
        guard preloadedImages.count > keepRecent else { return }
        
        trimCacheByPriority()
    }
    
    /// Get cache statistics
    func getCacheStats() -> (cached: Int, loading: Int) {
        return (preloadedImages.count, preloadTasks.count)
    }
}
