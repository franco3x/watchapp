//
//  WatchTimepiece.swift
//  WristScan
//
//  Created by Frank Coleman on 6/17/26.
//

import Foundation
import SwiftData

@Model
final class WatchTimepiece {
    var manufacturer: String
    var name: String
    var referenceNumber: String
    var purchaseDate: Date
    var purchasePrice: Double
    var timesWorn: Int
    
    init(
        manufacturer: String,
        name: String,
        referenceNumber: String,
        purchaseDate: Date,
        purchasePrice: Double
    ) {
        self.manufacturer = manufacturer
        self.name = name
        self.referenceNumber = referenceNumber
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.timesWorn = 0
    }
}
