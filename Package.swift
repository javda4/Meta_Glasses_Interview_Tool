// swift-tools-version: 5.9
// This file is provided for reference. If you opened the project as an
// .xcodeproj, add packages through Xcode → File → Add Package Dependencies
// instead of editing this file directly.

import PackageDescription

let package = Package(
    name: "RayBanMemoryApp",
    platforms: [
        .iOS(.v15)          // Minimum required by the Meta Wearables DAT SDK
    ],
    products: [
        .library(name: "RayBanMemoryApp", targets: ["RayBanMemoryApp"])
    ],
    dependencies: [

        // ── Meta Wearables Device Access Toolkit ──────────────────────────
        // Provides MWDATCore and MWDATCamera
        .package(
            url: "https://github.com/facebook/meta-wearables-dat-ios",
            from: "0.4.0"
        ),

        // ── Supabase Swift SDK (optional but recommended) ─────────────────
        // Drop-in replacement for the lightweight REST wrapper in this project.
        // Adds Realtime, Auth, Storage, and typed query builders.
        // Uncomment to use:
        //
        // .package(
        //     url: "https://github.com/supabase/supabase-swift",
        //     from: "2.0.0"
        // ),

    ],
    targets: [
        .target(
            name: "RayBanMemoryApp",
            dependencies: [
                .product(name: "MWDATCore",   package: "meta-wearables-dat-ios"),
                .product(name: "MWDATCamera", package: "meta-wearables-dat-ios"),

                // Uncomment if using the Supabase Swift SDK:
                // .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "RayBanMemoryApp"
        ),
        .testTarget(
            name: "RayBanMemoryAppTests",
            dependencies: [
                "RayBanMemoryApp",
                .product(name: "MWDATCore",   package: "meta-wearables-dat-ios"),
                .product(name: "MWDATCamera", package: "meta-wearables-dat-ios"),
            ],
            path: "RayBanMemoryAppTests"
        )
    ]
)
