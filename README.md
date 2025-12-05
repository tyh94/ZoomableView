# ZoomableView

SwiftUI modifier that adds smooth pinch‑to‑zoom, panning, and double‑tap zoom with sensible clamping and optional haptics (iOS 17+). Includes a lightweight logging hook and programmatic centering support.

## Demo
<img src="Example.gif" alt="ZoomableView demo" width="360" />

## Requirements
- iOS 16.0+ / macOS 11.0+
- Swift 5.9+

## Installation (Swift Package Manager)
1. In Xcode: *File* → *Add Package Dependencies…*
2. Enter the repo URL for this package.
3. Add the `ZoomableView` library to your target.

## Quick Start
Wrap your content in a `GeometryReader` to supply the container size, then apply `.zoomable(...)`:

```swift
import SwiftUI
import ZoomableView

struct ContentView: View {
    var body: some View {
        GeometryReader { proxy in
            Image(.images)
                .resizable()
                .zoomable(
                    containerSize: proxy.size,
                    logger: ConsoleLogger() // optional
                )
        }
    }
}

struct ConsoleLogger: Logger {
    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        print("[\(level.rawValue.uppercased())] \(message)")
    }
}
```

## Programmatic Centering
Pass a binding to `focusPoint` (in content coordinates). Setting it will center that point in the container; the value is cleared automatically.

```swift
@State private var focus: CGPoint?

GeometryReader { proxy in
    Image(.images)
        .resizable()
        .zoomable(
            containerSize: proxy.size,
            focusPoint: $focus,
            minZoomScale: 1,
            maxZoomScale: 4
        )
}

// Example: center on the middle of the image later
focus = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)
```

## Double Tap Behavior
Double tap toggles between `1.0` scale and `doubleTapZoomScale` (default `2.0`) anchored at the tap location. On iOS 17+ it emits selection haptics.

## Parameters
- `containerSize`: Required. Size of the viewport that should clamp panning.
- `focusPoint`: Optional binding for programmatic centering (cleared after use).
- `minZoomScale` / `maxZoomScale`: Clamps pinch zooming.
- `doubleTapZoomScale`: Target scale when toggling from the base scale.
- `animationDuration`: Duration for double-tap zoom and clamping animations.
- `logger`: Optional `Logger` to observe transforms and clamping.

## Logging
Provide any `Logger` implementation to receive debug messages from gesture end and clamping logic. The protocol supplies `debug`, `info`, `warning`, and `error` helpers.

## Notes
- Content is clamped to stay within the container; if the scaled content is smaller than the container, it recenters automatically.
- On macOS, gesture support depends on available input devices; pinch and double-tap behavior mirror iOS where supported.

