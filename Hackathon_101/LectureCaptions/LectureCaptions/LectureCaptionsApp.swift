//
//  LectureCaptionsApp.swift
//  LectureCaptions
//
//  Created by Md. Monirul Islam on 2/25/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

@main
struct LectureCaptionsApp: App {

    @StateObject private var captioner: SpeechCaptioner
    @StateObject private var settings: AppSettings
    private let summaryWindow = SummaryWindowController()
    @State private var lastSummary: SummaryResult? = nil

    private let windowController: CaptionWindowController
    @State private var clickThrough = false

    init() {
        let c = SpeechCaptioner()
        let s = AppSettings()

        _captioner = StateObject(wrappedValue: c)
        _settings  = StateObject(wrappedValue: s)

        windowController = CaptionWindowController(captioner: c, settings: s)
    }

    var body: some Scene {
        MenuBarExtra("LectureCaptions", systemImage: "captions.bubble") {

            Button("Start Captions") {
                Task { @MainActor in
                    let ok = await captioner.requestPermissions()
                    guard ok else {
                        print("Permission denied (Microphone or Speech).")
                        return
                    }

                    windowController.show()
                    windowController.setClickThrough(clickThrough)

                    do { try captioner.start() }
                    catch { print("Start error:", error.localizedDescription) }
                }
            }

            Button("Stop") {
                captioner.stop()
                windowController.hide()
            }

            Divider()

            Toggle("Chinese captions (中文)", isOn: $settings.chineseEnabled)

            Toggle("Click-through overlay", isOn: $clickThrough)
                .onChange(of: clickThrough) { _, newValue in
                    windowController.setClickThrough(newValue)
                }

            Divider()

            Button("Export Transcript (.txt)") {
                exportTranscriptTxt()
            }
            
            Button("Summarise so far (AI)") {
                Task.detached { [summaryWindow] in
                    let transcript = await MainActor.run { captioner.transcript }

                    do {
                        let result = try SummaryService.summariseWithOllama(transcript: transcript, model: "gemma3:4b")
                        await MainActor.run {
                            summaryWindow.show(result: result)
                            lastSummary = result
                        }
                    } catch {
                        let fallback = SummaryService.summariseOffline(transcript: transcript)
                        await MainActor.run {
                            summaryWindow.show(result: fallback)
                            lastSummary = fallback
                        }
                    }
                }
            }
//            Button("Export PDF (Summary + Transcript)") {
//                exportPDF()
//            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func exportPDF() {
        guard !captioner.transcript.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "LectureNotes.pdf"

        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }

//            let summary = SummaryService.summarise(transcript: captioner.transcript)
//            let pdf = PDFExporter.makePDF(summary: summary, transcript: captioner.transcript, title: "Lecture Notes")

//            if pdf.write(to: url) {
//                NSWorkspace.shared.activateFileViewerSelecting([url])
//            }
        }
    }

    private func exportTranscriptTxt() {
        guard !captioner.transcript.isEmpty else {
            print("Transcript is empty.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = "lecture.txt"

        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }

            let text = captioner.transcript
                .map { "\(isoTime($0.date))\t\($0.text)" }
                .joined(separator: "\n")

            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(url.deletingLastPathComponent())
            } catch {
                print("Write txt failed:", error.localizedDescription)
            }
        }
    }

    private func isoTime(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
