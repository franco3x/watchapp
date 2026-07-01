# WristScan Project Brief

## App Summary

WristScan is a specialized iOS application designed to catalog and track personal watch collections. It leverages optical character recognition (OCR) and an AI-driven enrichment pipeline to instantly identify timepieces and populate their exact horological specifications. Beyond a static catalog, the app acts as a dynamic ledger, tracking wear frequency, timekeeping accuracy, and hardware modifications over time.

## Target Platform & Requirements

* **OS:** iOS 17+ (Required for native SwiftData and `@Bindable` macros).
* **Device Support:** iPhone (Requires native camera access for OCR scanning).
* **Orientation:** Portrait (optimized for lists, charts, and camera scanning).

## Architecture & State Management

* **UI Framework:** Pure SwiftUI.
* **Persistence:** SwiftData using local SQLite storage.
* **State Management:** Lightweight declarative state (`@State`, `@Bindable`, `@Query`) rather than traditional heavyweight MVVM `ObservableObject` classes.
* **Concurrency Pattern:** Strict isolation of the Main UI Thread. All synchronous data conversions (like `UIImage(data:)`), SwiftData relationship fetching, and heavy collection grouping algorithms are forced into background threads using `Task.detached(priority: .userInitiated)` before state updates are routed back via `MainActor.run`.

## Screens & Features

* **WatchDetailView:** The central hub for a specific watch, displaying hero imagery, core specifications, wear frequency charts, service logs, and an accuracy ledger.
* **WatchCatalogItem / Watch Box:** The main grid/list view displaying the user's entire collection.
* **EditWatchView (with EditWatchSheetContainer):** The data entry form for updating watch specifications, housing the photo selection intercept logic.
* **ImageAdjusterView:** A custom cropping engine that allows users to pan and zoom high-resolution photos, utilizing `ImageRenderer` to capture and save a lightweight, screen-resolution crop.
* **RewindView (Epic 2):** A generated analytics report providing insights into collection wear habits over a selected period.
* **WatchScannerView (In Progress):** The camera interface for capturing watch faces and extracting raw dial text via Apple's Vision framework.

## Third-Party Dependencies & External Services

* **Apple Vision Framework (Native):** Used for on-device Optical Character Recognition (OCR) to read dial text without network latency.
* **Apple Charts (Native):** Used for rendering monthly wear frequency metrics.
* **WatchCharts API (Planned):** To be integrated for fetching current market valuations and historical price trends.
* **Multimodal LLM API / Gemini / GPT-4o (Planned):** Will serve as the AI specification engine to translate OCR text or reference numbers into structured JSON specification payloads.

## Data Model

* **WatchTimepiece:** The core entity. Stores strings (manufacturer, modelName, referenceNumber, caseMaterial, watchType, waterResistance), numerics (caseSize, lugToLug, lugWidth, timesWorn), dates (lastWornDate, wearHistory array), and the cropped image as a `Data` BLOB.
* **WatchModification:** A relational entity tracking the component type, modification details, and cost of aftermarket changes.
* **AccuracyLog:** A relational entity tracking the date checked, resting position, and deviation in seconds (+/-).
* **MonthlyWearLog:** A transient, computed struct used strictly for charting grouped wear data.

## Naming & File Conventions

* **View Isolation:** Any complex layout or isolated state (e.g., the `PhotosPicker`) must be extracted into its own strictly typed subview struct (e.g., `IsolatedPhotoPickerView`) to prevent parent state redraws from resetting child component states.
* **Naming:** Standard Swift camelCase for properties and variables, PascalCase for Structs and Classes. Explicit naming for background tasks (e.g., `reloadImage()`, `loadChartData()`).

## Decisions & Tradeoffs

* **Image Storage vs. DB Bloat:** We deliberately chose NOT to store raw, high-resolution user photos directly in SwiftData. Instead, `ImageAdjusterView` flattens the user's pan/zoom adjustments into a compressed, screen-resolution UI render before saving. This prevents SQLite BLOB faulting from choking the app.
* **Hybrid Cache vs. Local Database:** For Epic 5, we deliberately rejected building and maintaining our own massive ETL pipeline of global watch specifications. We are implementing a "Read-Through Cache." The app queries a lightweight cloud database for a reference number; if missing, it falls back to an LLM to generate the specs, presents them to the user for human-in-the-loop verification, and then writes the verified data to our cloud for future users.

## Known Issues & Unfinished Work

* **Epic 3 (Social Sharing):** Pending the creation of a rendering engine to export custom collection metric graphics for social media.
* **Epic 4 (Data Portability):** Pending the construction of a CSV parser to import historical wear data.
* **Epic 5 (AI Enrichment):** The LLM JSON generation, Read-Through Cache cloud setup, and WatchCharts integration have been architected but not yet coded.
* **Current Stabilization:** Still verifying if the `.onChange` cache refreshes and the `IsolatedPhotoPickerView` have fully resolved edge-case UI staleness and picker scroll-jumping.

## Things to NOT Change Without Asking

* **Main Thread Protections:** Do NOT reintroduce synchronous data decoding (e.g., `UIImage(data:)`) into the `body` property of any view.
* **SwiftData Observers:** Do NOT attach `.onChange` modifiers to heavy SwiftData properties like `imageData`. This creates an infinite loop of disk reads. Image refreshes must be handled explicitly via sheet dismissal triggers or `.task` modifiers.
* **Xcode Project Structure:** If generating new files, do not attempt to modify the `project.pbxproj` file programmatically; the developer will link new files into Xcode manually.