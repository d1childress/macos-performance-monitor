// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Operator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Operator",
            targets: ["Operator"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Operator",
            dependencies: [],
            path: "Operator",
            exclude: ["Resources/Operator.entitlements"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
