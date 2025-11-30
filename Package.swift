// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZoomableView",
    platforms: [
        .iOS(.v16),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ZoomableView",
            targets: ["ZoomableView"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ZoomableView"
        ),
        .testTarget(
            name: "ZoomableViewTests",
            dependencies: ["ZoomableView"]
        ),
    ]
)
