#!/bin/sh
# Xcode Cloud does not check out submodules automatically.
set -e
git submodule update --init --recursive
