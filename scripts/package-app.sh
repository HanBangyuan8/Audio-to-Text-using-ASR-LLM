#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-release}"
product="AudioToTextASRLLM"
app_name="Audio to Text using ASR LLM"
app_dir="dist/${app_name}.app"
contents_dir="${app_dir}/Contents"
macos_dir="${contents_dir}/MacOS"

swift build -c "${configuration}"

mkdir -p "${macos_dir}"
cp "Support/Info.plist" "${contents_dir}/Info.plist"
cp ".build/${configuration}/${product}" "${macos_dir}/${product}"
chmod +x "${macos_dir}/${product}"

echo "Packaged ${app_dir}"
