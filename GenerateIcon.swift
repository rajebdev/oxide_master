#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

class IconGenerator {

    // MARK: - Oxide Master Icon

    static func createOxideMasterIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let cornerRadius = size * 0.2237  // macOS icon standard

        // Create rounded rectangle path
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Clip to rounded rectangle
        path.addClip()

        // Background gradient (vibrant orange)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors =
            [
                CGColor(red: 255 / 255, green: 159 / 255, blue: 10 / 255, alpha: 1.0),  // Bright orange
                CGColor(red: 255 / 255, green: 137 / 255, blue: 0 / 255, alpha: 1.0),  // Mid orange
                CGColor(red: 247 / 255, green: 119 / 255, blue: 5 / 255, alpha: 1.0),  // Deep orange
            ] as CFArray

        if let gradient = CGGradient(
            colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.5, 1.0])
        {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: size / 2, y: size),
                end: CGPoint(x: size / 2, y: 0),
                options: []
            )
        }

        // Add subtle texture
        context.saveGState()
        context.setBlendMode(.overlay)
        context.setAlpha(0.08)

        for i in stride(from: 0, to: Int(size), by: 3) {
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: 0, y: CGFloat(i)))
            context.addLine(to: CGPoint(x: size, y: CGFloat(i)))
            context.strokePath()
        }
        context.restoreGState()

        // Draw hard disk icon
        let cx = size / 2
        let cy = size / 2
        let scale = size / 1024

        // Disk platter (circular) - larger size
        let platterRadius = 380 * scale
        let platterRect = CGRect(
            x: cx - platterRadius,
            y: cy - platterRadius,
            width: platterRadius * 2,
            height: platterRadius * 2
        )

        // Platter gradient (white/light gray)
        let platterGradient = NSGradient(
            colors: [
                NSColor(red: 250 / 255, green: 250 / 255, blue: 250 / 255, alpha: 1.0),
                NSColor(red: 230 / 255, green: 230 / 255, blue: 235 / 255, alpha: 1.0),
            ]
        )

        let platterPath = NSBezierPath(ovalIn: platterRect)
        platterPath.addClip()
        platterGradient?.draw(
            from: CGPoint(x: cx, y: cy + platterRadius),
            to: CGPoint(x: cx, y: cy - platterRadius),
            options: [])

        // Reset clip
        context.resetClip()
        path.addClip()

        // Disk tracks (circular lines)
        context.setStrokeColor(
            NSColor(red: 200 / 255, green: 200 / 255, blue: 205 / 255, alpha: 1.0).cgColor)
        context.setLineWidth(6 * scale)

        for i in 1...5 {
            let trackRadius = CGFloat(i) * 60 * scale
            let trackRect = CGRect(
                x: cx - trackRadius,
                y: cy - trackRadius,
                width: trackRadius * 2,
                height: trackRadius * 2
            )
            context.strokeEllipse(in: trackRect)
        }

        // Center hub
        let hubRadius = 65 * scale
        let hubPath = NSBezierPath(
            ovalIn: CGRect(
                x: cx - hubRadius,
                y: cy - hubRadius,
                width: hubRadius * 2,
                height: hubRadius * 2
            ))

        NSColor(red: 40 / 255, green: 40 / 255, blue: 45 / 255, alpha: 1.0).setFill()
        hubPath.fill()

        // Read/write arm
        let armWidth = 180 * scale
        let armHeight = 25 * scale
        let armPath = NSBezierPath()

        // Arm starting from center, going to upper right
        armPath.move(to: CGPoint(x: cx, y: cy))
        armPath.line(to: CGPoint(x: cx + armWidth, y: cy + armHeight / 2))
        armPath.line(to: CGPoint(x: cx + armWidth + 20 * scale, y: cy + armHeight / 2))
        armPath.line(to: CGPoint(x: cx + armWidth + 15 * scale, y: cy - armHeight / 2))
        armPath.line(to: CGPoint(x: cx + armWidth, y: cy - armHeight / 2))
        armPath.line(to: CGPoint(x: cx, y: cy - armHeight))
        armPath.close()

        NSColor(red: 90 / 255, green: 90 / 255, blue: 100 / 255, alpha: 1.0).setFill()
        armPath.fill()

        // Read head
        let headPath = NSBezierPath()
        headPath.move(to: CGPoint(x: cx + armWidth + 15 * scale, y: cy + armHeight / 2))
        headPath.line(to: CGPoint(x: cx + armWidth + 30 * scale, y: cy + armHeight))
        headPath.line(to: CGPoint(x: cx + armWidth + 35 * scale, y: cy))
        headPath.line(to: CGPoint(x: cx + armWidth + 30 * scale, y: cy - armHeight))
        headPath.line(to: CGPoint(x: cx + armWidth + 15 * scale, y: cy - armHeight / 2))
        headPath.close()

        NSColor(red: 110 / 255, green: 110 / 255, blue: 120 / 255, alpha: 1.0).setFill()
        headPath.fill()

        // Add glossy overlay (macOS style)
        context.saveGState()

        let glossPath = NSBezierPath(
            ovalIn: CGRect(
                x: size * 0.1,
                y: size * 0.5,
                width: size * 0.8,
                height: size * 0.6
            ))
        glossPath.addClip()

        let glossGradient = NSGradient(
            colors: [
                NSColor.white.withAlphaComponent(0.25),
                NSColor.white.withAlphaComponent(0.0),
            ]
        )

        glossGradient?.draw(
            from: CGPoint(x: size / 2, y: size),
            to: CGPoint(x: size / 2, y: size * 0.3),
            options: []
        )

        context.restoreGState()

        image.unlockFocus()

        return image
    }

    // MARK: - Save Functions

    static func saveIcon(_ image: NSImage, size: Int, name: String, retina: Bool = false) {
        guard let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            print("❌ Failed to create PNG for size \(size)")
            return
        }

        let filename = retina ? "\(name)_\(size/2)@2x.png" : "\(name)_\(size).png"
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filename)

        do {
            try pngData.write(to: url)
            print("  ✅ Created \(filename)")
        } catch {
            print("  ❌ Error saving \(filename): \(error)")
        }
    }
}

// MARK: - Main

print("🎨 Generating Oxide Master icons with vibrant orange & disk...")
print("")

let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    print("🔧 Creating \(size)x\(size) icon...")
    let image = IconGenerator.createOxideMasterIcon(size: CGFloat(size))
    IconGenerator.saveIcon(image, size: size, name: "oxide_master_swift")
}

print("")
print("🔧 Creating @2x versions...")

for size in [16, 32, 128, 256, 512] {
    let doubleSize = size * 2
    print("  Creating \(size)x\(size)@2x (\(doubleSize)x\(doubleSize))...")
    let image = IconGenerator.createOxideMasterIcon(size: CGFloat(doubleSize))
    IconGenerator.saveIcon(image, size: doubleSize, name: "oxide_master_swift", retina: true)
}

print("")
print("✅ All icons generated successfully!")
print("")
print("Generated files:")
for size in sizes {
    print("  - oxide_master_swift_\(size).png")
}
print("")
print("@2x versions:")
for size in [16, 32, 128, 256, 512] {
    print("  - oxide_master_swift_\(size)@2x.png")
}
