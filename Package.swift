// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-app-automation",
    platforms: [
        // macOS only, and not by choice: the Accessibility client API — reading
        // another app's interface and driving it — exists nowhere else. iOS
        // gives a third-party process no equivalent, with or without
        // permission.
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppAutomation", targets: ["AppAutomation"]),
    ],
    targets: [
        .target(name: "AppAutomation"),

        // A window with known controls, for the live tests to drive. Not a
        // product: nothing outside this package should be able to build it,
        // and it exists so a test can assert what an app SAW rather than what
        // the Accessibility API claimed to do.
        .executableTarget(name: "AutomationFixture", path: "Tests/AutomationFixture"),

        .testTarget(
            name: "AppAutomationTests",
            dependencies: ["AppAutomation", "AutomationFixture"]
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
