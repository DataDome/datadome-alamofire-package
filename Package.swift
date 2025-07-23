// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "DataDomeAlamofire",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(
            name: "DataDomeAlamofire",
            targets: ["DataDomeAlamofire"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(name: "DataDomeSDK", url: "https://github.com/DataDome/datadome-ios-package", from: Version(3, 8, 3))
    ],
    targets: [
        .target(
            name: "DataDomeAlamofire",
            dependencies: ["Alamofire", "DataDomeSDK"],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
