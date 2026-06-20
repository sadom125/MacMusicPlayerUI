import SwiftUI
import AppKit
import CoreImage

/// Extracts dominant color from album artwork for dynamic backgrounds.
class ColorExtractor {
    static let shared = ColorExtractor()

    private var cache: [UUID: Color] = [:]
    private let ciContext = CIContext()

    private init() {}

    /// Extract dominant color from artwork data.
    func dominantColor(from data: Data?, for trackID: UUID) -> Color {
        if let cached = cache[trackID] { return cached }

        guard let data = data,
              let nsImage = NSImage(data: data),
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return Color(red: 0.1, green: 0.1, blue: 0.15)
        }

        // Downsample to 1x1 to get average color
        let cgImage = bitmap.cgImage(forProposedRect: nil, context: nil, hints: nil)
        guard let cgImg = cgImage else {
            return Color(red: 0.1, green: 0.1, blue: 0.15)
        }

        let size = CGSize(width: 1, height: 1)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Color(red: 0.1, green: 0.1, blue: 0.15)
        }

        context.draw(cgImg, in: CGRect(origin: .zero, size: size))

        guard let data = context.data else {
            return Color(red: 0.1, green: 0.1, blue: 0.15)
        }

        let ptr = data.bindMemory(to: UInt8.self, capacity: 4)
        let r = Double(ptr[0]) / 255.0
        let g = Double(ptr[1]) / 255.0
        let b = Double(ptr[2]) / 255.0

        let color = Color(red: r, green: g, blue: b)
        cache[trackID] = color
        return color
    }

    /// Create a darker version of the color for background gradients.
    func darkerColor(from color: Color, factor: Double = 0.3) -> Color {
        return color.opacity(0.6)
    }

    /// Create a gradient palette from dominant color.
    func gradientColors(from dominantColor: Color) -> [Color] {
        return [
            dominantColor.opacity(0.8),
            dominantColor.opacity(0.4),
            dominantColor.opacity(0.2),
        ]
    }

    /// Clear cache for a specific track.
    func clearCache(for trackID: UUID) {
        cache.removeValue(forKey: trackID)
    }

    /// Clear all cached colors.
    func clearAllCache() {
        cache.removeAll()
    }
}
