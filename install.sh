#!/bin/bash

SYSTEM=$(uname -s)
if [ "$SYSTEM" != "Darwin" ]; then
    echo "SyphonBuffer: Platform ($SYSTEM) not supported."
    echo "SyphonBuffer: Skipping build."
    exit 0;
fi

cd native
make
