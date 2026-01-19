import Foundation

/// Parses markdown documentation into structured sections
public struct MarkdownParser {

    public init() {}

    /// Parse markdown content into sections
    public func parse(_ content: String) -> [Section] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [Section] = []
        var currentSection: (title: String, level: Int, id: String, startLine: Int, contentLines: [String])?
        var parentStack: [(id: String, level: Int)] = []

        for (lineIndex, line) in lines.enumerated() {
            // Check for heading
            if let heading = parseHeading(line) {
                // Save current section if exists
                if let current = currentSection {
                    let section = createSection(
                        from: current,
                        endLine: lineIndex - 1,
                        parentStack: parentStack
                    )
                    sections.append(section)
                }

                // Update parent stack
                while let last = parentStack.last, last.level >= heading.level {
                    parentStack.removeLast()
                }

                // Start new section
                currentSection = (
                    title: heading.title,
                    level: heading.level,
                    id: heading.id ?? generateId(from: heading.title),
                    startLine: lineIndex,
                    contentLines: []
                )

                parentStack.append((id: currentSection!.id, level: heading.level))
            } else if var current = currentSection {
                // Add line to current section content
                current.contentLines.append(line)
                currentSection = current
            }
        }

        // Don't forget the last section
        if let current = currentSection {
            let section = createSection(
                from: current,
                endLine: lines.count - 1,
                parentStack: parentStack
            )
            sections.append(section)
        }

        return sections
    }

    // MARK: - Private Helpers

    /// Parse a heading line
    /// Supports: # Title, ## Title, ### Title, and {#anchor-id}
    private func parseHeading(_ line: String) -> (title: String, level: Int, id: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Count leading hashes
        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        guard level > 0 && level <= 6 else { return nil }

        // Extract title (after hashes and space)
        let afterHashes = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)

        // Check for anchor ID: {#anchor-id}
        var title = afterHashes
        var anchorId: String? = nil

        if let anchorMatch = afterHashes.range(of: #"\{#([^}]+)\}"#, options: .regularExpression) {
            let fullMatch = String(afterHashes[anchorMatch])
            // Extract ID from {#xxx}
            let idStart = fullMatch.index(fullMatch.startIndex, offsetBy: 2)
            let idEnd = fullMatch.index(fullMatch.endIndex, offsetBy: -1)
            anchorId = String(fullMatch[idStart..<idEnd])

            // Remove anchor from title
            title = afterHashes.replacingCharacters(in: anchorMatch, with: "").trimmingCharacters(in: .whitespaces)
        }

        guard !title.isEmpty else { return nil }

        return (title: title, level: level, id: anchorId)
    }

    /// Generate a URL-safe ID from title
    private func generateId(from title: String) -> String {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")

        // Keep only alphanumeric and hyphens
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let filtered = normalized.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }

    /// Create a Section from parsed data
    private func createSection(
        from data: (title: String, level: Int, id: String, startLine: Int, contentLines: [String]),
        endLine: Int,
        parentStack: [(id: String, level: Int)]
    ) -> Section {
        // Find parent (last item in stack with lower level)
        let parentId: String? = {
            for item in parentStack.reversed() {
                if item.level < data.level {
                    return item.id
                }
            }
            return nil
        }()

        let content = data.contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return Section(
            id: data.id,
            title: data.title,
            level: data.level,
            content: content,
            startLine: data.startLine,
            endLine: endLine,
            parentId: parentId,
            children: []
        )
    }
}
