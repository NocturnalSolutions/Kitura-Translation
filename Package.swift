// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "KituraTranslation",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/LoggerAPI.git", majorVersion: 1)
    ]
)
