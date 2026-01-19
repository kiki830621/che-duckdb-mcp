import Foundation

/// Specialized search engine for DuckDB documentation
/// Provides fuzzy search, function lookup, and SQL syntax search
public struct SearchEngine {

    public init() {}

    // MARK: - Function Search

    /// Find function documentation
    /// Searches for functions like read_csv, json_extract, etc.
    public func findFunction(name: String, in sections: [Section]) -> FunctionDoc? {
        let lowerName = name.lowercased()

        // Look for exact function name match in section titles
        for section in sections {
            let lowerTitle = section.title.lowercased()

            // Check if title contains function name
            if lowerTitle.contains(lowerName) ||
               lowerTitle.contains(lowerName.replacingOccurrences(of: "_", with: " ")) {
                return extractFunctionDoc(from: section)
            }
        }

        // Fallback: search in content
        for section in sections {
            if section.content.lowercased().contains("\(lowerName)(") ||
               section.content.lowercased().contains("`\(lowerName)`") {
                return extractFunctionDoc(from: section)
            }
        }

        return nil
    }

    /// List all functions found in documentation
    public func listFunctions(in sections: [Section]) -> [String] {
        var functions = Set<String>()

        // Regex patterns for function names
        let patterns = [
            #"([a-z_]+)\("#,           // function_name(
            #"`([a-z_]+)`\("#,         // `function_name`(
        ]

        for section in sections {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(section.content.startIndex..., in: section.content)
                    let matches = regex.matches(in: section.content, options: [], range: range)

                    for match in matches {
                        if let funcRange = Range(match.range(at: 1), in: section.content) {
                            let funcName = String(section.content[funcRange])
                            // Filter out common non-function words
                            if !isCommonWord(funcName) && funcName.count > 2 {
                                functions.insert(funcName)
                            }
                        }
                    }
                }
            }
        }

        return functions.sorted()
    }

    // MARK: - SQL Syntax Search

    /// Find SQL syntax documentation
    public func findSQLSyntax(statement: String, in sections: [Section]) -> SQLSyntaxDoc? {
        let lowerStatement = statement.lowercased()

        // Common SQL statements
        let sqlKeywords = [
            "select", "insert", "update", "delete", "create", "drop", "alter",
            "copy", "export", "import", "attach", "detach", "use", "describe",
            "explain", "analyze", "vacuum", "checkpoint", "pragma", "set"
        ]

        // Find matching keyword
        let keyword = sqlKeywords.first { lowerStatement.contains($0) } ?? lowerStatement

        // Search for section about this SQL statement
        for section in sections {
            let lowerTitle = section.title.lowercased()

            if lowerTitle.contains(keyword) &&
               (lowerTitle.contains("statement") || lowerTitle.contains("syntax") ||
                lowerTitle.contains("clause") || section.level <= 2) {
                return extractSQLSyntaxDoc(from: section, keyword: keyword)
            }
        }

        // Fallback: content search
        for section in sections {
            if section.content.lowercased().contains("\(keyword) ") &&
               section.content.lowercased().contains("syntax") {
                return extractSQLSyntaxDoc(from: section, keyword: keyword)
            }
        }

        return nil
    }

    // MARK: - Fuzzy Search

    /// Perform fuzzy search with typo tolerance
    public func fuzzySearch(query: String, in sections: [Section], limit: Int = 10) -> [FuzzySearchResult] {
        let lowerQuery = query.lowercased()
        var results: [FuzzySearchResult] = []

        for section in sections {
            let titleScore = fuzzyScore(query: lowerQuery, target: section.title.lowercased())
            let contentScore = fuzzyScore(query: lowerQuery, target: section.content.lowercased()) / 2

            let totalScore = max(titleScore, contentScore)

            if totalScore > 0 {
                results.append(FuzzySearchResult(
                    section: section,
                    score: totalScore,
                    matchedIn: titleScore > contentScore ? "title" : "content"
                ))
            }
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    // MARK: - Private Helpers

    private func extractFunctionDoc(from section: Section) -> FunctionDoc {
        // Try to extract signature from content
        let signature = extractSignature(from: section.content)

        // Try to extract parameter list
        let parameters = extractParameters(from: section.content)

        // Try to extract return type
        let returnType = extractReturnType(from: section.content)

        return FunctionDoc(
            name: section.title,
            signature: signature,
            description: section.content,
            parameters: parameters,
            returnType: returnType,
            sectionId: section.id
        )
    }

    private func extractSQLSyntaxDoc(from section: Section, keyword: String) -> SQLSyntaxDoc {
        // Try to find syntax block (usually in code blocks)
        let syntax = extractCodeBlock(from: section.content, containing: keyword)

        return SQLSyntaxDoc(
            statement: keyword.uppercased(),
            syntax: syntax ?? "See documentation",
            description: section.content,
            sectionId: section.id
        )
    }

    private func extractSignature(from content: String) -> String? {
        // Look for function signature patterns
        let patterns = [
            #"```\n([^`]+\([^)]*\)[^`]*)\n```"#,  // Code block with function
            #"`([^`]+\([^)]*\))`"#,                // Inline code with function
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, options: [], range: range),
                   let sigRange = Range(match.range(at: 1), in: content) {
                    return String(content[sigRange])
                }
            }
        }

        return nil
    }

    private func extractParameters(from content: String) -> [String] {
        var params: [String] = []

        // Look for parameter list patterns
        let pattern = #"\|\s*`?([a-z_]+)`?\s*\|[^|]+\|"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)

            for match in matches {
                if let paramRange = Range(match.range(at: 1), in: content) {
                    params.append(String(content[paramRange]))
                }
            }
        }

        return params
    }

    private func extractReturnType(from content: String) -> String? {
        // Look for return type patterns
        let patterns = [
            #"returns?\s+(?:a\s+)?`?([A-Z][A-Za-z]+)`?"#,
            #"→\s*`?([A-Z][A-Za-z]+)`?"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, options: [], range: range),
                   let typeRange = Range(match.range(at: 1), in: content) {
                    return String(content[typeRange])
                }
            }
        }

        return nil
    }

    private func extractCodeBlock(from content: String, containing keyword: String) -> String? {
        let pattern = #"```(?:sql)?\n([^`]+)\n```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)

            for match in matches {
                if let blockRange = Range(match.range(at: 1), in: content) {
                    let block = String(content[blockRange])
                    if block.lowercased().contains(keyword.lowercased()) {
                        return block.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return nil
    }

    private func fuzzyScore(query: String, target: String) -> Int {
        // Simple fuzzy matching - counts character matches in order
        var score = 0
        var queryIndex = query.startIndex

        for char in target {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                score += 1
                queryIndex = query.index(after: queryIndex)
            }
        }

        // Bonus for exact substring match
        if target.contains(query) {
            score += query.count * 2
        }

        return score
    }

    private func isCommonWord(_ word: String) -> Bool {
        let common = ["the", "and", "for", "from", "with", "this", "that", "are", "was", "were", "has", "have", "had", "not", "all", "can", "but", "use", "set", "get"]
        return common.contains(word.lowercased())
    }
}

// MARK: - Supporting Types

/// Function documentation
public struct FunctionDoc: Codable, Sendable {
    public let name: String
    public let signature: String?
    public let description: String
    public let parameters: [String]
    public let returnType: String?
    public let sectionId: String
}

/// SQL syntax documentation
public struct SQLSyntaxDoc: Codable, Sendable {
    public let statement: String
    public let syntax: String
    public let description: String
    public let sectionId: String
}

/// Fuzzy search result
public struct FuzzySearchResult: Codable, Sendable {
    public let section: Section
    public let score: Int
    public let matchedIn: String
}
