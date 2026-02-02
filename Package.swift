// swift-tools-version: 6.0

// WARNING:
// This file is automatically managed by Swift Playgrounds and should not be manually edited.

import AppleProductTypes
import PackageDescription

let package = Package(
    name: "diet_app",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "diet_app",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.diet-app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .heart),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
