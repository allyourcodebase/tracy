#!/usr/bin/env bash
set -euo pipefail

git diff "$@" $(git describe --tags --abbrev=0) \
    --diff-filter=d \
    ':(exclude)include' \
    ':(exclude)README.md' \
    ':(exclude)build.zig' \
    ':(exclude)build.zig.zon' \
    ':(exclude)build.zig.zon2json-lock' \
    ':(exclude)flake.lock' \
    ':(exclude)flake.nix' \
    ':(exclude)diff.sh' \
    ':(exclude).github' \
    ':(exclude).gitattributes' \
    ':(exclude).gitignore'
