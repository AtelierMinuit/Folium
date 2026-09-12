# Testing

Tests cover URL normalization, validation, and core downloads.

- Uses `XCTest` primarily.
- Can be run via `xcodebuild -scheme FoliumTests test`.
- Includes a Python-based local web server (`Tests/Fixtures/run_test_server.sh`) for verifying HTTP behaviors like ranges, redirect handling, and valid/invalid PDFs.
