# Audio to Text using ASR LLM

![macOS](https://img.shields.io/badge/macOS-12%2B-blue?style=flat)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-147EFB?style=flat)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat)
![GitHub release](https://img.shields.io/github/v/release/HanBangyuan8/Audio-to-Text-using-ASR-LLM?style=flat)
![GitHub Downloads](https://img.shields.io/github/downloads/HanBangyuan8/Audio-to-Text-using-ASR-LLM/total?style=flat)
![GitHub Repo stars](https://img.shields.io/github/stars/HanBangyuan8/Audio-to-Text-using-ASR-LLM?style=flat)

A native macOS SwiftUI app for high-accuracy multilingual audio transcription with OpenAI-compatible ASR APIs, multimodal LLM gateways, custom JSON endpoints, and local ASR/LLM command pipelines.

<p align="center">
  <img src="Resources/AppIcon.png" alt="Audio to Text using ASR LLM app icon" width="160">
</p>

## Features

- OpenAI-compatible `/v1/audio/transcriptions` transcription
- OpenAI-compatible `/v1/chat/completions` audio transcription
- Custom JSON multimodal API mode with request templates and response text paths
- Local command mode for whisper.cpp, mlx-whisper, faster-whisper, FFmpeg pipelines, and custom scripts
- Provider presets for OpenAI, Qwen/DashScope-style compatibility layers, Gemini-compatible gateways, local gateways, and local command runners
- Drag-and-drop audio queue for MP3, WAV, M4A, FLAC, OGG, WebM, and AAC files
- Language hints, prompt/glossary guidance, custom HTTP headers, custom multipart fields, retries, and timeout controls
- Persistent queue and completed transcript recovery between launches
- Provider configuration import and export as JSON
- Selected or batch transcript export as TXT, Markdown, SRT, WebVTT, JSON, CSV, TSV, and HTML

## Requirements

### Latest Version

- Apple M chips and Intel processors
- Runtime requirement: macOS 12+
- Xcode 15+ or Swift 5.9+
- An OpenAI-compatible ASR API, multimodal LLM gateway, or local ASR command-line runner

## Configuration

Typical OpenAI-compatible transcription settings:

```text
Backend: API: Audio Transcriptions
Base URL: https://api.openai.com
Endpoint Path: /v1/audio/transcriptions
API Key: your provider key
ASR Model: gpt-4o-transcribe
Response: Verbose JSON
```

Typical local gateway settings:

```text
Backend: API: Custom JSON
Base URL: http://127.0.0.1:8000
Endpoint Path: /v1/chat/completions
ASR Model: your-audio-model
Response text path: choices.0.message.content
```

Typical local command settings:

```text
Backend: Local: Command
ASR Model: /path/to/ggml-large-v3.bin
Command: whisper-cli -m {model} -f {audio} -l {language} -otxt -osrt -of {outputBase}
```

## Build

```bash
swift build
```

## Run

```bash
swift run AudioToTextASRLLM
```

## Package

```bash
./scripts/package-dmg.sh
open "dist/Audio-to-Text-using-ASR-LLM-v1.2.0-macOS-universal.app"
```

The package script creates a signed ad-hoc universal macOS `.app`, a versioned zip archive, and a DMG image:

```text
dist/Audio-to-Text-using-ASR-LLM-v1.2.0-macOS-universal.zip
```

## Data Location

Transcription queue and completed result snapshots are stored locally at:

```text
~/Library/Application Support/AudioToTextASRLLM/records.json
```

Provider settings are stored in macOS user defaults and can also be exported as JSON from the app.

## Release

Download v1.0.0 and newer signed ad-hoc macOS app archives from [GitHub Releases](https://github.com/HanBangyuan8/Audio-to-Text-using-ASR-LLM/releases).

Release notes are maintained in `CHANGELOG.md`.

## License

MPL-2.0. See [LICENSE](LICENSE).

## Star History

<a href="https://www.star-history.com/?type=date&repos=HanBangyuan8%2FAudio-to-Text-using-ASR-LLM">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=HanBangyuan8/Audio-to-Text-using-ASR-LLM&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=HanBangyuan8/Audio-to-Text-using-ASR-LLM&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=HanBangyuan8/Audio-to-Text-using-ASR-LLM&type=date&legend=top-left" />
 </picture>
</a>
