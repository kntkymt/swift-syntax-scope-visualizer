// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-syntax-scope-visualizer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.51.0"),
        .package(url: "https://github.com/omochi/swift-react", from: "0.2.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
        .package(url: "https://github.com/kntkymt/swift-syntax-scope.git", from: "0.0.1"),
    ],
    targets: [
        .executableTarget(
            name: "swift-syntax-scope-visualizer",
            dependencies: [
                "Pages",
                "JavaScriptKit",
                .product(name: "React", package: "swift-react")
            ]
        ),
        .target(
            name: "Pages",
            dependencies: [
                "SwiftCodeEditor",
                .product(name: "React", package: "swift-react"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
                .product(name: "SwiftSyntaxScope", package: "swift-syntax-scope")
            ]
        ),
        .target(
            name: "SwiftCodeEditor",
            dependencies: [
                .product(name: "React", package: "swift-react")
            ]
        ),
        .testTarget(
            name: "swift-syntax-scope-visualizerTests",
            dependencies: [
                "Pages",
                "swift-syntax-scope-visualizer",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
