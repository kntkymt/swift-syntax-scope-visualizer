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
        .package(url: "https://github.com/kntkymt/swift-syntax-scope.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "swift-syntax-scope-visualizer",
            dependencies: [
                "Pages",
                "JavaScriptKit",
                .product(name: "React", package: "swift-react"),
            ]
        ),
        .target(
            name: "Pages",
            dependencies: [
                "SwiftCodeEditor",
                "SwiftReactPlus",
                .product(name: "React", package: "swift-react"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
                .product(name: "SwiftSyntaxScope", package: "swift-syntax-scope"),
            ]
        ),
        .target(
            name: "SwiftCodeEditor",
            dependencies: [
                "SwiftReactPlus",
                .product(name: "React", package: "swift-react"),
            ]
        ),
        .target(
            name: "SwiftReactPlus",
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
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .binaryTarget(
            name: "LicensePlistBinary",
            url:
                "https://github.com/mono0926/LicensePlist/releases/download/3.27.7/LicensePlistBinary-macos.artifactbundle.zip",
            checksum: "cfc763c02bc79f0539d4201098782116d1d6cc9911da9d2fafd6925cbc19880a"
        ),
        .plugin(
            name: "GenerateLicenseList",
            capability: .command(
                intent: .custom(
                    verb: "generate-license-list",
                    description:
                        "Generate Sources/Pages/Generated/LicensesContent.swift via LicensePlist"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Write Sources/Pages/Generated/LicensesContent.swift"
                    ),
                    .allowNetworkConnections(
                        scope: .all(ports: []),
                        reason: "Fetch OSS licenses from GitHub API"
                    ),
                ]
            ),
            dependencies: ["LicensePlistBinary"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
