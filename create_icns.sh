#!/bin/bash

# Create .icns file from PNG images
# This script converts the generated PNGs into a proper macOS .icns file

ICONSET_DIR="AppIcon.iconset"
ASSETS_DIR="OxideMaster/Assets.xcassets/AppIcon.appiconset"
OUTPUT_ICNS="OxideMaster.app/Contents/Resources/AppIcon.icns"

# Remove old iconset if exists
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Copy and rename files to iconset format
cp "$ASSETS_DIR/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
cp "$ASSETS_DIR/icon_16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ASSETS_DIR/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
cp "$ASSETS_DIR/icon_32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ASSETS_DIR/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
cp "$ASSETS_DIR/icon_128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ASSETS_DIR/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
cp "$ASSETS_DIR/icon_256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ASSETS_DIR/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
cp "$ASSETS_DIR/icon_512x512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"

# Create .icns file
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Cleanup
rm -rf "$ICONSET_DIR"

if [ -f "$OUTPUT_ICNS" ]; then
    echo "✅ Icon file created: $OUTPUT_ICNS"
else
    echo "❌ Failed to create icon file"
    exit 1
fi
