#!/bin/sh

SYSTEM=$(uname -s)
if [[ "$SYSTEM" != "Darwin" ]]; then
    echo "SyphonBuffer: Platform ($SYSTEM) not supported."
    echo "SyphonBuffer: Skipping build."
    exit 1;
fi

cd native
make
