import Foundation
@preconcurrency import QuickLookThumbnailing
import AppKit
import CoreGraphics

/// Asynchronous, out-of-process thumbnail generator using QuickLookThumbnailing.
/// Offloads rendering from the main thread and avoids parsing large PDFs in RAM.
public final class ThumbnailService: Sendable {
    public static let shared = ThumbnailService()

    private nonisolated(unsafe) let generator = QLThumbnailGenerator.shared

    public init() {}

    /// Generates a CGImage representation asynchronously off the main actor.
    public func generateCGImage(
        for fileURL: URL,
        targetSize: CGSize = CGSize(width: 300, height: 400),
        scale: CGFloat = 2.0
    ) async throws -> CGImage {
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: targetSize,
            scale: scale,
            representationTypes: .thumbnail
        )

        return try await withTaskCancellationHandler {
            let representation = try await generator.generateBestRepresentation(for: request)
            return representation.cgImage
        } onCancel: {
            self.generator.cancel(request)
        }
    }

    /// Convenience method for MainActor UI consumption returning NSImage.
    @MainActor
    public func generateNSImage(
        for fileURL: URL,
        targetSize: CGSize = CGSize(width: 300, height: 400),
        scale: CGFloat? = nil
    ) async throws -> NSImage {
        let backingScale = scale ?? (NSScreen.main?.backingScaleFactor ?? 2.0)
        let cgImage = try await generateCGImage(for: fileURL, targetSize: targetSize, scale: backingScale)

        let sizeInPoints = CGSize(
            width: CGFloat(cgImage.width) / backingScale,
            height: CGFloat(cgImage.height) / backingScale
        )
        return NSImage(cgImage: cgImage, size: sizeInPoints)
    }
}
