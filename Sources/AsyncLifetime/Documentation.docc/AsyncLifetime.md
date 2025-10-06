# ``AsyncLifetime``

Automatic lifetime management for async sequences, preventing retain cycles and ensuring proper resource cleanup.

## Overview

AsyncLifetime provides a suite of functions that automatically bind async sequence processing to object lifetimes. When the target object is deallocated, any ongoing async operations are automatically cancelled, preventing retain cycles and unnecessary computation.

This solves a fundamental problem in Swift's async/await world: automatically stopping async operations when the objects that depend on them are deallocated.

## The Problem We Solve

### The Root Cause: `@_implicitSelfCapture` in Task

The core issue stems from Swift's `Task` initializer which uses `@_implicitSelfCapture`.

Consider this typical pattern in view model initialization:

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

### The AsyncLifetime Solution

With AsyncLifetime, operations automatically stop when the object is deallocated:

```swift
@MainActor
@Observable
class Model {
    var items: [String] = []
    private var cancellables = Set<AnyLifetimeCancellable>()

    init(dataStream: AsyncStream<String>) {
        dataStream
            .assign(to: \.items, weakOn: self)
            .store(in: &cancellables)
    }
}
```

**How it works**: AsyncLifetime uses **weak references** to break the retain cycle, automatically cancelling operations when the target object is deallocated.

## Core Concepts

### 1. Automatic Lifetime Binding

The lifetime of async operations is automatically bound to objects:

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

### 2. Weak References

AsyncLifetime uses weak references to prevent retain cycles:

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

### 3. Actor Isolation

Operations respect Swift's actor isolation:

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

## Quick Start Examples

### Property Assignment in Initialization

The most common pattern - automatic lifetime binding during initialization:

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
    
    func refresh() {
        // Can manually stop all operations
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
```

## Migration Guide

**Before (Retain Cycle):**
```swift
@MainActor
@Observable
class Model {
    var items: [String] = []
    private var task: Task<Void, Never>?
    
    init(dataStream: AsyncStream<String>) {
        // ❌ Creates strong reference to self
        task = Task {
            for await item in dataStream {
                items.append(item) // long running or infinite stream will hold self
            }
        }

        // To break the cycle you would need think wisely and use [weak ...] 
        // and capture object only while processing item in for loop
        task = Task { [weak self] in
            for await item in dataStream {
                guard let self else { return }
                items.append(item) // long running or infinite stream will hold self
            }
        }
    }
    
    deinit {
        // ❌ This never gets called due to Task holding self
        task?.cancel()
    }
}
```

**After AsyncLifetime:**
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
    
    // ✅ deinit is called properly, no manual cleanup needed
}
```