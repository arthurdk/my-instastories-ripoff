//
//  FilterPickerView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

enum FilterType: String, CaseIterable {
    case none = "None"
    case noir = "Noir"
    case chrome = "Chrome"
    case fade = "Fade"
    case instant = "Instant"
    case process = "Process"
    case transfer = "Transfer"
    case mono = "Mono"
    case tonal = "Tonal"
}

struct FilterPickerView: View {
    @Binding var selectedFilter: FilterType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(selectedFilter == filter ? Color.white : Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(filter.rawValue.prefix(1)))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(selectedFilter == filter ? .black : .white)
                            )
                        
                        Text(filter.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .onTapGesture {
                        selectedFilter = filter
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        .background(Color.black.opacity(0.7))
    }
}

// UIImage extension for filters
extension UIImage {
    func applyFilter(_ filterType: FilterType) -> UIImage? {
        guard let ciImage = CIImage(image: self) else { return nil }
        
        let filterName: String
        switch filterType {
        case .none:
            return self
        case .noir:
            filterName = "CIPhotoEffectNoir"
        case .chrome:
            filterName = "CIPhotoEffectChrome"
        case .fade:
            filterName = "CIPhotoEffectFade"
        case .instant:
            filterName = "CIPhotoEffectInstant"
        case .process:
            filterName = "CIPhotoEffectProcess"
        case .transfer:
            filterName = "CIPhotoEffectTransfer"
        case .mono:
            filterName = "CIPhotoEffectMono"
        case .tonal:
            filterName = "CIPhotoEffectTonal"
        }
        
        let context = CIContext()
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
