// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacMouseGesture",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "MacMouseGesture", targets: ["MouseGesturePOC"])],
    targets: [
        .target(name: "GestureCore"),
        .target(name: "SystemGestureBridge", publicHeadersPath: "include",
                cSettings: [.unsafeFlags(["-fobjc-arc"])],
                linkerSettings: [.linkedFramework("Foundation"), .linkedFramework("CoreGraphics")]),
        .executableTarget(name: "MouseGesturePOC", dependencies: ["GestureCore", "SystemGestureBridge"],
                          linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("IOKit"),
                                           .linkedFramework("ServiceManagement")])
    ]
)
