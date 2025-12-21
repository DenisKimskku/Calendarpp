// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "CalendarPlusCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "calendarplusplus", targets: ["CalendarPlusCLI"])
    ],
    targets: [
        .executableTarget(
            name: "CalendarPlusCLI"
        )
    ]
)
