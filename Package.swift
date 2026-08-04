// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioToTextASRLLM",
    platforms: [
        .macOS(.v12)
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
