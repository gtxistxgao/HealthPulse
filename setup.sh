#!/bin/bash
#
# HealthPulse - One-Click Project Setup
#
# This script:
# 1. Installs XcodeGen (if not already installed)
# 2. Generates the .xcodeproj file
# 3. Opens the project in Xcode
#
# Usage: Open Terminal, cd to this folder, then run:
#   chmod +x setup.sh
#   ./setup.sh
#

set -e

echo ""
echo "========================================="
echo "  HealthPulse - Project Setup"
echo "========================================="
echo ""

# Check if we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This script must be run on macOS."
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
    echo "XcodeGen installed successfully."
else
    echo "XcodeGen is already installed."
fi

# Navigate to project directory
cd "$(dirname "$0")"
echo ""
echo "Generating Xcode project..."

# Generate the .xcodeproj
xcodegen generate

echo ""
echo "========================================="
echo "  Project generated successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. The project will open in Xcode now"
echo "  2. Select your Team in Signing & Capabilities"
echo "     (Project → HealthPulse target → Signing)"
echo "  3. Connect your iPhone and Build (Cmd+R)"
echo ""

# Open in Xcode
open HealthPulse.xcodeproj

echo "Done! Happy coding!"
