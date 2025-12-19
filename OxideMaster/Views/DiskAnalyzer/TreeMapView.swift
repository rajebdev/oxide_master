//
//  TreeMapView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct TreeMapView: View {
    let files: [FileInfo]
    @State private var selectedFile: FileInfo?
    
    var body: some View {
        GeometryReader { geometry in
            let rects = calculateTreeMap(files: files, in: geometry.size)
            
            ZStack(alignment: .topLeading) {
                ForEach(Array(rects.enumerated()), id: \.offset) { index, item in
                    TreeMapRectangle(
                        file: item.file,
                        rect: item.rect,
                        isSelected: selectedFile?.id == item.file.id
                    )
                    .onTapGesture {
                        selectedFile = item.file
                    }
                }
            }
        }
        .padding()
    }
    
    /// Calculate treemap layout using squarified algorithm
    private func calculateTreeMap(files: [FileInfo], in size: CGSize) -> [(file: FileInfo, rect: CGRect)] {
        guard !files.isEmpty else { return [] }
        
        let totalSize = files.reduce(0) { $0 + $1.totalSize }
        guard totalSize > 0 else { return [] }
        
        var results: [(file: FileInfo, rect: CGRect)] = []
        var remainingFiles = files.sorted { $0.totalSize > $1.totalSize }
        var availableRect = CGRect(origin: .zero, size: size)
        
        while !remainingFiles.isEmpty {
            let file = remainingFiles.removeFirst()
            let ratio = CGFloat(file.totalSize) / CGFloat(totalSize)
            let area = size.width * size.height * ratio
            
            let width = availableRect.width
            let height = area / width
            
            let rect = CGRect(
                x: availableRect.minX,
                y: availableRect.minY,
                width: min(width, availableRect.width),
                height: min(height, availableRect.height)
            )
            
            results.append((file, rect))
            
            // Update available rect
            availableRect = CGRect(
                x: availableRect.minX,
                y: availableRect.minY + height,
                width: availableRect.width,
                height: max(0, availableRect.height - height)
            )
            
            if availableRect.height < 10 {
                break
            }
        }
        
        return results
    }
}

// MARK: - TreeMap Rectangle

struct TreeMapRectangle: View {
    let file: FileInfo
    let rect: CGRect
    let isSelected: Bool
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: file.typeColor).opacity(0.7))
                .frame(width: rect.width, height: rect.height)
            
            if rect.width > 50 && rect.height > 30 {
                VStack(spacing: 2) {
                    Text(file.name)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    
                    Text(file.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(4)
                .frame(width: rect.width, height: rect.height)
            }
            
            if isSelected || isHovering {
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

