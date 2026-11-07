// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CardPeriod",
    platforms: [.iOS(.v16)],
    products: [.library(name: "CardPeriod", targets: ["CardPeriod"])],
    targets: [
        .target(name: "CardPeriod", path: "Sources/CardPeriod"),
        .testTarget(name: "CardPeriodCoreTests", dependencies: ["CardPeriod"], path: "Tests/CardPeriodCoreTests")
    ]
)
