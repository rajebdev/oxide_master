//
//  LiquidGlass.swift
//  OxideMaster
//
//  macOS 26 Liquid Glass Design System
//  Created on 2025-12-24.
//

import SwiftUI

// MARK: - Glass Material View Modifier

/// Creates a frosted glass effect with blur and subtle border
struct GlassMaterial: ViewModifier {
    var cornerRadius: CGFloat = 12
    var opacity: Double = 0.6
    var blurRadius: CGFloat = 20
    
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base blur effect using native material
                    if colorScheme == .dark {
                        Color.white.opacity(0.05)
                    } else {
                        Color.black.opacity(0.03)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - Glass Extensions

extension View {
    /// Apply liquid glass material effect
    func glassMaterial(cornerRadius: CGFloat = 12, opacity: Double = 0.6) -> some View {
        modifier(GlassMaterial(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    /// Apply sidebar glass background
    func sidebarGlass() -> some View {
        self.background(.ultraThinMaterial)
    }
}

// MARK: - Liquid Glass Colors

struct LiquidGlassColors {
    @Environment(\.colorScheme) static var colorScheme
    
    // Primary accent - Similar to macOS 26 blue
    static let accent = Color(red: 0.25, green: 0.52, blue: 0.96)
    
    // Selection background
    static let selectionBackground = Color.white.opacity(0.1)
    static let selectionBackgroundHover = Color.white.opacity(0.08)
    
    // Sidebar
    static let sidebarBackground = Color.clear
    static let sidebarItemHover = Color.white.opacity(0.06)
    static let sidebarItemSelected = Color.white.opacity(0.12)
    
    // Glass borders
    static let glassBorder = Color.white.opacity(0.1)
    static let glassBorderLight = Color.white.opacity(0.05)
    
    // Text
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let accentText = accent
}

// MARK: - Liquid Glass Sidebar Button (Xcode-style)

struct LiquidGlassSidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Flat icon - no background, just colored when selected
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(textColor)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                // Full-width selection highlight like Xcode
                if isSelected || isHovering {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(backgroundColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.15)
                : Color.black.opacity(0.08)
        } else if isHovering {
            return colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.04)
        }
        return .clear
    }
    
    private var iconColor: Color {
        if isSelected {
            return LiquidGlassColors.accent
        }
        return colorScheme == .dark 
            ? Color.white.opacity(0.7) 
            : Color.black.opacity(0.6)
    }
    
    private var textColor: Color {
        return colorScheme == .dark 
            ? Color.white.opacity(isSelected ? 1.0 : 0.85) 
            : Color.black.opacity(isSelected ? 1.0 : 0.75)
    }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    
    @Environment(\.colorScheme) var colorScheme
    
    init(padding: CGFloat = 16, cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.05)
                          : Color.black.opacity(0.03))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - Liquid Glass Toolbar

struct LiquidGlassToolbar<Content: View>: View {
    let content: Content
    
    @Environment(\.colorScheme) var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Rectangle()
                    .fill(colorScheme == .dark
                          ? Color.black.opacity(0.3)
                          : Color.white.opacity(0.5))
                    .background(.ultraThinMaterial)
            }
    }
}

// MARK: - Liquid Glass Divider

struct LiquidGlassDivider: View {
    var horizontal: Bool = true
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark
                  ? Color.white.opacity(0.08)
                  : Color.black.opacity(0.08))
            .frame(width: horizontal ? nil : 0.5, height: horizontal ? 0.5 : nil)
    }
}

// MARK: - Animated Hover Effect

struct HoverScale: ViewModifier {
    @State private var isHovering = false
    var scale: CGFloat = 1.02
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func hoverScale(_ scale: CGFloat = 1.02) -> some View {
        modifier(HoverScale(scale: scale))
    }
}
