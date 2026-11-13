// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "WeddingCore", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "WeddingCore", targets: ["WeddingCore"])], targets: [.target(name: "WeddingCore", path: "Core"), .testTarget(name: "WeddingCoreTests", dependencies: ["WeddingCore"], path: "Tests")])
