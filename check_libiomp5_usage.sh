#!/bin/bash
# Script: check_libiomp5_usage.sh
# Usage: ./check_libiomp5_usage.sh <your_binary>
# Purpose:
#  - Finds all libiomp5.so versions on the system
#  - Shows which version your app will actually use

APP="$1"

echo "========================================="
echo "🔍 Step 1: Searching for libiomp5.so files"
echo "========================================="

LIBS=$(find /opt /usr /lib* /home "$HOME" -type f -name 'libiomp5.so*' 2>/dev/null)

if [ -z "$LIBS" ]; then
    echo "✅ No libiomp5.so found on the system."
    exit 0
fi

declare -A LOADED_PATHS

i=1
for LIB in $LIBS; do
    echo "[$i] 📁 Found: $LIB"
    VERSION=$(strings "$LIB" | grep -E 'Intel\(R\) OpenMP|OpenMP runtime' | head -1)
    BUILD=$(strings "$LIB" | grep -i 'library version' | head -1)

    if [ -z "$VERSION" ] && [ -z "$BUILD" ]; then
        echo "    ⚠️  Could not extract version info."
    else
        echo "    🔢 Version: $VERSION"
        echo "    🏗️  Build: $BUILD"
    fi
    echo
    ((i++))
done

echo "============================================="
echo "🧪 Step 2: Detecting loaded libiomp5 in binary"
echo "============================================="

if [ -z "$APP" ]; then
    echo "ℹ️  No binary given. Skipping runtime check."
    echo "👉 Usage: ./check_libiomp5_usage.sh ./your_app"
    exit 0
fi

if [ ! -x "$APP" ]; then
    echo "❌ Error: '$APP' is not a valid executable."
    exit 1
fi

LOADED=$(ldd "$APP" 2>/dev/null | grep libiomp5)

if [ -z "$LOADED" ]; then
    echo "✅ '$APP' does not link to libiomp5."
else
    echo "🔗 '$APP' is linked to:"
    echo "$LOADED" | while read -r line; do
        echo "    $line"
    done
    echo

    LIB_PATH=$(echo "$LOADED" | awk '{print $3}')
    if [ -f "$LIB_PATH" ]; then
        echo "🔍 Inspecting linked libiomp5:"
        VERSION=$(strings "$LIB_PATH" | grep -E 'Intel\(R\) OpenMP|OpenMP runtime' | head -1)
        BUILD=$(strings "$LIB_PATH" | grep -i 'library version' | head -1)

        echo "    🔢 Version: $VERSION"
        echo "    🏗️  Build: $BUILD"
    fi
fi
echo "========================================="
echo "🔚 Done checking libiomp5 usage."