//
//  HydrationManager.swift
//  WristScan
//
//  Purpose: The static data utility responsible for parsing watch_seed.json on initial launch to populate the local SQL-backed catalog.
//

import Foundation
import SwiftData

// MARK: - DTO

/// Lightweight Decodable mirror of WatchCatalogItem used only for JSON decoding.
/// Keys must exactly match the property names in watch_seed.json.
private struct WatchCatalogItemDTO: Decodable {
    let manufacturer:    String
    let modelName:       String
    let referenceNumber: String
    let aliases:         [String]
    let watchType:       String
    let dialColor:       String
    let priceTier:       String
    let movementType:    String
    let movement:        String
}

// MARK: - HydrationManager

enum HydrationManager {

    /// Seeds the local watch catalog from `watch_seed.json` on first launch.
    /// Safe to call on every launch — exits immediately if records already exist.
    @MainActor
    static func seedDatabaseIfNeeded(context: ModelContext) async throws {

        // 1. Guard: skip if catalog is already populated.
        let descriptor = FetchDescriptor<WatchCatalogItem>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else {
            print("[HydrationManager] Catalog already seeded (\(count) items). Skipping.")
            return
        }

        // 2. Locate the seed file in the main bundle.
        guard let url = Bundle.main.url(forResource: "watch_seed", withExtension: "json") else {
            throw HydrationError.seedFileNotFound
        }

        // 3. Decode the JSON array into DTOs.
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([WatchCatalogItemDTO].self, from: data)

        // 4. Map DTOs → model instances and insert into the context.
        for dto in dtos {
            let item = WatchCatalogItem(
                manufacturer:    dto.manufacturer,
                modelName:       dto.modelName,
                referenceNumber: dto.referenceNumber,
                aliases:         dto.aliases,
                watchType:       dto.watchType,
                dialColor:       dto.dialColor,
                priceTier:       dto.priceTier,
                movementType:    dto.movementType,
                movement:        dto.movement
            )
            context.insert(item)
        }

        // 5. Persist — throws on failure, caught by the .task{} in WristScanApp.
        try context.save()
        print("[HydrationManager] ✅ Seeded \(dtos.count) catalog item(s).")
    }

    // MARK: - Errors

    enum HydrationError: LocalizedError {
        case seedFileNotFound

        var errorDescription: String? {
            switch self {
            case .seedFileNotFound:
                return "watch_seed.json was not found in the main bundle."
            }
        }
    }
}
