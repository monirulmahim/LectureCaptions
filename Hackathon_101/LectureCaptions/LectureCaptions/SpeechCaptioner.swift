import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class SpeechCaptioner: ObservableObject {
    @Published var liveText: String = ""
    @Published var isRunning: Bool = false

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Change if you want default locale. You can expose this later.
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))

    // Transcript for export
    private(set) var transcript: [(date: Date, text: String)] = []
    private var lastSnapshot: Date = .distantPast

    // Prevent stale overwrites (useful if you later add async steps again)
    private var liveVersion = UUID()

    // Word fixes
    private var wordFixer = WordFixer(map: [:])

    func requestPermissions() async -> Bool {
        let micOK = await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                cont.resume(returning: ok)
            }
        }

        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        return micOK && speechOK
    }

    func start() throws {
        guard !isRunning else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Speech recognizer unavailable"
            ])
        }

        stop()

        // Load / ensure word fixes file
        loadWordFixes()

        liveText = ""
        transcript.removeAll()
        lastSnapshot = .distantPast
        liveVersion = UUID()

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = false
        request = req

        let inputNode = audioEngine.inputNode

        // Safe mono float format
        let hwFormat = inputNode.outputFormat(forBus: 0)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hwFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "Audio", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not create audio format"
            ])
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    // PARTIAL: keep it fast (no heavy punctuation)
                    let partialFull = result.bestTranscription.formattedString
                    let partialTail = Self.tailCaption(partialFull)
                    let partialClean = Self.postProcess(partialTail)
                    let partialFixed = self.wordFixer.apply(to: partialClean)
                    _ = self.setLive(partialFixed)

                    // Snapshot every ~2 seconds (keeps export useful without exploding)
                    let now = Date()
                    if now.timeIntervalSince(self.lastSnapshot) > 2.0 {
                        self.transcript.append((date: now, text: partialFixed))
                        self.lastSnapshot = now
                    }

                    // FINAL: apply punctuation + fixes, store clean final line
                    if result.isFinal {
                        let finalFull = Self.punctuate(result.bestTranscription)
                        let finalClean = Self.postProcess(finalFull)
                        let finalFixed = self.wordFixer.apply(to: finalClean)
                        self.transcript.append((date: Date(), text: finalFixed))
                        _ = self.setLive(Self.tailCaption(finalFixed))
                    }
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.stop()
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil

        request?.endAudio()
        request = nil

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        if audioEngine.isRunning { audioEngine.stop() }

        isRunning = false
        liveText = ""
        liveVersion = UUID()
    }


    private func setLive(_ text: String) -> UUID {
        liveVersion = UUID()
        liveText = text
        return liveVersion
    }


    private static func tailCaption(_ full: String) -> String {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 140 else { return trimmed }
        return "…" + String(trimmed.suffix(140))
    }


    private static func postProcess(_ s: String) -> String {
        var t = s

        t = t.replacingOccurrences(of: "\n", with: " ")
        t = t.replacingOccurrences(of: "\t", with: " ")
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }

        // Fix spacing before punctuation
        t = t.replacingOccurrences(of: " ,", with: ",")
        t = t.replacingOccurrences(of: " .", with: ".")
        t = t.replacingOccurrences(of: " !", with: "!")
        t = t.replacingOccurrences(of: " ?", with: "?")
        t = t.replacingOccurrences(of: " :", with: ":")
        t = t.replacingOccurrences(of: " ;", with: ";")

        // Quick contractions (optional)
        var padded = " \(t) "
        let replacements: [(String, String)] = [
            (" dont ", " don't "),
            (" cant ", " can't "),
            (" wont ", " won't "),
            (" im ", " I'm "),
            (" ive ", " I've "),
            (" i ", " I "),
            (" i'", " I'")
        ]
        for (a, b) in replacements {
            padded = padded.replacingOccurrences(of: a, with: b)
        }
        t = padded.trimmingCharacters(in: .whitespacesAndNewlines)

        return t
    }


    private static func punctuate(_ t: SFTranscription) -> String {
        let segs = t.segments
        guard !segs.isEmpty else { return t.formattedString }

        // Tune these for lectures
        let commaGap: TimeInterval = 0.35
        let periodGap: TimeInterval = 0.85

        var out: [String] = []
        out.reserveCapacity(segs.count * 2)

        for i in 0..<segs.count {
            let s = segs[i]
            let word = s.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            if word.isEmpty { continue }

            out.append(word)

            if i < segs.count - 1 {
                let curEnd = s.timestamp + s.duration
                let nextStart = segs[i + 1].timestamp
                let gap = nextStart - curEnd

                if gap >= periodGap {
                    if let last = out.last,
                       !last.hasSuffix(".") && !last.hasSuffix("?") && !last.hasSuffix("!") {
                        out[out.count - 1] = last + "."
                    }
                } else if gap >= commaGap {
                    if let last = out.last,
                       !last.hasSuffix(",") && !last.hasSuffix(".") && !last.hasSuffix("?") && !last.hasSuffix("!") {
                        out[out.count - 1] = last + ","
                    }
                }
            }
        }

        var text = out.joined(separator: " ")
        text = text.replacingOccurrences(of: " ,", with: ",")
        text = text.replacingOccurrences(of: " .", with: ".")
        text = text.replacingOccurrences(of: " !", with: "!")
        text = text.replacingOccurrences(of: " ?", with: "?")

        text = applyQuestionHeuristic(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func applyQuestionHeuristic(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        // If it already ends with ?, keep it
        if trimmed.hasSuffix("?") { return trimmed }

        let lower = trimmed.lowercased()
        let starters = [
            "who","what","when","where","why","how",
            "is","are","am","was","were",
            "do","does","did",
            "can","could","should","would","will",
            "have","has","had"
        ]

        if trimmed.hasSuffix(".") {
            for s in starters where lower.hasPrefix(s + " ") {
                return String(trimmed.dropLast()) + "?"
            }
        }

        // tag questions
        if trimmed.hasSuffix("."),
           lower.hasSuffix(" right.") || lower.hasSuffix(" okay.") || lower.hasSuffix(" ok.") {
            return String(trimmed.dropLast()) + "?"
        }

        return trimmed
    }


    private func loadWordFixes() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // fallback bundle only
            loadWordFixesFromBundle()
            return
        }

        let folder = appSupport.appendingPathComponent("LectureCaptions", isDirectory: true)
        let url = folder.appendingPathComponent("WordFixes.json")

        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)

            // If file doesn't exist, copy starter from bundle
            if !fm.fileExists(atPath: url.path) {
                if let starter = Bundle.main.url(forResource: "WordFixes", withExtension: "json") {
                    try fm.copyItem(at: starter, to: url)
                }
            }

            wordFixer = WordFixer.load(from: url)
        } catch {
            // fallback to bundle
            loadWordFixesFromBundle()
        }
    }

    private func loadWordFixesFromBundle() {
        if let url = Bundle.main.url(forResource: "WordFixes", withExtension: "json") {
            wordFixer = WordFixer.load(from: url)
        } else {
            wordFixer = WordFixer(map: [:])
        }
    }


    func reloadWordFixes() {
        loadWordFixes()
    }
}
