//
//  WatchTimepiece.swift
//  WristScan
//
//  Purpose: SwiftData @Model representing an individual watch owned by the user, managing its core metadata, wear tracking, photography, and relationship to modifications.
//

import Foundation
import SwiftData

@Model
final class WatchTimepiece {
    var manufacturer: String
    var name: String
    var referenceNumber: String = ""
    var purchaseDate: Date
    var purchasePrice: Double
    var timesWorn: Int
    @Relationship(deleteRule: .cascade, inverse: \WatchModification.timepiece) var modifications: [WatchModification]?
    @Attribute(.externalStorage) var imageData: Data?
    
    var modelName: String = ""
    var movementType: String = ""
    var movement: String = ""
    var notes: String = ""
    
    init(
        manufacturer: String,
        name: String,
        referenceNumber: String,
        purchaseDate: Date,
        purchasePrice: Double,
        imageData: Data? = nil
    ) {
        self.manufacturer = manufacturer
        self.name = name
        self.referenceNumber = referenceNumber
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.timesWorn = 0
        self.modifications = []
        self.imageData = imageData
        self.modelName = ""
        self.movementType = ""
        self.movement = ""
        self.notes = ""
    }
}

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
        dateApplied: Date = Date(),
        cost: Double = 0.0,
        timepiece: WatchTimepiece? = nil
    ) {
        self.componentType = componentType
        self.modificationDetails = modificationDetails
        self.dateApplied = dateApplied
        self.cost = cost
        self.timepiece = timepiece
    }
}
