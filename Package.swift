// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "NokeMobileLibrary",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "NokeMobileLibrary",
            targets: ["NokeMobileLibraryC", "NokeMobileLibrary"])
    ],
    dependencies: [
        .package(url: "https://github.com/noke-inc/PhoneKeyCore.git", from: "1.1.3")
    ],
    targets: [
        .target(
            name: "NokeMobileLibraryC",
            dependencies: [],
            path: "NokeMobileLibrary/C"
        ),
        .target(
            name: "NokeMobileLibrary",
            dependencies: [
                "NokeMobileLibraryC",
                .product(name: "PhoneKeyCore", package: "PhoneKeyCore")
            ],
            path: "NokeMobileLibrary",
            sources: ["Classes", "Extensions"])
    ],
    swiftLanguageVersions: [.v5])
