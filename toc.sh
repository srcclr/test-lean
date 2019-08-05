#!/bin/bash

title="$(grep title: metadata.yaml | sed -e 's/title: //' -e "s/'//g")"

echo "# $title"

paste -d '\0' \
  <(ls chapters | sort | sed -e 's/\(.*\).md/- [\1]/') \
  <(ls chapters | sort | sed -e 's!\(.*\).md!(chapters/\1.md)!' -e 's/ /%20/g')
