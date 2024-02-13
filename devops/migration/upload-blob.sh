#!/bin/bash

set -ex

SRC="$1"
DST="$2"
SAS="$3"

if ! test -r "$SRC"; then
        echo "E: File not found: $SRC" >&2
        exit 1
fi

curl \
        -v \
        -X PUT \
        -H "Content-Type: application/octet-stream" \
        -H "x-ms-date: $(date -Ru | sed 's/\+0000/GMT/')" \
        -H "x-ms-version: 2020-02-10" \
        -H "x-ms-blob-type: BlockBlob" \
        --data-binary "@$SRC" \
        "$DST/$(basename $SRC)?$SAS"