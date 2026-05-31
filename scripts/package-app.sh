#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-release}"
product="AudioToTextASRLLM"
app_name="Audio to Text using ASR LLM"
dist_dir="dist"
published_app_dir="${dist_dir}/${app_name}.app"
zip_path="${dist_dir}/${app_name}.zip"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/AudioToTextASRLLM.XXXXXX")"
app_dir="${stage_dir}/${app_name}.app"
zip_stage_path="${stage_dir}/${app_name}.zip"
verify_dir="${stage_dir}/verify"
contents_dir="${app_dir}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"

cleanup() {
    rm -rf "${stage_dir}"
}
trap cleanup EXIT

swift build -c "${configuration}"

rm -rf "${published_app_dir}" "${zip_path}"
mkdir -p "${dist_dir}"
mkdir -p "${macos_dir}" "${resources_dir}"
cp "Support/Info.plist" "${contents_dir}/Info.plist"
cp ".build/${configuration}/${product}" "${macos_dir}/${product}"
chmod +x "${macos_dir}/${product}"

xattr -cr "${app_dir}" || true
codesign --force --deep --sign - "${app_dir}"
codesign --verify --deep --strict --verbose=2 "${app_dir}"
xattr -cr "${app_dir}" || true

ditto -c -k --norsrc --keepParent "${app_dir}" "${zip_stage_path}"
mkdir -p "${verify_dir}"
ditto -x -k "${zip_stage_path}" "${verify_dir}"
codesign --verify --deep --strict --verbose=2 "${verify_dir}/${app_name}.app"

ditto --norsrc "${app_dir}" "${published_app_dir}"
cp "${zip_stage_path}" "${zip_path}"

echo "Packaged ${published_app_dir}"
echo "Packaged ${zip_path}"
