// swift-tools-version: 6.3

import PackageDescription
import CompilerPluginSupport

let package = Package(
   name: "BCTestExpectation",
   platforms: [
      .iOS(.v17), .macOS(.v14), .macCatalyst(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)
   ],
   products: [
      .library(
         name: "BCTestExpectation",
         targets: ["BCTestExpectation"]
      )
   ],
   dependencies: [
      .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
   ],
   targets: [
      .target(
         name: "BCTestExpectation",
         dependencies: [
            "BCLoggable",
            "BCTestMacros"
         ],
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .macro(
         name: "BCTestMacros",
         dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
         ],
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .target(
         name: "BCLoggable",
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .target(
         name: "TestSupport",
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .testTarget(
         name: "BCTestMacrosTests",
         dependencies: [
            "BCTestMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
         ],
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .testTarget(
         name: "BCTestTests",
         dependencies: [
            "BCTestExpectation",
            "BCLoggable",
            "TestSupport"
         ],
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .testTarget(
         name: "AlternativesTests",
         dependencies: [
            "TestSupport",
            "BCLoggable"
         ],
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      ),
      .testTarget(
         name: "XCTestTests",
         swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .strictMemorySafety()
         ]
      )
   ],
   swiftLanguageModes: [.v6]
)
