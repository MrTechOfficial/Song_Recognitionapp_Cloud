// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "reczt_rich_share",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "reczt-rich-share", targets: ["reczt_rich_share"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "reczt_rich_share",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
