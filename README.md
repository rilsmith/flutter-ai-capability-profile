# AI Capability Dashboard (Flutter)

An editable, hostable dashboard for visualizing AI-driven engineering capability across nine dimensions. Flutter web port of the React dashboard in `js-capability-dashboard`.

## Features

- Polished consulting-style radar chart and summary cards
- **In-browser editing** — update titles, scores, descriptors, and colors live
- Drag or click along chart axes to adjust dimension scores
- Auto-saved to browser localStorage
- Export / import JSON for sharing assessments (compatible with the JS dashboard)
- Static web build deployable to any host

## Quick start

```bash
flutter pub get
flutter run -d chrome
```

Open the URL shown in the terminal (typically `http://localhost:<port>`).

## Build for production

```bash
flutter build web
```

The `build/web/` folder contains static files ready to deploy.

## Editing the dashboard

1. Click **Edit Dashboard** in the top-right corner.
2. Use the side panel to change header text, dimension names, scores (slider or number), descriptors, and accent colors.
3. Drag radar chart points or click along an axis to adjust scores at any time.
4. Changes apply immediately and persist in your browser.
5. Use **Export JSON** to save a snapshot, or **Import JSON** to load one.
6. **Reset to Defaults** restores the original sample data.

## Project structure

```
lib/
├── models/         Data types (Dimension, DashboardData, etc.)
├── data/           Default dashboard content
├── providers/      State + localStorage persistence
├── utils/          Score calculations and chart helpers
├── theme/          Dashboard styling
└── widgets/        Dashboard UI (chart, cards, edit panel)
```

## Tech stack

- Flutter (web)
- provider (state management)
- shared_preferences (localStorage persistence)
- file_picker (JSON import)

## JSON compatibility

Exports use the same JSON schema as the JS dashboard (`ai-capability-dashboard-data` storage key and `capability-profile.json` export filename). Profiles can be shared between the React and Flutter versions.
