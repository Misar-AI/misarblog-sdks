// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MisarBlog",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "MisarBlog", targets: ["MisarBlog"])
    ],
    targets: [
        .target(name: "MisarBlog", path: "Sources/MisarBlog")
    ]
)
