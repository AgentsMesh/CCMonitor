# CCMonitor

A native macOS menu bar app for real-time monitoring of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) token usage and costs.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.10-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

## Features

- **Real-time Monitoring** — Watches `~/.claude/projects/**/*.jsonl` via FSEvents, processes new entries within seconds
- **Accurate Pricing** — Fetches model pricing from LiteLLM database with 3-tier cache (remote → local → embedded fallback)
- **Incremental Processing** — Tracks byte offsets per file; restarts pick up exactly where they left off
- **Rich Dashboard** — Swift Charts with bar/line toggle, time range selection (minutes/hours/days), click-to-inspect data points
- **Menu Bar at a Glance** — Configurable display: cost only, cost + tokens, or icon only
- **Multi-dimensional Aggregation** — By time (minute/hour/day), by project, by model, by session
- **Burn Rate & Forecast** — Real-time $/hr rate with daily and monthly cost projections
- **Budget Alerts** — Configurable daily/monthly budgets with visual progress indicators
- **Instant Startup** — Aggregation snapshots restore cached data in under a second

## Requirements

- macOS 14.0 (Sonoma) or later
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and used (generates the JSONL logs this app monitors)

## Installation

### Download Release

Download the latest `CCMonitor.app.zip` from [Releases](https://github.com/AgentsMesh/CCMonitor/releases), unzip, and move to `/Applications/`.

### Build from Source

```bash
git clone https://github.com/AgentsMesh/CCMonitor.git
cd CCMonitor

# Build release .app bundle
./scripts/build-app.sh release

# Run directly
open build/CCMonitor.app

# Or install to /Applications
cp -R build/CCMonitor.app /Applications/
```

> **Note:** `SMAppService` requires the app to be in `/Applications` for Launch at Login to work.

## Architecture

```
FSEvents (directory watch, 0.5s latency)
    │
    ▼
IncrementalFileReader (byte offset tracking, persistent state)
    │ [String] new lines
    ▼
JSONLParser (filter type=assistant + message.usage, dedup by hash)
    │ [UsageEntry]
    ▼
CostCalculator + PricingService (token × price, 200K tiered pricing)
    │ UsageEntry + cost
    ▼
UsageAggregator (@Observable, incremental multi-dimension aggregation)
    │ automatic SwiftUI refresh
    ▼
Dashboard UI (Swift Charts + SwiftUI)
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Swift Package Manager (not Xcode project) | Reproducible builds, no `.xcodeproj` noise |
| `@Observable` (Observation framework) | Modern SwiftUI state management, fine-grained updates |
| FSEvents API | Native macOS file watching, recursive directory support |
| Actor-based `IncrementalFileReader` | Thread-safe byte offset tracking across concurrent file access |
| 3-tier pricing cache | Accurate online pricing with offline resilience |
| Aggregation snapshots | Sub-second startup after first run |

## Project Structure

```
Sources/CCMonitor/
├── App/                    # Entry point, AppState pipeline, Launch at Login
├── Models/                 # UsageEntry, ModelPricing, AggregatedUsage, SessionInfo, ProjectInfo
├── Services/
│   ├── Watcher/            # FSEventsWatcher, IncrementalFileReader
│   ├── Parser/             # JSONLParser
│   ├── Pricing/            # PricingService (LiteLLM), CostCalculator (tiered pricing)
│   ├── Aggregation/        # UsageAggregator, BurnRateCalculator, AggregationCache
│   └── Persistence/        # SwiftData UsageStore
├── ViewModels/             # MenuBarViewModel, DashboardViewModel, SettingsViewModel
├── Views/
│   ├── MenuBar/            # Menu bar popover
│   ├── Dashboard/Panels/   # Summary cards, time series, model distribution, projects, budget
│   ├── Settings/           # General + Budget tabs
│   └── Components/         # Reusable UI components
├── Utilities/              # Constants, Formatters, PathDiscovery, WindowManager
└── Resources/              # Embedded pricing fallback
```

## Development

```bash
# Build debug
swift build

# Run tests
swift test

# Build release .app
./scripts/build-app.sh release
```

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [swift-log](https://github.com/apple/swift-log) | ≥ 1.5.0 | Structured logging |

All other frameworks (SwiftUI, SwiftData, Charts, AppKit, ServiceManagement) are system-provided.

## License

MIT
