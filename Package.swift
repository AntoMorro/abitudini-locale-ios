// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "HabitCore", platforms: [.macOS(.v13), .iOS(.v18)], products: [.library(name: "HabitCore", targets: ["HabitCore"])], targets: [.target(name: "HabitCore", path: "Core"), .testTarget(name: "HabitCoreTests", dependencies: ["HabitCore"], path: "Tests")])
