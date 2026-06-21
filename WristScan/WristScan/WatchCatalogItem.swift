//
//  WatchCatalogItem.swift
//  WristScan
//
//  Purpose: SwiftData @Model representing the local reference catalog/database of pre-loaded watch models used for OCR comparison.
//

import Foundation
import SwiftData

/// A catalog entry describing a known watch reference.
/// Serves as the lookup target for fuzzy matching against scanned OCR results.
@Model
final class WatchCatalogItem {

    // MARK: - Identity

    var id: UUID
    /// Unique reference number — the primary key for fuzzy lookups.
    @Attribute(.unique) var referenceNumber: String

    // MARK: - Description

    var manufacturer: String
    var modelName: String
    /// Alternate colloquial names (e.g. "Pepsi", "Batman", "Hulk").
    /// Stored as a flat array; SwiftData persists this via a Transformable column.
    var aliases: [String]

    // MARK: - Classification

    /// Broad style category, e.g. "Diver", "Pilot", "Dress", "Sport".
    var watchType: String
    var dialColor: String
    /// Price tier bucket: "Budget", "Mid-Range", "Luxury", "Ultra-Luxury".
    var priceTier: String
    var movementType: String
    var movement: String

    // Dial & Visuals
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

    // MARK: - Init

    init(
        id: UUID = UUID(),
        manufacturer: String,
        modelName: String,
        referenceNumber: String,
        aliases: [String] = [],
        watchType: String,
        dialColor: String,
        priceTier: String,
        movementType: String,
        movement: String,
        lumeType: String = "",
        caseMaterial: String = "",
        crystalType: String = "",
        waterResistance: String = "",
        strapMaterial: String = "",
        complications: String = "",
        caseSize: Double = 0.0,
        lugToLug: Double = 0.0,
        lugWidth: Double = 0.0
    ) {
        self.id              = id
        self.manufacturer    = manufacturer
        self.modelName       = modelName
        self.referenceNumber = referenceNumber
        self.aliases         = aliases
        self.watchType       = watchType
        self.dialColor       = dialColor
        self.priceTier       = priceTier
        self.movementType    = movementType
        self.movement        = movement
        
        self.lumeType        = lumeType
        self.caseMaterial    = caseMaterial
        self.crystalType     = crystalType
        self.waterResistance = waterResistance
        self.strapMaterial   = strapMaterial
        self.complications   = complications
        self.caseSize        = caseSize
        self.lugToLug        = lugToLug
        self.lugWidth        = lugWidth
    }
}
