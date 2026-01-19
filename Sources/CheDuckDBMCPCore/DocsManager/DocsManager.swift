import Foundation

/// Manages DuckDB documentation download, caching, and access
public actor DocsManager {
    /// Documentation URL
    private static let docsURL = "https://blobs.duckdb.org/docs/duckdb-docs.md"

    /// Cache directory (shared with the integrated MCP)
    private static let cacheDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/che-duckdb-mcp")
    }()

    /// Cache file path
    private static let cacheFile: URL = {
        cacheDir.appendingPathComponent("duckdb-docs.md")
    }()

    /// Cache expiration time (24 hours)
    private static let cacheExpirationSeconds: TimeInterval = 24 * 60 * 60

    /// Parsed documentation sections
    private var sections: [Section] = []

    /// Raw markdown content
    private var rawContent: String = ""

    /// Last update time
    private var lastUpdated: Date?

    /// Whether documentation is loaded
    private var isLoaded: Bool = false

    // MARK: - Public Interface

    public init() {}

    /// Initialize and load documentation
    public func initialize() async throws {
        try await loadDocs()
    }

    /// Get documentation info
    public func getDocInfo() -> DocInfo {
        DocInfo(
            source: Self.docsURL,
            cachePath: Self.cacheFile.path,
            lastUpdated: lastUpdated,
            sectionCount: sections.count,
            contentSize: rawContent.count,
            isLoaded: isLoaded
        )
    }

    /// Force refresh documentation from source
    public func refresh() async throws {
        try await downloadDocs()
        try parseDocs()
    }

    /// Get all sections
    public func getAllSections() -> [Section] {
        sections
    }

    /// Get sections by level
    public func getSections(level: Int? = nil, parentId: String? = nil) -> [Section] {
        var result = sections

        if let level = level {
            result = result.filter { $0.level == level }
        }

        if let parentId = parentId {
            result = result.filter { $0.parentId == parentId }
        }

        return result
    }

    /// Get section by ID or title
    public func getSection(id: String? = nil, title: String? = nil, includeChildren: Bool = true) -> Section? {
        var section: Section?

        if let id = id {
            section = sections.first { $0.id == id }
        } else if let title = title {
            // Fuzzy match on title
            let lowerTitle = title.lowercased()
            section = sections.first { $0.title.lowercased().contains(lowerTitle) }
        }

        if var result = section, includeChildren {
            result.children = sections.filter { $0.parentId == result.id }
            return result
        }

        return section
    }

    /// Search documentation
    public func search(query: String, mode: SearchMode = .all, limit: Int = 10) -> [SearchResult] {
        let lowerQuery = query.lowercased()
        var results: [SearchResult] = []

        for section in sections {
            var score = 0
            var matches: [String] = []

            // Title match
            if mode == .title || mode == .all {
                if section.title.lowercased().contains(lowerQuery) {
                    score += 10
                    matches.append("title")
                }
            }

            // Content match
            if mode == .content || mode == .all {
                if section.content.lowercased().contains(lowerQuery) {
                    score += 5
                    matches.append("content")
                }
            }

            if score > 0 {
                results.append(SearchResult(
                    section: section,
                    score: score,
                    matches: matches,
                    snippet: extractSnippet(from: section.content, around: lowerQuery)
                ))
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        return Array(results.prefix(limit))
    }

    /// Get raw content
    public func getRawContent() -> String {
        rawContent
    }

    // MARK: - Private Methods

    private func loadDocs() async throws {
        // Check if cache exists and is valid
        if isCacheValid() {
            try loadFromCache()
        } else {
            try await downloadDocs()
        }

        try parseDocs()
        isLoaded = true
    }

    private func isCacheValid() -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.cacheFile.path) else {
            return false
        }

        do {
            let attrs = try fm.attributesOfItem(atPath: Self.cacheFile.path)
            if let modDate = attrs[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modDate)
                return age < Self.cacheExpirationSeconds
            }
        } catch {
            return false
        }

        return false
    }

    private func loadFromCache() throws {
        rawContent = try String(contentsOf: Self.cacheFile, encoding: .utf8)
        let attrs = try FileManager.default.attributesOfItem(atPath: Self.cacheFile.path)
        lastUpdated = attrs[.modificationDate] as? Date
    }

    private func downloadDocs() async throws {
        guard let url = URL(string: Self.docsURL) else {
            throw DocsError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DocsError.downloadFailed
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw DocsError.invalidContent
        }

        // Ensure cache directory exists
        try FileManager.default.createDirectory(at: Self.cacheDir, withIntermediateDirectories: true)

        // Save to cache
        try content.write(to: Self.cacheFile, atomically: true, encoding: .utf8)

        rawContent = content
        lastUpdated = Date()
    }

    private func parseDocs() throws {
        let parser = MarkdownParser()
        sections = parser.parse(rawContent)
    }

    private func extractSnippet(from content: String, around query: String, contextChars: Int = 100) -> String {
        guard let range = content.lowercased().range(of: query) else {
            // Return first contextChars if query not found
            let endIndex = content.index(content.startIndex, offsetBy: min(contextChars, content.count))
            return String(content[..<endIndex]) + "..."
        }

        // Convert to character positions
        let matchStart = content.distance(from: content.startIndex, to: range.lowerBound)
        let snippetStart = max(0, matchStart - contextChars / 2)
        let snippetEnd = min(content.count, matchStart + query.count + contextChars / 2)

        let startIdx = content.index(content.startIndex, offsetBy: snippetStart)
        let endIdx = content.index(content.startIndex, offsetBy: snippetEnd)

        var snippet = String(content[startIdx..<endIdx])

        if snippetStart > 0 {
            snippet = "..." + snippet
        }
        if snippetEnd < content.count {
            snippet = snippet + "..."
        }

        return snippet
    }
}

// MARK: - Supporting Types

/// Documentation section
public struct Section: Codable, Sendable {
    public let id: String
    public let title: String
    public let level: Int
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public var parentId: String?
    public var children: [Section]

    public init(id: String, title: String, level: Int, content: String,
                startLine: Int, endLine: Int, parentId: String? = nil, children: [Section] = []) {
        self.id = id
        self.title = title
        self.level = level
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
        self.parentId = parentId
        self.children = children
    }
}

/// Documentation info
public struct DocInfo: Codable, Sendable {
    public let source: String
    public let cachePath: String
    public let lastUpdated: Date?
    public let sectionCount: Int
    public let contentSize: Int
    public let isLoaded: Bool
}

/// Search mode
public enum SearchMode: String, Codable, Sendable {
    case title
    case content
    case all
}

/// Search result
public struct SearchResult: Codable, Sendable {
    public let section: Section
    public let score: Int
    public let matches: [String]
    public let snippet: String
}

/// Documentation errors
public enum DocsError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidContent
    case notLoaded
    case sectionNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid documentation URL"
        case .downloadFailed:
            return "Failed to download documentation"
        case .invalidContent:
            return "Invalid documentation content"
        case .notLoaded:
            return "Documentation not loaded"
        case .sectionNotFound:
            return "Section not found"
        }
    }
}
