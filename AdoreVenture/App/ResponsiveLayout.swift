import SwiftUI

// Responsive layout helper for consistent spacing and sizing across all iPhone types
struct ResponsiveLayout {
    static let screenWidth = UIScreen.main.bounds.width
    static let screenHeight = UIScreen.main.bounds.height
    
    // Device type detection based on actual iPhone dimensions
    static var isMiniDevice: Bool {
        // iPhone 13 mini, 12 mini, SE (3rd gen)
        return screenHeight <= 812 && screenWidth <= 375
    }
    
    static var isStandardDevice: Bool {
        // iPhone 13, 12, 11, XR, XS, X
        return screenHeight > 812 && screenHeight <= 844 && screenWidth <= 390
    }
    
    static var isPlusDevice: Bool {
        // iPhone 13 Pro Max, 12 Pro Max, 11 Pro Max, XS Max
        return screenHeight > 844 && screenWidth > 390
    }
    
    static var isLargeDevice: Bool {
        return isPlusDevice
    }
    
    static var isWideDevice: Bool {
        return screenWidth > 400
    }
    
    static var isCompactDevice: Bool {
        return isMiniDevice
    }
    
    // Responsive spacing
    static var standardSpacing: CGFloat {
        if isMiniDevice { return 18 }
        if isStandardDevice { return 24 }
        return 28 // Plus devices
    }
    
    static var compactSpacing: CGFloat {
        if isMiniDevice { return 14 }
        if isStandardDevice { return 18 }
        return 22 // Plus devices
    }
    
    static var tightSpacing: CGFloat {
        if isMiniDevice { return 8 }
        if isStandardDevice { return 12 }
        return 16 // Plus devices
    }
    
    // Responsive padding
    static var standardPadding: CGFloat {
        if isMiniDevice { return 18 }
        if isStandardDevice { return 22 }
        return 26 // Plus devices
    }
    
    static var compactPadding: CGFloat {
        if isMiniDevice { return 14 }
        if isStandardDevice { return 18 }
        return 22 // Plus devices
    }
    
    static var tightPadding: CGFloat {
        if isMiniDevice { return 12 }
        if isStandardDevice { return 16 }
        return 20 // Plus devices
    }
    
    // Responsive font sizes
    static func titleFontSize() -> CGFloat {
        if isMiniDevice { return 28 }
        if isStandardDevice { return 32 }
        return 36 // Plus devices
    }
    
    static func subtitleFontSize() -> CGFloat {
        if isMiniDevice { return 20 }
        if isStandardDevice { return 24 }
        return 28 // Plus devices
    }
    
    static func bodyFontSize() -> CGFloat {
        if isMiniDevice { return 14 }
        if isStandardDevice { return 16 }
        return 18 // Plus devices
    }
    
    static func captionFontSize() -> CGFloat {
        if isMiniDevice { return 12 }
        if isStandardDevice { return 14 }
        return 16 // Plus devices
    }
    
    // Responsive icon sizes
    static func largeIconSize() -> CGFloat {
        if isMiniDevice { return 70 }
        if isStandardDevice { return 80 }
        return 90 // Plus devices
    }
    
    static func mediumIconSize() -> CGFloat {
        if isMiniDevice { return 50 }
        if isStandardDevice { return 60 }
        return 70 // Plus devices
    }
    
    static func smallIconSize() -> CGFloat {
        if isMiniDevice { return 30 }
        if isStandardDevice { return 35 }
        return 40 // Plus devices
    }
    
    // Safe area handling (guard against NaN)
    static func topSafeArea() -> CGFloat {
        let top = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0
        return top.isFinite ? max(60, top + 20) : 60
    }
    
    static func bottomSafeArea() -> CGFloat {
        let bottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom ?? 0
        return bottom.isFinite ? max(40, bottom + 20) : 40
    }
}

// View extensions for easy responsive design
extension View {
    func responsivePadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, ResponsiveLayout.standardPadding)
    }
    
    func responsiveHorizontalPadding() -> some View {
        self.padding(.horizontal, ResponsiveLayout.standardPadding)
    }
    
    func responsiveSpacing() -> some View {
        self.padding(.vertical, ResponsiveLayout.standardSpacing)
    }
    
    func responsiveFont(_ style: Font.TextStyle) -> some View {
        self.font(.system(size: ResponsiveLayout.bodyFontSize(), weight: .regular))
    }
    
    func responsiveTitleFont() -> some View {
        self.font(.system(size: ResponsiveLayout.titleFontSize(), weight: .bold))
    }
    
    func responsiveSubtitleFont() -> some View {
        self.font(.system(size: ResponsiveLayout.subtitleFontSize(), weight: .semibold))
    }
}
