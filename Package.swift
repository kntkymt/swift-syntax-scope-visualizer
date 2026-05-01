// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-syntax-scope-visualizer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.51.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "swift-syntax-scope-visualizer",
            dependencies: [
                "JavaScriptKit"
            ]
        ),
        .testTarget(
            name: "swift-syntax-scope-visualizerTests",
            dependencies: ["swift-syntax-scope-visualizer"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
