#!/bin/bash
set -euo pipefail

# RLENV Build Script
# This script rebuilds the application from source located at /rlenv/source/rapidobj/
#
# Original image: ghcr.io/mayhemheroes/rapidobj:master
# Git revision: 86f42e0203d018b9898e87504cd369143db5728d

# ============================================================================
# Environment Variables
# ============================================================================
export CXX=clang++

# ============================================================================
# REQUIRED: Change to Source Directory
# ============================================================================
cd /rlenv/source/rapidobj/fuzz

# ============================================================================
# Clean Previous Build (recommended)
# ============================================================================
# Remove old build artifacts to ensure fresh rebuild
rm -f rapidobj-fuzz *.o

# ============================================================================
# Build Commands (NO NETWORK, NO PACKAGE INSTALLATION)
# ============================================================================
# Build the fuzzer using make (defined in Makefile)
# The Makefile compiles: clang++ -g -std=c++17 -fsanitize=fuzzer,address,undefined,nullability,integer,implicit-conversion
# -fno-sanitize-recover=undefined,nullability,integer,implicit-conversion rapidobj-fuzz.cpp -o rapidobj-fuzz
make

# ============================================================================
# Copy Artifacts (use 'cat >' for busybox compatibility)
# ============================================================================
# Copy the built fuzzer to the root directory where it's expected
cat rapidobj-fuzz > /rapidobj-fuzz

# ============================================================================
# Set Permissions
# ============================================================================
chmod 777 /rapidobj-fuzz 2>/dev/null || true

# 777 allows validation script (running as UID 1000) to overwrite during rebuild
# 2>/dev/null || true prevents errors if chmod not available

# ============================================================================
# REQUIRED: Verify Build Succeeded
# ============================================================================
if [ ! -f /rapidobj-fuzz ]; then
    echo "Error: Build artifact not found at /rapidobj-fuzz"
    exit 1
fi

# Verify executable bit
if [ ! -x /rapidobj-fuzz ]; then
    echo "Warning: Build artifact is not executable"
fi

# Verify file size
SIZE=$(stat -c%s /rapidobj-fuzz 2>/dev/null || stat -f%z /rapidobj-fuzz 2>/dev/null || echo 0)
if [ "$SIZE" -lt 1000 ]; then
    echo "Warning: Build artifact is suspiciously small ($SIZE bytes)"
fi

echo "Build completed successfully: /rapidobj-fuzz ($SIZE bytes)"
