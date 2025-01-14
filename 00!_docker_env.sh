#!/bin/sh -e
export BUILDKIT_COLORS="run=blue:error=red:cancel=yellow:warning=blue"
export BUILDKIT_TTY_LOG_LINES=40
export EBR_RELEASE="2024.02.10"
export UBT_RELEASE="2025.01"
export LNX_RELEASE="6.6.71"
DOCKER_ID="devuan_build/lcpi-pc-t100:pre_0"
# TARGETS:
# base, devuan_bootstrap, kbuilder, kernel_build
# TARGET="base"
# TARGET="kbuilder"
TARGET="kernel_build"

echo $UID
echo $USER
