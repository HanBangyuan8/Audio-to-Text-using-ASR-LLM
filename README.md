# Audio to Text using ASR LLM

A native SwiftUI macOS app for high-accuracy multilingual audio transcription through OpenAI-compatible ASR LLM APIs, multimodal chat gateways, custom JSON APIs, and local ASR/LLM command pipelines.

## Current Features

- Drag and drop or choose audio files.
- Provider presets for OpenAI, local OpenAI-compatible gateways, Qwen/DashScope-style compatibility layers, Gemini-compatible gateways, whisper.cpp, mlx-whisper, and faster-whisper scripts.
- Configurable OpenAI-compatible `multipart/form-data` transcription endpoint.
- OpenAI-compatible Chat Audio mode for gateways that accept base64 audio in `/v1/chat/completions`.
- Custom JSON API mode with a request-body template, response text path, base64 audio placeholders, and data URL placeholders.
- Local command mode for local ASR/LLM runners such as whisper.cpp, mlx-whisper, faster-whisper, or custom scripts.
- Works with providers that expose `/v1/audio/transcriptions` style APIs.
- Model field accepts any provider model name, such as OpenAI, Qwen, Mimo, Gemini-compatible proxy models, or local gateway models.
- Optional language hint, prompt/glossary, response format, temperature, custom HTTP headers, and custom multipart fields.
- Request timeout and retry controls for unstable APIs or long-running local pipelines.
- Transcription queue and completed results are restored between launches.
- Import and export provider configuration as JSON.
- Queue-based transcription for multiple files.
- Export one transcript or all completed transcripts.
- Export transcripts as TXT, Markdown, SRT, WebVTT, JSON, CSV, TSV, or HTML.

## Build

```bash
swift build
```

## Run

```bash
swift run AudioToTextASRLLM
```

## Package as a macOS App

```bash
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

The app bundle will be created at:

```text
dist/Audio to Text using ASR LLM.app
```

## v1.0.0 Release Checklist

```bash
swift build
swift build -c release
./scripts/package-app.sh
```

## Provider Setup

For an OpenAI-compatible server:

- Base URL: `https://api.openai.com`
- Endpoint Path: `/v1/audio/transcriptions`
- API Key: your provider key
- ASR Model: provider model name, for example `gpt-4o-transcribe`
- Response: use `Verbose JSON` when you want timestamped segments for SRT, WebVTT, and CSV exports.

For a third-party gateway, keep the same endpoint path if it mirrors OpenAI. If the gateway uses a different route, update `Endpoint Path`.

## Backend Modes

### API: Audio Transcriptions

Use this for providers that implement OpenAI-style audio transcription with `multipart/form-data`.

Typical local or remote examples:

```text
https://api.openai.com/v1/audio/transcriptions
http://127.0.0.1:8000/v1/audio/transcriptions
http://localhost:8080/v1/audio/transcriptions
```

### API: Chat Audio

Use this for OpenAI-compatible multimodal chat gateways that accept audio in message content.

Typical endpoint:

```text
/v1/chat/completions
```

Payload modes:

- `input_audio`: sends `{ type: "input_audio", input_audio: { data, format } }`.
- `audio_url data URL`: sends `{ type: "audio_url", audio_url: { url: "data:<mime>;base64,..." } }`.

This mode asks the model to return only transcript text, and it includes your language hint and glossary prompt in the user message.

### API: Custom JSON

Use this for providers and local gateways that are mostly OpenAI-compatible but require a slightly different JSON shape. The app replaces these placeholders inside the request template:

- `{model}`
- `{temperature}`
- `{language}`
- `{prompt}`
- `{instruction}`
- `{filename}`
- `{mimeType}`
- `{audioBase64}`
- `{audioDataURL}`

Set `Response text path` to a dot path such as:

```text
choices.0.message.content
```

If the path is empty, the app tries common response shapes including `text` and `choices[0].message.content`.

### Local: Command

Use this for anything that can be called from the shell: local ASR binaries, Python scripts, MLX tools, whisper.cpp, faster-whisper wrappers, FFmpeg preprocessing pipelines, or a custom script that chains ASR plus LLM correction.

## Local ASR / LLM Setup

Switch Backend to `Local: Command` and enter a command template. The app replaces these placeholders:

- `{audio}`: shell-escaped input audio path
- `{outputBase}`: shell-escaped temporary output path without extension
- `{output}`: shell-escaped temporary `.txt` output path
- `{model}`: shell-escaped model field
- `{language}`: shell-escaped language hint
- `{prompt}`: shell-escaped prompt/glossary

Examples:

```bash
whisper-cli -m {model} -f {audio} -otxt -of {outputBase}
```

```bash
mlx_whisper {audio} --model {model} --language {language}
```

```bash
python3 ~/asr/transcribe.py --audio {audio} --model {model} --language {language} --prompt {prompt} > {output}
```

The app reads `{outputBase}.txt`, `.md`, `.srt`, `.vtt`, or `.json` if the command creates one. Otherwise it uses stdout as the transcript.

## Accuracy Tips

- Use `Verbose JSON` for providers that return timestamped segments.
- Put names, product terms, mixed-language rules, spelling preferences, and punctuation style in Prompt.
- For long audio, use a local command pipeline that chunks audio, transcribes chunks, and performs an LLM cleanup pass.
- For diarization or word timestamps, add provider-specific fields in Advanced, for example `diarization=true`.
- For local HTTP servers, set Base URL to `http://127.0.0.1:<port>` and use one of the API modes.

## Extra Fields

Some providers expose additional multipart fields. Add them in Advanced as one `key=value` pair per line:

```text
timestamp_granularities[]=segment
diarization=true
```

The app forwards these fields without interpreting them.

Extra HTTP headers can be added as one `Header: value` pair per line:

```text
X-Provider-Mode: asr
HTTP-Referer: http://localhost
```
