import AppKit
import SwiftUI
import QuartzCore

final class SummaryWindowController {
    private var window: NSWindow?

    func show(result: SummaryResult) {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let content = SummaryView(result: result) { [weak self] in
            self?.hide()
        }

        let hosting = NSHostingView(rootView: content)

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)

        let width: CGFloat = 420
        let height: CGFloat = 540

        let target = NSRect(
            x: screen.minX + 30,
            y: screen.midY - height/2,
            width: width,
            height: height
        )

        let start = NSRect(
            x: screen.minX - width - 20,
            y: target.origin.y,
            width: width,
            height: height
        )

        let w = NSWindow(contentRect: start, styleMask: [.borderless], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.hasShadow = true
        w.contentView = hosting
        w.isMovableByWindowBackground = true

        w.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            w.animator().setFrame(target, display: true)
        }

        window = w
    }

    func hide() {
        guard let w = window else { return }
        let screen = NSScreen.main?.visibleFrame ?? w.frame
        let end = NSRect(
            x: screen.minX - w.frame.width - 20,
            y: w.frame.origin.y,
            width: w.frame.width,
            height: w.frame.height
        )

        NSAnimationContext.runAnimationGroup({
            $0.duration = 0.2
            w.animator().setFrame(end, display: true)
        }, completionHandler: {
            w.orderOut(nil)
        })

        window = nil
    }
}
