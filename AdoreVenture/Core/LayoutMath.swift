//
//  LayoutMath.swift
//  Shared CGFloat guards so SwiftUI / CoreGraphics never receive NaN or infinity.
//

import CoreGraphics

extension Double {
    /// Star ratings from AI / Firestore; keeps SwiftUI/CoreGraphics from seeing NaN or absurd values.
    var avSanitizedStarRating: Double {
        guard isFinite, !isNaN else { return 4.5 }
        return min(5.0, max(1.0, self))
    }

    /// For `Circle.trim`, `ProgressView(value:)`, and any 0…1 drawing. NaN/±∞ → 0 (unlike `min(1,max(0,x))`, which keeps NaN).
    var avClampedUnitInterval: Double {
        guard isFinite else { return 0 }
        return min(1, max(0, self))
    }
}

extension CGFloat {
    /// Use for frames, alignment guides, and any value passed into CoreGraphics.
    var sanitizedForLayout: CGFloat {
        guard isFinite, !isNaN else { return 0 }
        return Swift.max(0, self)
    }

    /// NaN/±∞ → 0; finite negatives preserved (e.g. custom alignment stacks).
    var finiteOnly: CGFloat {
        guard isFinite, !isNaN else { return 0 }
        return self
    }
}
