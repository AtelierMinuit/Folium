import Foundation
import os

/// Unified, privacy-safe logger for ScribeMac.
/// Categorized by subsystems. Never logs credentials, cookies, tokens, or auth headers.
public enum AppLogger {
    private static let subsystem = "com.scribemac.app"

    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let provider = Logger(subsystem: subsystem, category: "provider")
    public static let download = Logger(subsystem: subsystem, category: "download")
    public static let filesystem = Logger(subsystem: subsystem, category: "filesystem")
    public static let pdf = Logger(subsystem: subsystem, category: "pdf")
    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let general = Logger(subsystem: subsystem, category: "general")
}
