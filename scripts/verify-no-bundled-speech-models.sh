#!/bin/zsh
set -euo pipefail

target="${1:?usage: verify-no-bundled-speech-models.sh <app-bundle>}"

if [[ ! -d "$target" ]]; then
  print -u2 "Speech model bundle check target does not exist: $target"
  exit 1
fi

model_artifact="$(
  find "$target" \
    \( \
      -name '*.mlmodel' -o \
      -name '*.mlmodelc' -o \
      -name '*.mlpackage' -o \
      -name '*.safetensors' -o \
      -name 'weight.bin' \
    \) \
    -print \
    -quit
)"

if [[ -n "$model_artifact" ]]; then
  print -u2 "Refusing to bundle optional speech model artifact:"
  print -u2 "$model_artifact"
  exit 1
fi

echo "PASS: optional speech models are external to the app bundle"
