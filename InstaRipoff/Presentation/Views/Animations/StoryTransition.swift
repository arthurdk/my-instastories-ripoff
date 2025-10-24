//
//  StoryTransition.swift
//  InstaRipoff
//
//  Created on 23/10/2025.

import SwiftUI

struct CubeTransformModifier: ViewModifier {
    let translation: CGFloat
    let width: CGFloat
    let maxRotateAngle: CGFloat
    let isLeftView: Bool
    
    func body(content: Content) -> some View {
        let k = translation / width
        
        let rotationAngle: CGFloat
        let translateX: CGFloat
        let translateZ: CGFloat
        
        if translation > 0 {
            // Scrolling to the left side (revealing left view)
            if isLeftView {
                // Left view: -angle -> 0
                let r2 = k * maxRotateAngle
                let r = r2 - maxRotateAngle
                let gap1 = width / 2.0 * (1 - cos(r))
                rotationAngle = r
                translateX = translation + gap1
                translateZ = sin(r) * width / 2
            } else {
                // Right view (current): 0 -> -angle
                let r2 = k * maxRotateAngle
                let gap2 = width / 2.0 * (1 - cos(r2))
                rotationAngle = r2
                translateX = translation - gap2
                translateZ = -sin(r2) * width / 2
            }
        } else if translation < 0 {
            // Scrolling to the right side (revealing right view)
            if isLeftView {
                // Left view (current): 0 -> angle (negative k means positive rotation)
                let r = k * maxRotateAngle
                let gapWidth1 = width / 2.0 * (1 - cos(r))
                rotationAngle = r
                translateX = translation + gapWidth1
                translateZ = sin(r) * width / 2
            } else {
                // Right view: angle -> 0
                let r2 = maxRotateAngle + k * maxRotateAngle
                let gapWidth2 = width / 2.0 * (1 - cos(r2))
                rotationAngle = r2
                translateX = translation - gapWidth2
                translateZ = -sin(r2) * width / 2
            }
        } else {
            // No translation
            rotationAngle = 0
            translateX = 0
            translateZ = 0
        }
        
        return content
            .offset(x: translateX, y: 0)
            .rotation3DEffect(
                .radians(Double(rotationAngle)),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.0
            )
            .modifier(ProjectionTransform3D(translateZ: translateZ))
    }
}

// MARK: - 3D Projection Transform

/// Custom modifier to apply Z-axis translation with proper 3D projection
struct ProjectionTransform3D: GeometryEffect {
    var translateZ: CGFloat
    
    var animatableData: CGFloat {
        get { translateZ }
        set { translateZ = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        var transform = CATransform3DIdentity
        
        // Apply perspective (m34) - matches CubeAnimation
        let screenWidth = UIScreen.main.bounds.width
        transform.m34 = -1.0 / (screenWidth * 2.0)
        
        // Apply Z translation
        transform = CATransform3DTranslate(transform, 0, 0, translateZ)
        
        return ProjectionTransform(transform)
    }
}
