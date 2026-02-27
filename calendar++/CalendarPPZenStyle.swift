import SwiftUI
import AppKit

enum CalendarPPZenStyle {
    static let stroke = Color.primary.opacity(0.10)
    static let strokeStrong = Color.primary.opacity(0.18)

    static let cornerRadius: CGFloat = 14
    static let cornerRadiusSmall: CGFloat = 10
}

struct CalendarPPZenBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        let intensity = max(0.0, min(1.0, settings.uiBackgroundIntensity))
        let accent = settings.resolvedTintColor

        ZStack {
            Color(nsColor: .windowBackgroundColor)

            RadialGradient(
                colors: [
                    accent.opacity((colorScheme == .dark ? 0.22 : 0.12) * intensity),
                    .clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 820
            )

            RadialGradient(
                colors: [
                    accent.opacity((colorScheme == .dark ? 0.12 : 0.07) * intensity),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 900
            )

            // Subtle vignette for depth.
            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.55 : 0.06),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .blendMode(.multiply)
            .opacity((colorScheme == .dark ? 0.45 : 0.25) * intensity)
        }
        .ignoresSafeArea()
    }
}

private struct CalendarPPZenCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let strong: Bool
    let hovered: Bool

    func body(content: Content) -> some View {
        let shadowOpacity = colorScheme == .dark ? 0.55 : 0.12

        return content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(strong ? .regularMaterial : .thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(hovered ? CalendarPPZenStyle.strokeStrong : CalendarPPZenStyle.stroke, lineWidth: 1)
                    )
            )
            .shadow(
                color: (strong || hovered) ? Color.black.opacity(shadowOpacity) : .clear,
                radius: strong ? 18 : (hovered ? 14 : 0),
                x: 0,
                y: strong ? 10 : (hovered ? 6 : 0)
            )
    }
}

extension View {
    func calendarPPZenCard(
        cornerRadius: CGFloat = CalendarPPZenStyle.cornerRadiusSmall,
        strong: Bool = false,
        hovered: Bool = false
    ) -> some View {
        modifier(CalendarPPZenCardModifier(cornerRadius: cornerRadius, strong: strong, hovered: hovered))
    }
}
