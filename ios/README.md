# TravelItinerary iOS

This iOS app is a native `WKWebView` shell around the existing static travel app.

## Data Flow

1. Update trip data in Notion.
2. Run `npm run sync -- <tripId>` to export Notion data into `data/*.json`.
3. Commit and push the JSON changes so GitHub Pages serves the latest API data.
4. On the iOS app, tap `更新資料` to manually download the latest JSON files.
5. The app stores the last successful download in iOS Application Support and keeps using it offline.

## Local Web Assets

The app bundles a copy of `index.html`, `css`, `js`, and `data` under `ios/TravelItinerary/WebApp`.

After changing the web UI or local fallback data, run:

```sh
npm run sync:ios
```

## API Source

The remote JSON source is configured in `ios/TravelItinerary/Info.plist`:

```xml
<key>APIBaseURL</key>
<string>https://shunch9586.github.io/TripALLaroundtheWORLD/</string>
```

The updater first downloads `data/config.json`, then downloads each trip's `itinerary.json`, `info.json`, and `trip.json`.
