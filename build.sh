#!/bin/bash

set -x

title="$(basename "$(pwd)")"

build() {
  local to="$1"
  local ext="$2"
  pandoc --standalone --table-of-contents --to "$to" metadata.yaml chapters/*.md -o "$title.$ext"
}

build epub epub
build latex pdf
