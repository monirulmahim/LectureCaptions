//
//  Item.swift
//  LectureCaptions
//
//  Created by Md. Monirul Islam on 2/25/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
