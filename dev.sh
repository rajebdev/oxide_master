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
    echo ""
    echo "Examples:"
    echo "  ./dev.sh           # Build and run"
    echo "  ./dev.sh build     # Same as above"
    echo "  ./dev.sh clean     # Full rebuild"
    echo "  ./dev.sh run       # Just open app"
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
        
    help|--help|-h)
        show_usage
        ;;
        
    *)
        echo "❌ Unknown command: $CMD"
        echo ""
        show_usage
        ;;
esac
