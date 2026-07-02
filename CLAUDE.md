# Working with Me

As you build, explain what you’re doing in plain English — assume I don’t know developer terminology unless I’ve used it myself.

Specifically:

	•	When you create a new file, briefly explain what it’s for and why it needs to exist.
	•	When you’re about to run a terminal command, explain what it does before running it.
	•	When you hit an error or build failure, explain what went wrong in plain English before fixing it.
	•	When you make an architectural or design decision (not just small edits), explain the reasoning.

Keep explanations short and practical — a few sentences, not a lecture. Skip explaining trivial changes like renaming a variable or fixing a typo.

If I ask ‘why’ or ‘what does that mean,’ pause and explain in more depth before continuing.

The goal is for me to learn as we go, not just end up with a working app.


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

* **MainTabView:** Root navigation. Three tabs: Watch Box (collection grid), Insights (analytics dashboard), and Atomic Time (NTP-verified clock dashboard).
* **WatchDetailView:** The central hub for a specific watch, displaying hero imagery, core specifications, wear frequency charts, service logs, and an accuracy ledger.
* **ContentView / Watch Box:** The main grid/list view displaying the user's entire collection.
* **EditWatchView (with EditWatchSheetContainer):** The data entry form for updating watch specifications, housing the photo selection intercept logic.
* **ImageAdjusterView:** A custom cropping engine that allows users to pan and zoom high-resolution photos, utilizing `ImageRenderer` to capture and save a lightweight, screen-resolution crop.
* **AnalyticsDashboardView / RewindView (Epic 2):** `AnalyticsDashboardView` is the Insights tab landing screen; it links to `RewindView`, a generated analytics report providing insights into collection wear habits over a selected period. Report logic lives in `RewindEngine`.
* **Share-as-image (Epic 3):** A shared `ShareCardExporter.swift` component (`ShareCardCoordinator` + `ShareCardPreviewSheet`) lets a screen render a SwiftUI view off-screen into an image, preview it, share it via the system share sheet, or save it to Photos — with permission handling, temp-file cleanup, and success/error feedback all handled once, centrally. Currently wired up on `RewindView` (the full report card), `WatchDetailView` (a single watch's card), and `AnalyticsDashboardView` (the Collection Distribution and Top 5 Wrist Checks charts). The exported cards' visual design is intentionally plain for now; a follow-up redesign pass is tracked below.
* **WatchScannerView:** The camera interface for capturing watch faces. Uses Apple's Vision framework to extract raw dial text on-device, then fuzzy-matches it against the local `WatchCatalogItem` reference database to identify the watch. This is the non-AI matching path; the LLM enrichment fallback described under Epic 5 is not yet built.
* **AtomicClockManager / AtomicClockDashboardView / AccuracyCheckView:** A zero-dependency NTP (network time) client that queries `pool.ntp.org` directly to get true time independent of the device's own clock, so accuracy-ledger entries are checked against a trustworthy reference rather than a potentially-wrong iPhone clock.
* **WristCheckCalendarView / ManualWristCheckView:** A calendar heatmap of a watch's wear history, plus a manual-entry flow for logging (or backfilling) a wrist check for a past date.
* **SettingsView:** Houses data portability controls — currently CSV *export* of the collection (details, purchase history, modifications). CSV *import* is not yet built; see Epic 4 below.
* **CatalogSelectionView / FilterSheetView / CatalogDebugView:** Supporting UI for browsing, filtering, and (in debug builds) inspecting the local `WatchCatalogItem` reference catalog used by the scanner.
* **HydrationManager:** Seeds the local database from a bundled `watch_seed.json` file on first launch.

## Third-Party Dependencies & External Services

* **Apple Vision Framework (Native):** Used for on-device Optical Character Recognition (OCR) to read dial text without network latency.
* **Apple Charts (Native):** Used for rendering monthly wear frequency metrics.
* **WatchCharts API (Planned):** To be integrated for fetching current market valuations and historical price trends.
* **Multimodal LLM API / Gemini / GPT-4o (Planned):** Will serve as the AI specification engine to translate OCR text or reference numbers into structured JSON specification payloads.

## Data Model

* **WatchTimepiece:** The core entity. Stores strings (manufacturer, modelName, referenceNumber, caseMaterial, watchType, waterResistance), numerics (caseSize, lugToLug, lugWidth, timesWorn), dates (lastWornDate, wearHistory array), and the cropped image as a `Data` BLOB.
* **WatchModification:** A relational entity tracking the component type, modification details, and cost of aftermarket changes.
* **AccuracyLog:** A relational entity tracking the date checked, resting position, and deviation in seconds (+/-).
* **WatchCatalogItem:** A separate, pre-loaded reference catalog of known watch models (manufacturer, reference number, aliases like "Pepsi"/"Batman", price tier, etc.), distinct from the user's own collection. This is the lookup target the `WatchScannerView` fuzzy-matches OCR text against.
* **MonthlyWearLog:** A transient, computed struct used strictly for charting grouped wear data.

## Naming & File Conventions

* **View Isolation:** Any complex layout or isolated state (e.g., the `PhotosPicker`) must be extracted into its own strictly typed subview struct (e.g., `IsolatedPhotoPickerView`) to prevent parent state redraws from resetting child component states.
* **Naming:** Standard Swift camelCase for properties and variables, PascalCase for Structs and Classes. Explicit naming for background tasks (e.g., `reloadImage()`, `loadChartData()`).

## Decisions & Tradeoffs

* **Image Storage vs. DB Bloat:** We deliberately chose NOT to store raw, high-resolution user photos directly in SwiftData. Instead, `ImageAdjusterView` flattens the user's pan/zoom adjustments into a compressed, screen-resolution UI render before saving. This prevents SQLite BLOB faulting from choking the app.
* **Hybrid Cache vs. Local Database:** For Epic 5, we deliberately rejected building and maintaining our own massive ETL pipeline of global watch specifications. We are implementing a "Read-Through Cache." The app queries a lightweight cloud database for a reference number; if missing, it falls back to an LLM to generate the specs, presents them to the user for human-in-the-loop verification, and then writes the verified data to our cloud for future users.

## Feature and Task Status

Living project tracker, starting from today forward. Already-shipped functionality is documented once in Screens & Features above and isn't duplicated here — this list is only for things worth actively tracking as they move toward done.

### Done

- [x] CSV export (`SettingsView`) — collection details, purchase history, and modifications
- [x] Scanner: auto-redirect to manual entry after 2 consecutive failed scans
- [x] Insights: removed "Individual Watch" from the Collection Distribution pie chart dropdown
- [x] Insights: fixed overlapping x-axis labels on the Top 5 Wrist Checks bar chart
- [x] Insights: added a time-window filter (Last Month / Last Year / This Year / All Time) to Top 5 Wrist Checks
- [x] Epic 3 — share-as-image mechanism: Save to Photos + system share sheet for the Rewind report, individual watch detail cards, and both Insights charts, via shared `ShareCardExporter.swift`

### In Progress

- [ ] Current Stabilization — verify `.onChange` cache refreshes and `IsolatedPhotoPickerView` have fully resolved edge-case UI staleness and picker scroll-jumping

### Not Started

- [ ] Epic 3 — redesign the visual layout/branding of all four share card images together, for consistency (currently functional but reuses the original plain Rewind card styling)
- [ ] Epic 3 - a more full version of the shared image that is really like Spotify wrapped
- [ ] Epic 4 — CSV import parser for historical wear data
- [ ] Epic 5 — LLM JSON generation engine (OCR text / reference number → structured specs)
- [ ] Epic 5 — cloud read-through cache backend

### Icebox

- [ ] Epic 5 — WatchCharts API integration for market valuations
- [ ] Push notifications reminding the user to check/wear a watch
- [ ] Badge/leveling system
- [ ] Timegrapher functionality
- [ ] Ability to share image directly to social media (Instagram, Facebook, X, etc)

## Things to NOT Change Without Asking

* **Main Thread Protections:** Do NOT reintroduce synchronous data decoding (e.g., `UIImage(data:)`) into the `body` property of any view.
* **SwiftData Observers:** Do NOT attach `.onChange` modifiers to heavy SwiftData properties like `imageData`. This creates an infinite loop of disk reads. Image refreshes must be handled explicitly via sheet dismissal triggers or `.task` modifiers.
* **Xcode Project Structure:** If generating new files, do not attempt to modify the `project.pbxproj` file programmatically; the developer will link new files into Xcode manually.