// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-syntax-scope-visualizer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.51.0"),
        .package(url: "https://github.com/omochi/swift-react", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "swift-syntax-scope-visualizer",
            dependencies: [
                "JavaScriptKit",
                .product(name: "React", package: "swift-react")
            ]
        ),
        .testTarget(
            name: "swift-syntax-scope-visualizerTests",
            dependencies: ["swift-syntax-scope-visualizer"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
