import AppKit
import Foundation

@MainActor
final class DynamicAppIconManager {
    static let shared = DynamicAppIconManager()

    private var dayObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var refreshTimer: Timer?
    private var isStarted = false
    private lazy var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()
    private lazy var fallbackMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "M"
        return formatter
    }()

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        updateIcon(for: Date())
        registerObservers()
        scheduleRefreshTimer()
    }

    func refreshNow() {
        updateIcon(for: Date())
    }

    deinit {
        if let dayObserver {
            NotificationCenter.default.removeObserver(dayObserver)
        }
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        refreshTimer?.invalidate()
    }

    private func registerObservers() {
        dayObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateIcon(for: Date())
            }
        }

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateIcon(for: Date())
            }
        }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateIcon(for: Date())
            }
        }
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateIcon(for: Date())
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func updateIcon(for date: Date) {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.object(forKey: "dynamicDockIconEnabled") == nil
            ? true
            : defaults.bool(forKey: "dynamicDockIconEnabled")

        if !isEnabled {
            applyBundledIcon()
            return
        }
        NSApplication.shared.applicationIconImage = makeTodayIcon(for: date, side: 1024)
    }

    private func applyBundledIcon() {
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let image = NSImage(named: iconName) {
            NSApplication.shared.applicationIconImage = image
            return
        }

        if let image = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = image
            return
        }

        NSApplication.shared.applicationIconImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private func makeTodayIcon(for date: Date, side: CGFloat) -> NSImage {
        let palette = paletteForCurrentAccent()

        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = CGRect(x: 0, y: 0, width: side, height: side)
        NSColor.clear.setFill()
        canvas.fill()

        let baseRect = canvas.insetBy(dx: side * 0.07, dy: side * 0.07)
        let baseRadius = side * 0.20
        let basePath = NSBezierPath(roundedRect: baseRect, xRadius: baseRadius, yRadius: baseRadius)
        NSGradient(colors: [palette.baseTop, palette.baseBottom])?.draw(in: basePath, angle: -90)
        palette.baseStroke.setStroke()
        basePath.lineWidth = max(1.0, side * 0.004)
        basePath.stroke()

        let cardRect = baseRect.insetBy(dx: side * 0.15, dy: side * 0.14)
        let cardRadius = side * 0.09
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: cardRadius, yRadius: cardRadius)
        palette.cardFill.setFill()
        cardPath.fill()
        palette.cardStroke.setStroke()
        cardPath.lineWidth = max(1.0, side * 0.0032)
        cardPath.stroke()

        let stripHeight = cardRect.height * 0.34
        let headerRect = CGRect(
            x: cardRect.minX,
            y: cardRect.maxY - stripHeight,
            width: cardRect.width,
            height: stripHeight
        )
        let headerPath = NSBezierPath(roundedRect: headerRect, xRadius: cardRadius * 0.56, yRadius: cardRadius * 0.56)
        palette.headerFill.setFill()
        headerPath.fill()

        let monthLabel = monthText(for: date)

        let monthText = NSAttributedString(
            string: monthLabel,
            attributes: [
                .font: NSFont.systemFont(ofSize: side * 0.13, weight: .semibold),
                .foregroundColor: palette.monthText,
                .kern: side * 0.001
            ]
        )
        let monthSize = monthText.size()
        monthText.draw(at: CGPoint(
            x: headerRect.midX - monthSize.width / 2,
            y: headerRect.midY - monthSize.height / 2 - side * 0.002
        ))

        let dayNumber = String(Calendar.current.component(.day, from: date))
        let dayText = NSAttributedString(
            string: dayNumber,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: side * 0.24, weight: .bold),
                .foregroundColor: palette.dayText
            ]
        )
        let daySize = dayText.size()
        let bodyRect = CGRect(
            x: cardRect.minX,
            y: cardRect.minY,
            width: cardRect.width,
            height: cardRect.height - stripHeight
        )
        dayText.draw(at: CGPoint(
            x: bodyRect.midX - daySize.width / 2,
            y: bodyRect.midY - daySize.height / 2 - side * 0.006
        ))

        return image
    }

    private func monthText(for date: Date) -> String {
        let localized = monthFormatter.string(from: date).trimmingCharacters(in: .whitespacesAndNewlines)
        if localized.count <= 4 {
            return localized.uppercased()
        }
        return fallbackMonthFormatter.string(from: date)
    }

    private struct IconPalette {
        let baseTop: NSColor
        let baseBottom: NSColor
        let baseStroke: NSColor
        let cardFill: NSColor
        let cardStroke: NSColor
        let headerFill: NSColor
        let monthText: NSColor
        let dayText: NSColor
    }

    private func paletteForCurrentAccent() -> IconPalette {
        let defaults = UserDefaults.standard
        let useAccent = defaults.object(forKey: "dynamicDockIconUseAccent") == nil
            ? true
            : defaults.bool(forKey: "dynamicDockIconUseAccent")
        let choice = useAccent ? (UserDefaults.standard.string(forKey: "uiAccentChoice") ?? "jade") : "ocean"

        switch choice {
        case "system":
            let accent = NSColor.controlAccentColor
            return IconPalette(
                baseTop: blend(accent, with: .black, fraction: 0.70),
                baseBottom: blend(accent, with: .black, fraction: 0.40),
                baseStroke: NSColor.white.withAlphaComponent(0.22),
                cardFill: NSColor(calibratedWhite: 0.965, alpha: 1),
                cardStroke: NSColor.white.withAlphaComponent(0.72),
                headerFill: blend(accent, with: .white, fraction: 0.22),
                monthText: NSColor.white.withAlphaComponent(0.96),
                dayText: blend(accent, with: .black, fraction: 0.50)
            )
        case "ocean":
            return IconPalette(
                baseTop: NSColor(calibratedRed: 20 / 255, green: 58 / 255, blue: 90 / 255, alpha: 1),
                baseBottom: NSColor(calibratedRed: 40 / 255, green: 125 / 255, blue: 192 / 255, alpha: 1),
                baseStroke: NSColor.white.withAlphaComponent(0.24),
                cardFill: NSColor(calibratedRed: 239 / 255, green: 244 / 255, blue: 249 / 255, alpha: 1),
                cardStroke: NSColor.white.withAlphaComponent(0.76),
                headerFill: NSColor(calibratedRed: 93 / 255, green: 175 / 255, blue: 247 / 255, alpha: 1),
                monthText: NSColor.white.withAlphaComponent(0.96),
                dayText: NSColor(calibratedRed: 24 / 255, green: 78 / 255, blue: 131 / 255, alpha: 1)
            )
        case "rose":
            return IconPalette(
                baseTop: NSColor(calibratedRed: 72 / 255, green: 25 / 255, blue: 52 / 255, alpha: 1),
                baseBottom: NSColor(calibratedRed: 151 / 255, green: 58 / 255, blue: 104 / 255, alpha: 1),
                baseStroke: NSColor.white.withAlphaComponent(0.22),
                cardFill: NSColor(calibratedRed: 248 / 255, green: 238 / 255, blue: 244 / 255, alpha: 1),
                cardStroke: NSColor.white.withAlphaComponent(0.72),
                headerFill: NSColor(calibratedRed: 225 / 255, green: 107 / 255, blue: 157 / 255, alpha: 1),
                monthText: NSColor.white.withAlphaComponent(0.95),
                dayText: NSColor(calibratedRed: 130 / 255, green: 42 / 255, blue: 84 / 255, alpha: 1)
            )
        case "amber":
            return IconPalette(
                baseTop: NSColor(calibratedRed: 74 / 255, green: 45 / 255, blue: 13 / 255, alpha: 1),
                baseBottom: NSColor(calibratedRed: 173 / 255, green: 111 / 255, blue: 33 / 255, alpha: 1),
                baseStroke: NSColor.white.withAlphaComponent(0.22),
                cardFill: NSColor(calibratedRed: 250 / 255, green: 245 / 255, blue: 236 / 255, alpha: 1),
                cardStroke: NSColor.white.withAlphaComponent(0.72),
                headerFill: NSColor(calibratedRed: 236 / 255, green: 166 / 255, blue: 66 / 255, alpha: 1),
                monthText: NSColor(calibratedRed: 1, green: 246 / 255, blue: 229 / 255, alpha: 0.96),
                dayText: NSColor(calibratedRed: 122 / 255, green: 77 / 255, blue: 24 / 255, alpha: 1)
            )
        case "graphite":
            return IconPalette(
                baseTop: NSColor(calibratedWhite: 0.18, alpha: 1),
                baseBottom: NSColor(calibratedWhite: 0.36, alpha: 1),
                baseStroke: NSColor.white.withAlphaComponent(0.20),
                cardFill: NSColor(calibratedWhite: 0.94, alpha: 1),
                cardStroke: NSColor.white.withAlphaComponent(0.60),
                headerFill: NSColor(calibratedWhite: 0.60, alpha: 1),
                monthText: NSColor(calibratedWhite: 0.96, alpha: 0.95),
                dayText: NSColor(calibratedWhite: 0.25, alpha: 1)
            )
        default: // jade
            return IconPalette(
                baseTop: NSColor(calibratedRed: 21 / 255, green: 55 / 255, blue: 47 / 255, alpha: 1),
                baseBottom: NSColor(calibratedRed: 50 / 255, green: 130 / 255, blue: 110 / 255, alpha: 1),
                baseStroke: NSColor.white.withAlphaComponent(0.22),
                cardFill: NSColor(calibratedRed: 239 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1),
                cardStroke: NSColor.white.withAlphaComponent(0.70),
                headerFill: NSColor(calibratedRed: 97 / 255, green: 200 / 255, blue: 170 / 255, alpha: 1),
                monthText: NSColor(calibratedRed: 237 / 255, green: 250 / 255, blue: 245 / 255, alpha: 0.96),
                dayText: NSColor(calibratedRed: 30 / 255, green: 96 / 255, blue: 78 / 255, alpha: 1)
            )
        }
    }

    private func blend(_ base: NSColor, with other: NSColor, fraction: CGFloat) -> NSColor {
        base.blended(withFraction: fraction, of: other) ?? base
    }
}
