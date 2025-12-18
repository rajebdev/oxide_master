#!/bin/bash

# DiskOxide - All-in-one build & run script

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
        echo "🔨 Building DiskOxide..."
        swift build -c release
        
        if [ $? -eq 0 ]; then
            echo "✅ Build successful!"
            
            # Kill existing
            pkill -f "DiskOxide.app" 2>/dev/null && echo "✅ Killed existing process"
            
            # Update bundle (preserve permissions)
            echo "📦 Updating app bundle..."
            mkdir -p DiskOxide.app/Contents/MacOS DiskOxide.app/Contents/Resources
            cp .build/release/DiskOxide DiskOxide.app/Contents/MacOS/
            cp DiskOxide/Info.plist DiskOxide.app/Contents/
            
            # Create and copy icon
            if [ -f "create_icns.sh" ]; then
                bash create_icns.sh > /dev/null 2>&1
            fi
            
            # Sign
            echo "🔏 Signing app..."
            codesign --force --deep --sign - DiskOxide.app 2>/dev/null
            
            sleep 0.5
            echo "🚀 Opening DiskOxide..."
            open DiskOxide.app
            echo "✅ Done!"
        else
            echo "❌ Build failed!"
            exit 1
        fi
        ;;
        
    clean)
        echo "🗑️  Cleaning..."
        rm -rf DiskOxide.app
        rm -rf .build
        
        echo "🔨 Building DiskOxide..."
        swift build -c release
        
        if [ $? -eq 0 ]; then
            echo "✅ Build successful!"
            
            pkill -f "DiskOxide.app" 2>/dev/null
            
            echo "📦 Creating app bundle..."
            mkdir -p DiskOxide.app/Contents/MacOS DiskOxide.app/Contents/Resources
            cp .build/release/DiskOxide DiskOxide.app/Contents/MacOS/
            cp DiskOxide/Info.plist DiskOxide.app/Contents/
            
            echo "🔏 Signing app..."
            codesign --force --deep --sign - DiskOxide.app 2>/dev/null
            
            sleep 0.5
            echo "🚀 Opening DiskOxide..."
            open DiskOxide.app
            echo "✅ Done! (New app - will ask for permissions)"
        else
            echo "❌ Build failed!"
            exit 1
        fi
        ;;
        
    run)
        echo "🔍 Checking for existing process..."
        pkill -f "DiskOxide.app" 2>/dev/null && echo "✅ Killed existing process"
        
        sleep 0.5
        echo "🚀 Opening DiskOxide..."
        open DiskOxide.app
        echo "✅ Done!"
        ;;
        
    reset)
        echo "🗑️  Resetting TCC permissions..."
        pkill -f "DiskOxide.app" 2>/dev/null
        tccutil reset All com.rajebdev.DiskOxide 2>/dev/null && echo "✅ Reset complete"
        echo ""
        echo "📝 If needed, manually remove in System Settings:"
        echo "   Privacy & Security > Files and Folders > DiskOxide"
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
