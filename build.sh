#!/bin/bash
# Build script for WiFiGuard
# Run this on a machine with Theos installed (macOS/Linux/iOS)

set -e

echo "=== WiFiGuard Build Script ==="
echo ""

# Check if THEOS is set
if [ -z "$THEOS" ]; then
    echo "Error: THEOS environment variable not set"
    echo ""
    echo "Please install Theos first:"
    echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)\""
    echo ""
    echo "Then set the environment variable:"
    echo "  export THEOS=~/theos"
    exit 1
fi

echo "THEOS found at: $THEOS"
echo ""

# Clean previous build
echo "[1/3] Cleaning previous build..."
make clean 2>/dev/null || true

# Build package
echo "[2/3] Building package..."
make package THEOS_PACKAGE_SCHEME=rootless

# Show result
echo ""
echo "[3/3] Build complete!"
echo ""
echo "Package location:"
ls -la packages/*.deb 2>/dev/null || echo "No package found in packages/"

echo ""
echo "To install on device:"
echo "  scp packages/*.deb root@<device-ip>:/var/tmp/"
echo "  ssh root@<device-ip> 'dpkg -i /var/tmp/*.deb && uicache -a'"
