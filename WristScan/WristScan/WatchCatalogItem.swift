//
//  WatchCatalogItem.swift
//  WristScan
//
//  Created by Frank Coleman on 6/17/26.
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
    var primaryStyle: String
    var dialColor: String
    /// Price tier bucket: "Budget", "Mid-Range", "Luxury", "Ultra-Luxury".
    var priceTier: String

    // MARK: - Init

    init(
        id: UUID = UUID(),
        manufacturer: String,
        modelName: String,
        referenceNumber: String,
        aliases: [String] = [],
        primaryStyle: String,
        dialColor: String,
        priceTier: String
    ) {
        self.id              = id
        self.manufacturer    = manufacturer
        self.modelName       = modelName
        self.referenceNumber = referenceNumber
        self.aliases         = aliases
        self.primaryStyle    = primaryStyle
        self.dialColor       = dialColor
        self.priceTier       = priceTier
    }
}
