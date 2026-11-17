// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "cmfdial",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "cmfdial",
            path: "Sources/cmfdial",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist", "-Xlinker", "Sources/cmfdial/Info.plist"])
            ]
        )
    ]
)
