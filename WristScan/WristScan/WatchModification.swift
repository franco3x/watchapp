//
//  WatchModification.swift
//  WristScan
//
//  Created by Frank Coleman on 6/18/26.
//

import Foundation
import SwiftData

@Model
final class WatchModification {
    var componentType: String
    var modificationDetails: String
    var dateApplied: Date
    var cost: Double
    
    var timepiece: WatchTimepiece?
    
    init(
        componentType: String,
        modificationDetails: String,
        dateApplied: Date,
        cost: Double,
        timepiece: WatchTimepiece? = nil
    ) {
        self.componentType = componentType
        self.modificationDetails = modificationDetails
        self.dateApplied = dateApplied
        self.cost = cost
        self.timepiece = timepiece
    }
}
