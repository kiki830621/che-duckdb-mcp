import Foundation

/// Formats query results in various output formats
public struct ResultFormatter {

    /// Output format options
    public enum Format: String, Codable, Sendable {
        case json
        case markdown
        case csv
    }

    public init() {}

    /// Format a query result set
    /// - Parameters:
    ///   - result: Query result set
    ///   - format: Output format
    /// - Returns: Formatted string
    public func format(_ result: QueryResultSet, as format: Format) -> String {
        switch format {
        case .json:
            return formatAsJSON(result)
        case .markdown:
            return formatAsMarkdown(result)
        case .csv:
            return formatAsCSV(result)
        }
    }

    // MARK: - JSON Format

    private func formatAsJSON(_ result: QueryResultSet) -> String {
        var jsonRows: [[String: Any?]] = []

        for row in result.rows {
            var jsonRow: [String: Any?] = [:]
            for (idx, column) in result.columns.enumerated() {
                let value = row[idx]
                // Try to parse numeric values
                if let val = value {
                    if let intVal = Int64(val) {
                        jsonRow[column] = intVal
                    } else if let doubleVal = Double(val) {
                        jsonRow[column] = doubleVal
                    } else if val.lowercased() == "true" {
                        jsonRow[column] = true
                    } else if val.lowercased() == "false" {
                        jsonRow[column] = false
                    } else {
                        jsonRow[column] = val
                    }
                } else {
                    jsonRow[column] = nil
                }
            }
            jsonRows.append(jsonRow)
        }

        // Convert to JSON string
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonRows, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }

    // MARK: - Markdown Format

    private func formatAsMarkdown(_ result: QueryResultSet) -> String {
        guard !result.columns.isEmpty else {
            return "_No columns_"
        }

        guard !result.rows.isEmpty else {
            return formatMarkdownHeader(result.columns) + "\n_No rows_"
        }

        var lines: [String] = []

        // Calculate column widths
        var widths: [Int] = result.columns.map { $0.count }
        for row in result.rows {
            for (idx, cell) in row.enumerated() {
                let len = (cell ?? "NULL").count
                widths[idx] = max(widths[idx], len)
            }
        }

        // Header row
        let header = "| " + result.columns.enumerated().map { idx, col in
            col.padding(toLength: widths[idx], withPad: " ", startingAt: 0)
        }.joined(separator: " | ") + " |"
        lines.append(header)

        // Separator row with alignment hints
        let separator = "|" + widths.enumerated().map { idx, width in
            let type = result.types[idx].lowercased()
            let isNumeric = type.contains("int") || type.contains("float") ||
                           type.contains("double") || type.contains("decimal") ||
                           type.contains("numeric")
            if isNumeric {
                return String(repeating: "-", count: width + 1) + ":"
            } else {
                return String(repeating: "-", count: width + 2)
            }
        }.joined(separator: "|") + "|"
        lines.append(separator)

        // Data rows
        for row in result.rows {
            let dataRow = "| " + row.enumerated().map { idx, cell in
                let value = cell ?? "NULL"
                return value.padding(toLength: widths[idx], withPad: " ", startingAt: 0)
            }.joined(separator: " | ") + " |"
            lines.append(dataRow)
        }

        // Add row count info
        if result.totalRowCount > result.rowCount {
            lines.append("")
            lines.append("_Showing \(result.rowCount) of \(result.totalRowCount) rows_")
        }

        return lines.joined(separator: "\n")
    }

    private func formatMarkdownHeader(_ columns: [String]) -> String {
        let header = "| " + columns.joined(separator: " | ") + " |"
        let separator = "|" + columns.map { _ in "---" }.joined(separator: "|") + "|"
        return header + "\n" + separator
    }

    // MARK: - CSV Format

    private func formatAsCSV(_ result: QueryResultSet) -> String {
        var lines: [String] = []

        // Header row
        lines.append(result.columns.map { escapeCSV($0) }.joined(separator: ","))

        // Data rows
        for row in result.rows {
            let csvRow = row.map { escapeCSV($0 ?? "") }.joined(separator: ",")
            lines.append(csvRow)
        }

        return lines.joined(separator: "\n")
    }

    private func escapeCSV(_ value: String) -> String {
        // If value contains comma, quote, or newline, wrap in quotes
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// MARK: - Convenience Extensions

extension QueryResultSet {
    /// Format result as JSON
    public func asJSON() -> String {
        ResultFormatter().format(self, as: .json)
    }

    /// Format result as Markdown
    public func asMarkdown() -> String {
        ResultFormatter().format(self, as: .markdown)
    }

    /// Format result as CSV
    public func asCSV() -> String {
        ResultFormatter().format(self, as: .csv)
    }
}
