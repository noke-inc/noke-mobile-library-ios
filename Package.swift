// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "NokeMobileLibrary",
    platforms: [.iOS(.v8)],
    products: [
        .library(
            name: "NokeMobileLibrary",
            targets: ["NokeMobileLibraryC", "NokeMobileLibrary"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "NokeMobileLibraryC",
            dependencies: [],
            path: "NokeMobileLibrary/C"
        ),
        .target(
            name: "NokeMobileLibrary",
            dependencies: ["NokeMobileLibraryC"],
            path: "NokeMobileLibrary/Classes")
    ],
    swiftLanguageVersions: [.v5])
