import AppKit
import Foundation

struct IconPalette {
    let baseTop: NSColor
    let baseBottom: NSColor
    let baseStroke: NSColor
    let cardFill: NSColor
    let cardStroke: NSColor
    let headerFill: NSColor
    let monthText: NSColor
    let dayText: NSColor
}

private let defaultPalette = IconPalette(
    baseTop: NSColor(calibratedRed: 20 / 255, green: 58 / 255, blue: 90 / 255, alpha: 1),
    baseBottom: NSColor(calibratedRed: 40 / 255, green: 125 / 255, blue: 192 / 255, alpha: 1),
    baseStroke: NSColor.white.withAlphaComponent(0.24),
    cardFill: NSColor(calibratedRed: 239 / 255, green: 244 / 255, blue: 249 / 255, alpha: 1),
    cardStroke: NSColor.white.withAlphaComponent(0.76),
    headerFill: NSColor(calibratedRed: 93 / 255, green: 175 / 255, blue: 247 / 255, alpha: 1),
    monthText: NSColor.white.withAlphaComponent(0.96),
    dayText: NSColor(calibratedRed: 24 / 255, green: 78 / 255, blue: 131 / 255, alpha: 1)
)

private let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("MMM")
    return formatter
}()

private let fallbackMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateFormat = "M"
    return formatter
}()

private func monthText(for date: Date) -> String {
    let localized = monthFormatter.string(from: date).trimmingCharacters(in: .whitespacesAndNewlines)
    if localized.count <= 4 {
        return localized.uppercased()
    }
    return fallbackMonthFormatter.string(from: date)
}

func makeIcon(side: CGFloat, date: Date, palette: IconPalette) -> NSImage {
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

    let dayLabel = String(Calendar.current.component(.day, from: date))
    let dayText = NSAttributedString(
        string: dayLabel,
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

func writePNG(_ image: NSImage, to path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    outputDir = FileManager.default.currentDirectoryPath
}

let assets = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in assets {
    let icon = makeIcon(side: CGFloat(size), date: Date(), palette: defaultPalette)
    let path = (outputDir as NSString).appendingPathComponent(filename)
    try writePNG(icon, to: path)
    print("wrote \(filename)")
}
