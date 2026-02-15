#!/bin/bash
# CE Easy Trainer - Environment Setup
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "=== CE Easy Trainer Setup ==="

# Check git
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get update && apt-get install -y git
fi

# Clone Cheat Engine source if not exists
if [ ! -d "cheat-engine" ]; then
    echo "Cloning Cheat Engine source..."
    git clone --depth 1 https://github.com/cheat-engine/cheat-engine.git cheat-engine
fi

# Create build directories
mkdir -p build/{bin,obj,lib}

# Check for Lazarus (Windows only for actual build)
if command -v lazbuild &> /dev/null; then
    echo "Lazarus found: $(lazbuild --version)"
else
    echo "Note: Lazarus/FPC required for Windows build"
    echo "Download from: https://sourceforge.net/projects/lazarus/"
fi

echo "=== Setup Complete ==="
echo "Project root: $PROJECT_ROOT"
