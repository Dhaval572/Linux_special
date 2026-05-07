#!/bin/bash

# ============================================
# UNIVERSAL APPIMAGE CREATOR
# Edit ONLY these 3 variables for each project
# ============================================

# === EDIT THESE 3 LINES FOR YOUR PROJECT ===
BINARY_PATH="./build/app"     # ← CHANGE THIS: Path to your compiled binary
APP_NAME="Aim_practice"      # ← CHANGE THIS: Your app display name
APP_CATEGORY="Game"           # ← CHANGE THIS: Game, Development, Utility, Graphics, etc.
# ============================================

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Creating AppImage for: $APP_NAME${NC}"

# Check binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}ERROR: Binary not found at $BINARY_PATH${NC}"
    echo "Current directory: $(pwd)"
    echo "Files found: $(ls -la)"
    exit 1
fi

# Create AppDir
rm -rf AppDir
mkdir -p AppDir/usr/{bin,lib}

# Copy binary
cp "$BINARY_PATH" AppDir/usr/bin/app

# Auto-detect and copy libraries
echo "Detecting and copying libraries..."
ldd "$BINARY_PATH" | grep "=> /" | grep -v "libc\|libstdc++\|libm\|libgcc\|linux-vdso\|ld-linux" | awk '{print $3}' | while read lib; do
    if [ -f "$lib" ]; then
        cp "$lib" AppDir/usr/lib/ 2>/dev/null && echo "  ✓ $(basename $lib)"
    fi
done

# Create AppRun
cat > AppDir/AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/app" "$@"
EOF
chmod +x AppDir/AppRun

# Create desktop file
cat > AppDir/app.desktop << EOF
[Desktop Entry]
Name=$APP_NAME
Exec=app
Icon=app
Type=Application
Categories=$APP_CATEGORY;
EOF

# Create icon (simple placeholder)
touch AppDir/app.png

# Setup runtime
RUNTIME="$HOME/.local/share/appimagetool/runtime"
mkdir -p "$(dirname $RUNTIME)"

if [ ! -f "$RUNTIME" ]; then
    echo "Downloading runtime (one time only)..."
    curl -s -L -o "$RUNTIME" "https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-x86_64"
    chmod +x "$RUNTIME"
fi

# Create AppImage
OUTPUT="${APP_NAME}.AppImage"
echo "Packaging..."
cat "$RUNTIME" > "$OUTPUT"

if command -v mksquashfs &> /dev/null; then
    mksquashfs AppDir squashfs.tmp -noappend -root-owned -comp gzip 2>/dev/null
    cat squashfs.tmp >> "$OUTPUT"
    rm squashfs.tmp
else
    (cd AppDir && tar cf - .) | gzip -9 >> "$OUTPUT"
fi

chmod +x "$OUTPUT"
rm -rf AppDir

echo -e "${GREEN}✅ SUCCESS!${NC}"
echo -e "AppImage: ${GREEN}$OUTPUT${NC}"
echo -e "Size: $(du -h $OUTPUT | cut -f1)"
echo -e "Run: ${GREEN}./$OUTPUT${NC}"
