import Foundation
import os

/// High-performance telemetry tracker for Apple Instruments using OSSignposter.
public struct PipelineSignposter: Sendable {
    public static let shared = PipelineSignposter()

    private let pointsOfInterestSignposter: OSSignposter
    private let pipelineSignposter: OSSignposter

    public init(subsystem: String = "com.scribemac.app") {
        let poiLogger = Logger(subsystem: subsystem, category: "PointsOfInterest")
        let pipeLogger = Logger(subsystem: subsystem, category: "PipelineExecution")

        self.pointsOfInterestSignposter = OSSignposter(logger: poiLogger)
        self.pipelineSignposter = OSSignposter(logger: pipeLogger)
    }

    // MARK: - 1. Phase: Resolve
    public func trackResolve<T: Sendable>(
        targetURL: URL,
        operation: () async throws -> T
    ) async throws -> T {
        let id = pipelineSignposter.makeSignpostID()
        let intervalState = pipelineSignposter.beginInterval("ResolveProvider", id: id)

        do {
            let result = try await operation()
            pipelineSignposter.endInterval("ResolveProvider", intervalState)
            return result
        } catch {
            pipelineSignposter.endInterval("ResolveProvider", intervalState)
            throw error
        }
    }

    // MARK: - 2. Phase: Download
    public func trackDownload<T: Sendable>(
        url: URL,
        operation: () async throws -> (T, bytesCount: Int64)
    ) async throws -> T {
        let id = pipelineSignposter.makeSignpostID()
        let intervalState = pipelineSignposter.beginInterval("StreamingDownload", id: id)

        pointsOfInterestSignposter.emitEvent("DownloadStarted", id: id)

        do {
            let (result, _) = try await operation()
            pipelineSignposter.endInterval("StreamingDownload", intervalState)
            return result
        } catch {
            pipelineSignposter.endInterval("StreamingDownload", intervalState)
            throw error
        }
    }

    // MARK: - 3. Phase: Validate
    public func trackValidation<T: Sendable>(
        operation: () throws -> T
    ) throws -> T {
        let id = pipelineSignposter.makeSignpostID()
        return try pipelineSignposter.withIntervalSignpost("ValidatePDF", id: id) {
            pointsOfInterestSignposter.emitEvent("CheckingMagicBytes", id: id)
            let result = try operation()
            pointsOfInterestSignposter.emitEvent("PDFValidatedOK", id: id)
            return result
        }
    }

    // MARK: - 4. Phase: Hash Computation
    public func trackHashComputation<T: Sendable>(
        fileSize: Int64,
        operation: () throws -> T
    ) throws -> T {
        let id = pipelineSignposter.makeSignpostID()
        let intervalState = pipelineSignposter.beginInterval("CryptoHashSHA256", id: id)

        do {
            let result = try operation()
            pipelineSignposter.endInterval("CryptoHashSHA256", intervalState)
            return result
        } catch {
            pipelineSignposter.endInterval("CryptoHashSHA256", intervalState)
            throw error
        }
    }
}
