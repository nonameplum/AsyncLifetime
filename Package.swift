// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [PackageDescription.SwiftSetting] = [
  .enableUpcomingFeature("InferSendableFromCaptures"),
  .enableUpcomingFeature("IsolatedDefaultValues"),
  .enableUpcomingFeature("RegionBasedIsolation"),
]

let package = Package(
  name: "AsyncLifetime",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .watchOS(.v10),
    .tvOS(.v17),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "AsyncLifetime",
      targets: ["AsyncLifetime"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "AsyncLifetime",
      dependencies: [],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "AsyncLifetimeTests",
      dependencies: [
        "AsyncLifetime",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
