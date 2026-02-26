//
//  CaptionOverlayView.swift
//  LectureCaptions
//
//  Created by Md. Monirul Islam on 2/25/26.
//

import SwiftUI
import Translation

struct CaptionOverlayView: View {
    @ObservedObject var captioner: SpeechCaptioner
    @EnvironmentObject var settings: AppSettings

    @StateObject private var pipe = TranslationPipe()

    @State private var chineseText: String = ""
    @State private var debounceTask: Task<Void, Never>?
    private var zhConfig: TranslationSession.Configuration? {
        settings.chineseEnabled
        ? .init(source: .init(identifier: "en"),
                target: .init(identifier: "zh-Hans"))
        : nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 10, height: 10)
                        .opacity(captioner.isRunning ? 1 : 0)

                    Text(displayEnglish)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if settings.chineseEnabled {
                    Divider().opacity(0.25)

                    Text(chineseText.isEmpty ? "正在翻译…" : chineseText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(height: settings.chineseEnabled ? 104 : 72)
        .animation(.easeInOut(duration: 0.18), value: settings.chineseEnabled)

        .onChange(of: captioner.liveText) { _, _ in
            scheduleSendToTranslator()
        }
        .onChange(of: settings.chineseEnabled) { _, enabled in
            debounceTask?.cancel()
            chineseText = ""
            if enabled { scheduleSendToTranslator() }
        }
        .onChange(of: captioner.isRunning) { _, running in
            if !running {
                debounceTask?.cancel()
                chineseText = ""
            } else {
                scheduleSendToTranslator()
            }
        }
        
        // Translation runs here (Apple requires this pattern)
        .translationTask(zhConfig) { session in
            for await text in pipe.stream {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                do {
                    let response = try await session.translate(trimmed)
                    await MainActor.run {
                        // Only apply if still enabled
                        if settings.chineseEnabled {
                            chineseText = response.targetText
                        }
                    }
                } catch {
                    await MainActor.run { chineseText = "" }
                }
            }
        }
        .onDisappear {
            pipe.finish()
        }
    }

    private var displayEnglish: String {
        captioner.liveText.isEmpty ? "Listening…" : captioner.liveText
    }

    private func scheduleSendToTranslator() {
        guard settings.chineseEnabled else { return }

        let text = captioner.liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "Listening…" else {
            chineseText = ""
            return
        }

        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            // Debounce to avoid translating every tiny partial update
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }

            let latest = captioner.liveText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !latest.isEmpty, settings.chineseEnabled else { return }
            pipe.send(latest)
        }
    }
}
