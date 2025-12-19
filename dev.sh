#!/bin/bash

# Oxide Master - All-in-one build & run script

show_usage() {
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build     - Build and run (default, preserves permissions)"
    echo "  clean     - Clean build (resets permissions)"
    echo "  run       - Run without building"
    echo "  reset     - Reset TCC permissions"
    echo "  dmg       - Create DMG installer"
    echo ""
    echo "Examples:"
    echo "  ./dev.sh           # Build and run"
    echo "  ./dev.sh build     # Same as above"
    echo "  ./dev.sh clean     # Full rebuild"
    echo "  ./dev.sh run       # Just open app"
    echo "  ./dev.sh dmg       # Create DMG file"
    exit 0
}

CMD="${1:-build}"

case "$CMD" in
    build)
        echo "🔨 Building Oxide Master..."
        swift build -c release
        
        if [ $? -eq 0 ]; then
            echo "✅ Build successful!"
            
            # Kill existing
            pkill -f "OxideMaster.app" 2>/dev/null && echo "✅ Killed existing process"
            
            # Update bundle (preserve permissions)
            echo "📦 Updating app bundle..."
            mkdir -p OxideMaster.app/Contents/MacOS OxideMaster.app/Contents/Resources
            cp .build/release/OxideMaster OxideMaster.app/Contents/MacOS/
            cp OxideMaster/Info.plist OxideMaster.app/Contents/
            
            # Create and copy icon
            echo "🎨 Creating app icon..."
            if [ -f "create_icns.sh" ]; then
                bash create_icns.sh
            fi
            
            # Sign
            echo "🔏 Signing app..."
            codesign --force --deep --sign - OxideMaster.app 2>/dev/null
            
            sleep 0.5
            echo "🚀 Opening Oxide Master..."
            open OxideMaster.app
            echo "✅ Done!"
        else
            echo "❌ Build failed!"
            exit 1
        fi
        ;;
        
    clean)
        echo "🗑️  Cleaning..."
        rm -rf OxideMaster.app
        rm -rf .build
        
        echo "🔨 Building Oxide Master..."
        swift build -c release
        
        if [ $? -eq 0 ]; then
            echo "✅ Build successful!"
            
            pkill -f "OxideMaster.app" 2>/dev/null
            
            echo "📦 Creating app bundle..."
            mkdir -p OxideMaster.app/Contents/MacOS OxideMaster.app/Contents/Resources
            cp .build/release/OxideMaster OxideMaster.app/Contents/MacOS/
            cp OxideMaster/Info.plist OxideMaster.app/Contents/
            
            echo "🔏 Signing app..."
            codesign --force --deep --sign - OxideMaster.app 2>/dev/null
            
            sleep 0.5
            echo "🚀 Opening Oxide Master..."
            open OxideMaster.app
            echo "✅ Done! (New app - will ask for permissions)"
        else
            echo "❌ Build failed!"
            exit 1
        fi
        ;;
        
    run)
        echo "🔍 Checking for existing process..."
        pkill -f "OxideMaster.app" 2>/dev/null && echo "✅ Killed existing process"
        
        sleep 0.5
        echo "🚀 Opening Oxide Master..."
        open OxideMaster.app
        echo "✅ Done!"
        ;;
        
    reset)
        echo "🗑️  Resetting TCC permissions..."
        pkill -f "OxideMaster.app" 2>/dev/null
        tccutil reset All com.rajebdev.OxideMaster 2>/dev/null && echo "✅ Reset complete"
        echo ""
        echo "📝 If needed, manually remove in System Settings:"
        echo "   Privacy & Security > Files and Folders > Oxide Master"
        ;;
        
    dmg)
        echo "📦 Creating DMG installer..."
        
        # Build first
        echo "🔨 Building Oxide Master..."
        swift build -c release
        
        if [ $? -ne 0 ]; then
            echo "❌ Build failed!"
            exit 1
        fi
        
        echo "✅ Build successful!"
        
        # Create app bundle
        echo "📦 Creating app bundle..."
        rm -rf OxideMaster.app
        mkdir -p OxideMaster.app/Contents/MacOS OxideMaster.app/Contents/Resources
        cp .build/release/OxideMaster OxideMaster.app/Contents/MacOS/
        cp OxideMaster/Info.plist OxideMaster.app/Contents/
        
        # Create and copy icon
        echo "🎨 Creating app icon..."
        if [ -f "create_icns.sh" ]; then
            bash create_icns.sh
        fi
        
        # Remove quarantine attributes
        echo "🔓 Removing quarantine attributes..."
        xattr -cr OxideMaster.app
        
        # Sign with entitlements
        echo "🔏 Signing app..."
        codesign --force --deep --sign - --options runtime OxideMaster.app 2>/dev/null || \
        codesign --force --deep --sign - OxideMaster.app 2>/dev/null
        
        # Create DMG
        APP_NAME="OxideMaster"
        VERSION="1.0.0"
        DMG_NAME="${APP_NAME}-${VERSION}.dmg"
        DMG_TEMP="dmg_temp"
        
        echo "💿 Creating DMG: $DMG_NAME"
        
        # Clean up old files
        rm -rf "$DMG_TEMP" "$DMG_NAME"
        
        # Create temp directory and copy app
        mkdir -p "$DMG_TEMP"
        cp -R OxideMaster.app "$DMG_TEMP/"
        
        # Clean quarantine attributes from copied app
        echo "🔓 Cleaning app in DMG..."
        xattr -cr "$DMG_TEMP/OxideMaster.app"
        
        # Sign again to ensure it's valid
        codesign --force --deep --sign - "$DMG_TEMP/OxideMaster.app" 2>/dev/null
        
        # Create symlink to Applications
        ln -s /Applications "$DMG_TEMP/Applications"
        
        # Create DMG
        hdiutil create -volname "$APP_NAME" \
                       -srcfolder "$DMG_TEMP" \
                       -ov -format UDZO \
                       "$DMG_NAME"
        
        # Clean up temp
        rm -rf "$DMG_TEMP"
        
        # Remove quarantine from DMG itself
        echo "🔓 Cleaning DMG file..."
        xattr -cr "$DMG_NAME" 2>/dev/null
        
        if [ -f "$DMG_NAME" ]; then
            echo "✅ DMG created successfully: $DMG_NAME"
            echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
        else
            echo "❌ Failed to create DMG!"
            exit 1
        fi
        ;;
        
    help|--help|-h)
        show_usage
        ;;
        
    *)
        echo "❌ Unknown command: $CMD"
        echo ""
        show_usage
        ;;
esac
