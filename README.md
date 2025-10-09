# AsyncLifetime

<p align="center">
  <img src="resources/AsyncLifetime-logo.png" alt="AsyncLifetime Logo" width="200"/>
</p>

Automatic lifetime management for async sequences, preventing retain cycles and ensuring proper resource cleanup in Swift's async/await world.

AsyncLifetime provides a suite of functions that automatically bind async sequence processing to object lifetimes. When the target object is deallocated, any ongoing async operations are automatically cancelled, preventing retain cycles and unnecessary computation.

---

- [The Problem](#the-problem)
- [The Solution](#the-solution)  
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Requirements](#requirements)
- [License](#license)

## The Problem

The core issue stems from Swift's `Task` initializer which uses `@_implicitSelfCapture`. Consider this typical pattern in view model initialization:

```swift
@MainActor
@Observable
class Model {
    var items: [String] = []
    
    init(dataStream: AsyncStream<String>) {
        Task {
            for await item in dataStream {
                items.append(item) // self is implicitly strongly captured by Task
            }
        }
    }
}
```

**The Problem**: The `Task` holds a strong reference to `self` (the ViewModel), preventing it from being deallocated even when the UI is dismissed.

## The Solution

AsyncLifetime uses **weak references** to break retain cycles, automatically cancelling operations when the target object is deallocated:

```swift
@MainActor
@Observable
class Model {
    var items: [String] = []
    private var cancellables = Set<AnyLifetimeCancellable>()

    init(dataStream: AsyncStream<String>) {
        withLifetime(of: self, consuming: dataStream) { service, item in
            service.items.append(item)
        }
        .cancellable.store(in: &cancellables)
    }
}
```

## Installation

### Swift Package Manager

The preferred way of installing AsyncLifetime is via the Swift Package Manager.

**In Xcode:**
1. Open your project and navigate to **File → Add Package Dependencies**
2. Paste the repository URL: `https://github.com/nonameplum/AsyncLifetime`
3. Click **Next** and select **Up to Next Major Version**
4. Click **Add Package**

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/nonameplum/AsyncLifetime", from: "1.0.0")
]
```

## Quick Start

### Property Assignment in Initialization

The most common pattern - automatic lifetime binding during initialization:

```swift
import AsyncLifetime

@MainActor
@Observable
class Model {
    var items: [String] = []
    private var cancellables = Set<AnyLifetimeCancellable>()

    init(dataStream: AsyncStream<[String]>) {
        dataStream
            .assign(to: \.items, weakOn: self)
            .store(in: &cancellables)
    }
}
```

### Manual Cancellation Control

Store cancellable objects when you need explicit control:

```swift
@MainActor
@Observable
class Model {
    var items: [String] = []
    private var cancellables = Set<AnyLifetimeCancellable>()

    init(dataStream: AsyncStream<String>) {
        withLifetime(of: self, consuming: dataStream) { service, item in
            service.items.append(item)
        }
        .cancellable.store(in: &cancellables)
    }
    
    func cancel() {
        // Can manually stop all operations
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
```

## Documentation

Full documentation with detailed examples and API reference is available at:

- [AsyncLifetime Documentation](https://nonameplum.github.io/AsyncLifetime/main/documentation/asynclifetime/)

## Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 16.0+ / visionOS 1.0+
- Swift 6.1+
- Xcode 16.0+

## License

AsyncLifetime is released under the MIT license. See [LICENSE](LICENSE) for details.
