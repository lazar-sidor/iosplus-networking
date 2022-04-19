// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iosplusNetworking",
    platforms: [.iOS(SupportedPlatform.IOSVersion.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "iosplusNetworking",
            targets: ["iosplusNetworking"]
        ),
        .library(
            name: "iosplusFirebaseAuthentication",
            targets: ["iosplusCoreAuthentication", "iosplusFirebaseAuthentication"]
        ),
        .library(
            name: "iosplusAwsCognitoAuthentication",
            targets: ["iosplusCoreAuthentication", "iosplusAwsCognitoAuthentication"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
          name: "Firebase",
          url: "https://github.com/firebase/firebase-ios-sdk",
          "8.0.0" ..< "9.0.0"
        ),
        .package(
          name: "Facebook",
          url: "https://github.com/facebook/facebook-ios-sdk",
          "12.2.1" ..< "13.0.0"
        ),
        .package(
          name: "GoogleSignIn",
          url: "https://github.com/google/GoogleSignIn-iOS",
          "6.1.0" ..< "7.0.0"
        ),
        .package(
          name: "Amplify",
          url: "https://github.com/aws-amplify/amplify-ios",
          "1.0.0" ..< "2.0.0"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "iosplusNetworking",
            dependencies: [],
            path: "Sources/iosplusNetworking"
        ),
        .target(
            name: "iosplusCoreAuthentication",
            dependencies: [],
            path: "Sources/iosplusAuthentication/Core"
        ),
        .target(
            name: "iosplusFirebaseAuthentication",
            dependencies: [
                "iosplusCoreAuthentication",
                .product(name: "FirebaseAuth", package: "Firebase"),
                .product(name: "FacebookLogin", package: "Facebook"),
                "GoogleSignIn"
            ],
            path: "Sources/iosplusAuthentication/Firebase"
        ),
        .target(
            name: "iosplusAwsCognitoAuthentication",
            dependencies: [
                "iosplusCoreAuthentication",
                .product(name: "AWSCognitoAuthPlugin", package: "Amplify"),
            ],
            path: "Sources/iosplusAuthentication/Amplify"
        ),
        .testTarget(
            name: "iosplusNetworkingTests",
            dependencies: ["iosplusNetworking"]
        ),
    ]
)
