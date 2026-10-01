// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MapleCore",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "MapleCore", targets: ["MapleCore"])
    ],
    targets: [
        .target(name: "MapleCore"),
        .testTarget(name: "MapleCoreTests", dependencies: ["MapleCore"])
    ]
)
