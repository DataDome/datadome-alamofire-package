// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "DataDomeAlamofire",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "DataDomeAlamofire",
            targets: ["DataDomeAlamofire"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(url: "git@github.com:DataDome/mobile-package-ios-coredatadome.git", exact: Version(0, 6, 0))
    ],
    targets: [
        .target(
            name: "DataDomeAlamofire",
            dependencies: [
                "Alamofire",
                .product(name: "CoreDataDome", package: "mobile-package-ios-coredatadome")
            ],
            path: "Sources"
        )
    ],
    swiftLanguageModes: [.v6]
)
