import Foundation

// MARK: - Diff Helpers
enum DiffHelpers {

    // MARK: - LCS-based Diff Algorithm
    static func diff(original: String, modified: String) -> [DiffOperation] {
        let origWords = tokenize(original)
        let modWords = tokenize(modified)

        let lcs = longestCommonSubsequence(origWords, modWords)
        return buildDiffFromLCS(original: origWords, modified: modWords, lcs: lcs)
    }

    // MARK: - Similarity Calculation
    static func calculateSimilarity(original: String, modified: String) -> Double {
        if original.isEmpty && modified.isEmpty { return 1.0 }
        if original.isEmpty || modified.isEmpty { return 0.0 }

        let origWords = tokenize(original)
        let modWords = tokenize(modified)

        let lcsLength = longestCommonSubsequenceLength(origWords, modWords)
        let maxLength = max(origWords.count, modWords.count)

        return maxLength > 0 ? Double(lcsLength) / Double(maxLength) : 1.0
    }

    // MARK: - Levenshtein Distance
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    // MARK: - Private Helpers

    private static func tokenize(_ text: String) -> [String] {
        // Split by whitespace and punctuation while preserving separators
        var tokens: [String] = []
        var currentWord = ""

        for char in text {
            if char.isWhitespace || char.isPunctuation {
                if !currentWord.isEmpty {
                    tokens.append(currentWord)
                    currentWord = ""
                }
                tokens.append(String(char))
            } else {
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            tokens.append(currentWord)
        }

        return tokens
    }

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [[Int]] {
        let m = a.count
        let n = b.count
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        return dp
    }

    private static func longestCommonSubsequenceLength(_ a: [String], _ b: [String]) -> Int {
        let dp = longestCommonSubsequence(a, b)
        return dp[a.count][b.count]
    }

    private static func buildDiffFromLCS(original: [String], modified: [String], lcs: [[Int]]) -> [DiffOperation] {
        var result: [DiffOperation] = []
        var i = original.count
        var j = modified.count

        var deletions: [String] = []
        var insertions: [String] = []

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && original[i - 1] == modified[j - 1] {
                // Flush any pending changes
                if !deletions.isEmpty {
                    result.append(.delete(deletions.reversed().joined()))
                    deletions = []
                }
                if !insertions.isEmpty {
                    result.append(.insert(insertions.reversed().joined()))
                    insertions = []
                }
                result.append(.equal(original[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
                insertions.append(modified[j - 1])
                j -= 1
            } else if i > 0 {
                deletions.append(original[i - 1])
                i -= 1
            }
        }

        // Flush remaining changes
        if !deletions.isEmpty {
            result.append(.delete(deletions.reversed().joined()))
        }
        if !insertions.isEmpty {
            result.append(.insert(insertions.reversed().joined()))
        }

        return result.reversed()
    }
}

// MARK: - Character Extension
extension Character {
    var isPunctuation: Bool {
        CharacterSet.punctuationCharacters.contains(self.unicodeScalars.first!)
    }
}
