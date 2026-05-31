#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-release}"
product="AudioToTextASRLLM"
app_name="Audio to Text using ASR LLM"
app_dir="dist/${app_name}.app"
zip_path="dist/${app_name}.zip"
contents_dir="${app_dir}/Contents"
macos_dir="${contents_dir}/MacOS"

swift build -c "${configuration}"

rm -rf "${app_dir}" "${zip_path}"
mkdir -p "${macos_dir}"
cp "Support/Info.plist" "${contents_dir}/Info.plist"
cp ".build/${configuration}/${product}" "${macos_dir}/${product}"
chmod +x "${macos_dir}/${product}"

ditto -c -k --norsrc --keepParent "${app_dir}" "${zip_path}"

echo "Packaged ${app_dir}"
echo "Packaged ${zip_path}"
