import SwiftUI
import AppKit

// Helper extension to convert NSColor to SwiftUI Color
extension Color {
    static func fromNSColor(_ nsColor: NSColor) -> Color {
        return Color(nsColor.cgColor)
    }
}
