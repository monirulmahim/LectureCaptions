import Foundation

struct WordFixer {
    private(set) var map: [String: String] = [:]

    init(map: [String: String]) {
        // store lowercase keys
        self.map = Dictionary(uniqueKeysWithValues: map.map { ($0.key.lowercased(), $0.value) })
    }

    static func load(from url: URL) -> WordFixer {
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
            return WordFixer(map: obj ?? [:])
        } catch {
            return WordFixer(map: [:])
        }
    }

    func apply(to text: String) -> String {
        guard !map.isEmpty else { return text }

        var out = ""
        out.reserveCapacity(text.count)

        var current = ""
        current.reserveCapacity(32)

        func flushWord() {
            guard !current.isEmpty else { return }
            let key = current.lowercased()
            if let replacement = map[key] {
                out += matchCase(of: current, replacement: replacement)
            } else {
                out += current
            }
            current.removeAll(keepingCapacity: true)
        }

        for ch in text {
            if ch.isLetter || ch.isNumber || ch == "'" {
                current.append(ch)
            } else {
                flushWord()
                out.append(ch)
            }
        }
        flushWord()

        return out
    }

    private func matchCase(of original: String, replacement: String) -> String {
        // ALL CAPS
        if original == original.uppercased() {
            return replacement.uppercased()
        }
        // Capitalized
        if let first = original.first, first.isUppercase,
           original.dropFirst().allSatisfy({ $0.isLowercase }) {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }
}
