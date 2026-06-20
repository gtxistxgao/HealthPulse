#!/bin/bash
#
# HealthPulse - One-Click Project Setup
#
# This script:
# 1. Ensures an `xcodegen` command is available
#      - macOS: installs the real XcodeGen via Homebrew
#      - other platforms (e.g. Linux CI): installs the bundled fallback
#        generator so `xcodegen generate` works without a Swift toolchain
# 2. Generates the .xcodeproj file from project.yml
# 3. (macOS) Opens the project in Xcode
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "========================================="
echo "  HealthPulse - Project Setup"
echo "========================================="
echo ""

install_fallback_xcodegen() {
    # Install the bundled, dependency-light generator as `xcodegen` on PATH so
    # platforms without the real (macOS-only, Swift-based) XcodeGen can still
    # run `xcodegen generate`.
    local src="$SCRIPT_DIR/xcodegen"
    if [[ ! -f "$src" ]]; then
        echo "Error: fallback generator missing at $src" >&2
        return 1
    fi

    # Best-effort: make the full (scheme-aware) path available.
    python3 -m pip install --quiet --user pyyaml >/dev/null 2>&1 || true

    local installed=""
    for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/.bun/bin" "$HOME/bin"; do
        if mkdir -p "$dir" 2>/dev/null && cp "$src" "$dir/xcodegen" 2>/dev/null; then
            chmod +x "$dir/xcodegen" 2>/dev/null || true
            installed="$dir"
            echo "Installed fallback xcodegen to $dir/xcodegen"
        fi
    done

    if [[ -z "$installed" ]]; then
        echo "Warning: could not install xcodegen to a PATH directory." >&2
        return 1
    fi

    # Make it usable in this shell session too.
    export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
}

# 1. Ensure xcodegen is available.
if command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is already installed."
elif [[ "$(uname)" == "Darwin" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo "Installing XcodeGen..."
    brew install xcodegen
    echo "XcodeGen installed successfully."
else
    echo "Real XcodeGen is macOS-only; installing bundled fallback generator..."
    install_fallback_xcodegen
fi

# 2. Generate the .xcodeproj
echo ""
echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "========================================="
echo "  Project generated successfully!"
echo "========================================="
echo ""

# 3. On macOS, open in Xcode for convenience.
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Next steps:"
    echo "  1. The project will open in Xcode now"
    echo "  2. Select your Team in Signing & Capabilities"
    echo "  3. Connect your iPhone and Build (Cmd+R)"
    echo ""
    open HealthPulse.xcodeproj
fi

echo "Done!"
