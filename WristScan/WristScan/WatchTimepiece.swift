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
    @Relationship(deleteRule: .cascade, inverse: \AccuracyLog.timepiece) var accuracyLogs: [AccuracyLog]?
    @Attribute(.externalStorage) var imageData: Data?
    
    var modelName: String = ""
    var movementType: String = ""
    var movement: String = ""
    var notes: String = ""
    var watchType: String = ""
    
    // Dial & Visuals
    var dialColor: String = ""
    var lumeType: String = ""

    // Case & Material Specs
    var caseMaterial: String = ""
    var crystalType: String = ""
    var waterResistance: String = ""
    var strapMaterial: String = ""
    var complications: String = "" // e.g., "Date, Chronograph"

    // Dimensions (Using Double for future numeric filtering/sorting)
    var caseSize: Double = 0.0     // in mm
    var lugToLug: Double = 0.0     // in mm
    var lugWidth: Double = 0.0     // in mm
    
    var lastWornDate: Date? = nil
    var wearHistory: [Date] = []
    
    init(
        manufacturer: String,
        name: String,
        referenceNumber: String,
        purchaseDate: Date,
        purchasePrice: Double,
        imageData: Data? = nil,
        dialColor: String = "",
        lumeType: String = "",
        caseMaterial: String = "",
        crystalType: String = "",
        waterResistance: String = "",
        strapMaterial: String = "",
        complications: String = "",
        caseSize: Double = 0.0,
        lugToLug: Double = 0.0,
        lugWidth: Double = 0.0,
        lastWornDate: Date? = nil,
        wearHistory: [Date] = [],
        accuracyLogs: [AccuracyLog] = []
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
        self.watchType = ""
        
        self.dialColor = dialColor
        self.lumeType = lumeType
        self.caseMaterial = caseMaterial
        self.crystalType = crystalType
        self.waterResistance = waterResistance
        self.strapMaterial = strapMaterial
        self.complications = complications
        self.caseSize = caseSize
        self.lugToLug = lugToLug
        self.lugWidth = lugWidth
        self.lastWornDate = lastWornDate
        self.wearHistory = wearHistory
        self.accuracyLogs = accuracyLogs
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

@Model
final class AccuracyLog {
    /// The exact date and time the accuracy check was performed.
    var dateChecked: Date
    /// Deviation from true time in seconds; positive = running fast, negative = running slow.
    var deviationInSeconds: Double
    /// Watch position during the check, e.g. 'Dial Up', 'Crown Down', 'On Wrist'.
    var position: String
    /// Free-form notes for the check (temperature, power reserve, etc.).
    var notes: String
    var timepiece: WatchTimepiece?
    
    init(
        dateChecked: Date = Date(),
        deviationInSeconds: Double = 0.0,
        position: String = "",
        notes: String = "",
        timepiece: WatchTimepiece? = nil
    ) {
        self.dateChecked = dateChecked
        self.deviationInSeconds = deviationInSeconds
        self.position = position
        self.notes = notes
        self.timepiece = timepiece
    }
}
