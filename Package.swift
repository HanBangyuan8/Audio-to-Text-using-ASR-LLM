// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioToTextASRLLM",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioToTextASRLLM", targets: ["AudioToTextASRLLM"])
    ],
    targets: [
        .executableTarget(
            name: "AudioToTextASRLLM",
            path: "Sources/AudioToTextASRLLM"
        )
    ]
)
