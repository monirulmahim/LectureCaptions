//
//   TranslationPipe.swift
//  LectureCaptions
//
//  Created by Md. Monirul Islam on 2/26/26.
//

import Foundation
import Combine


@MainActor
final class TranslationPipe: ObservableObject {
    private var continuation: AsyncStream<String>.Continuation?

    lazy var stream: AsyncStream<String> = {
        AsyncStream { cont in
            self.continuation = cont
        }
    }()

    func send(_ text: String) {
        continuation?.yield(text)
    }

    func finish() {
        continuation?.finish()
        continuation = nil
    }
}
