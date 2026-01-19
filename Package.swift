// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheDuckDBMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CheDuckDBMCPCore",
            targets: ["CheDuckDBMCPCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/duckdb/duckdb-swift.git", from: "1.0.0")
    ],
    targets: [
        // Core library containing DocsManager, DatabaseManager, and server logic
        .target(
            name: "CheDuckDBMCPCore",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "DuckDB", package: "duckdb-swift")
            ],
            path: "Sources/CheDuckDBMCPCore"
        ),
        // Executable entry point
        .executableTarget(
            name: "CheDuckDBMCP",
            dependencies: ["CheDuckDBMCPCore"],
            path: "Sources/CheDuckDBMCP"
        )
    ]
)
