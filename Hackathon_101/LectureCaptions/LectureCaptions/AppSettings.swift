//
//  AppSettings.swift
//  LectureCaptions
//
//  Created by Md. Monirul Islam on 2/26/26.
//

import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var chineseEnabled: Bool = false
}
