//
//  CaptionWindowController.swift
//  LectureCaptions
//
//  Created by Md. Monirul Islam on 2/25/26.
//

import AppKit
import SwiftUI

final class CaptionWindowController {
    private var window: NSWindow?

    private let captioner: SpeechCaptioner
    private let settings: AppSettings

    init(captioner: SpeechCaptioner, settings: AppSettings) {
        self.captioner = captioner
        self.settings = settings
    }

    func show() {
        if window != nil { return }

        let content = CaptionOverlayView(captioner: captioner)
            .environmentObject(settings)

        let hosting = NSHostingView(rootView: content)

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)

        let height: CGFloat = 72
        let width: CGFloat = min(980, screen.width - 40)

        // Bottom center
        let xPos = screen.midX - (width / 2)
        let yPos = screen.minY + 40

        let frame = NSRect(x: xPos, y: yPos, width: width, height: height)

        let w = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.hasShadow = true
        w.ignoresMouseEvents = false

        // Don’t steal focus
        w.orderFrontRegardless()

        w.contentView = hosting
        self.window = w
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }

    func setClickThrough(_ on: Bool) {
        window?.ignoresMouseEvents = on
    }
}
