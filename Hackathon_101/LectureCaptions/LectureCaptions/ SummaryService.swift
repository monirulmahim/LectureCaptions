import Foundation

struct SummaryService {
    static func summariseOffline(transcript: [(date: Date, text: String)], maxBullets: Int = 6) -> SummaryResult {
        let raw = transcript.map { $0.text }.joined(separator: " ")
        let text = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let sentences = splitIntoSentences(text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 25 }

        guard !sentences.isEmpty else {
            return SummaryResult(bullets: ["Not enough content yet."], keywords: [], questions: [])
        }

        let questions = sentences.filter { $0.hasSuffix("?") }.prefix(8).map { $0 }

        var wordFreq: [String: Int] = [:]
        for s in sentences {
            for w in tokenize(s) {
                if w.count < 3 { continue }
                if stopwords.contains(w) { continue }
                wordFreq[w, default: 0] += 1
            }
        }

        let topKeywords = wordFreq.sorted { $0.value > $1.value }.prefix(10).map { $0.key }

        var scored: [(Int, String)] = []
        scored.reserveCapacity(sentences.count)
        for s in sentences {
            var score = 0
            for w in tokenize(s) { score += wordFreq[w, default: 0] }
            if s.count <= 140 { score += 5 }
            scored.append((score, s))
        }

        let bullets = scored
            .sorted { $0.0 > $1.0 }
            .map { $0.1 }
            .uniqued()
            .prefix(maxBullets)
            .map(cleanBullet)

        return SummaryResult(
            bullets: bullets.isEmpty ? ["Not enough content yet."] : bullets,
            keywords: topKeywords,
            questions: Array(questions)
        )
    }

    static func summariseWithOllama(transcript: [(date: Date, text: String)],
                                   model: String = "gemma3:4b") throws -> SummaryResult {
        let joined = transcript.map { $0.text }.joined(separator: " ")
        return try summariseWithOllama(text: joined, model: model)
    }

    static func summariseWithOllama(text: String, model: String = "gemma3:4b") throws -> SummaryResult {
        guard let scriptURL = Bundle.main.url(forResource: "ollama_summary", withExtension: "py") else {
            throw NSError(domain: "SummaryService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing ollama_summary.py in Copy Bundle Resources"
            ])
        }

        // keep size reasonable
        let trimmed = String(text.suffix(20_000))

        let out = try PythonRunner.run(scriptURL: scriptURL, args: [
            "--model", model,
            "--text", trimmed
        ])

        let data = Data(out.utf8)

        // if script returned {"error": "..."}
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? String {
            throw NSError(domain: "SummaryService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Ollama error: \(err)"
            ])
        }

        do {
            let decoded = try JSONDecoder().decode(SummaryResult.self, from: data)
            return SummaryResult(
                bullets: decoded.bullets.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                keywords: decoded.keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                questions: decoded.questions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            )
        } catch {
            throw NSError(domain: "SummaryService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Invalid JSON from Ollama. Output starts: \(out.prefix(300))"
            ])
        }
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        let seps = CharacterSet(charactersIn: ".!?")
        var out: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if String(ch).rangeOfCharacter(from: seps) != nil {
                out.append(current)
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out
    }

    private static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map(String.init)
    }

    private static func cleanBullet(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["so ", "okay ", "now ", "and ", "but "] {
            if t.lowercased().hasPrefix(prefix) { t = String(t.dropFirst(prefix.count)) }
        }
        if !(t.hasSuffix(".") || t.hasSuffix("?") || t.hasSuffix("!")) { t += "." }
        if let first = t.first, first.isLowercase { t = first.uppercased() + t.dropFirst() }
        return t
    }

    private static let stopwords: Set<String> = [
        "the","and","a","an","to","of","in","on","for","with","as","at","by","from","it","is","are","was","were",
        "be","been","being","this","that","these","those","we","you","they","i","he","she","them","our","your",
        "not","or","but","so","if","then","there","here","can","could","should","would","will","just","like",
        "about","into","over","also","because","what","when","where","why","how"
    ]
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for s in self {
            let key = s.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(s)
        }
        return out
    }
}
