// swift-tools-version: 5.8

// see: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html

import PackageDescription

let package = Package(
    name: "todo",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/hectr/SwiftyChrono.git", branch: "swifttools42"),
        .package(url: "https://github.com/nadjem/Swiftline", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "todo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftyChrono", package: "SwiftyChrono"),
                .product(name: "Swiftline", package: "Swiftline"),
            ],
            path: "src"
        ),
    ]
)
