# Changelog

## v1.0.1

Compatibility and repository metadata update.

- Lowered runtime requirement from macOS 14+ to macOS 13+.
- Lowered build tool requirement from Xcode 16+ / Swift 6.0+ to Xcode 15+ / Swift 5.9+.
- Replaced the macOS 14-only empty-state view with a SwiftUI fallback compatible with macOS 13.
- Switched the project license to MPL-2.0.
- Aligned repository presentation and release asset naming with the other HanBangyuan8 repositories.

## v1.0.0

Initial public release.

- Native SwiftUI macOS app for audio-to-text transcription.
- Supports OpenAI-compatible audio transcription APIs.
- Supports OpenAI-compatible multimodal chat audio APIs.
- Supports custom JSON multimodal gateways with configurable response paths.
- Supports local ASR/LLM command pipelines such as whisper.cpp, mlx-whisper, faster-whisper, and custom scripts.
- Includes provider presets for OpenAI, Qwen/DashScope-style compatibility layers, Gemini-compatible gateways, local gateways, and local command runners.
- Handles multiple audio formats including MP3, WAV, M4A, FLAC, OGG, WebM, and AAC.
- Provides language hints, prompt/glossary guidance, custom HTTP headers, custom multipart fields, retries, and timeout controls.
- Persists the transcription queue and completed results between app launches.
- Exports selected or completed transcripts as TXT, Markdown, SRT, WebVTT, JSON, CSV, TSV, and HTML.
- Packages as a standalone macOS `.app` with `scripts/package-app.sh`.
