import AsyncAlgorithms
import Foundation
import Testing

@testable import AsyncLifetime

/// Unit tests to demonstrate limitations of the internal _withLifetimeTask, thats why is not exposed as a public API.

@Suite("AsyncLifetime Known Limitations")
struct AsyncLifetimeLoopholeTests {
  @Test("Demonstrate isolation by explicit closure annotation")
  @MainActor
  func closure_isolation() async throws {
    let observer = Observer()
    let stream = makeStubStream()

    // Even though operation is marked with `@_inheritActorContext(always)` currently in Swift there is no way
    // to express the `operation/forEach` closure isolation statically so it would be known by the compiler.
    // Operation closure needs to be marked with `@TestGlobalActor` explicitly to run on desired isolation.
    let task = await _withLifetimeTask(
      isolation: TestGlobalActor.shared,
      of: observer,
      consuming: stream
    ) { @TestGlobalActor observer, item in
      #if swift(<6.2)
        // Workaround to Sending value of non-Sendable type '@TestGlobalActor @Sendable (Observer, Int) async -> Void' risks causing data races
        // From https://github.com/swiftlang/swift/issues/76488
        await Task.yield()
      #endif
      TestGlobalActor.shared.assertIsolated()
      observer.append(item)
    }

    try await task.value
  }

  @Test("Demonstrate lack of explicit closure isolation annotation")
  @MainActor
  func closure_without_explicit_isolation() async throws {
    let observer = Observer()
    let stream = makeStubStream()

    // Even though operation is marked with `@_inheritActorContext(always)` currently in Swift there is no way
    // to express the `operation/forEach` closure isolation statically so it would be known by the compiler.
    // Operation closure needs to be marked with `@TestGlobalActor` explicitly to run on desired isolation.
    let task = await _withLifetimeTask(
      isolation: TestGlobalActor.shared,
      of: observer,
      consuming: stream
    ) { observer, item in
      // without @TestGlobalActor it runs on @MainActor because of the test method annotation
      MainActor.assertIsolated()
      await observer.append(item)
    }

    try await task.value
  }

  @Test("Demonstrate isolation inheritance by surrounding context")
  func inherit_surrounding_isolation() async throws {
    let observer = Observer()
    let stream = makeStubStream()

    // Another approach is to mark a method with desired isolation, and operation closure with inherit automatically
    // isolation from the context
    @TestGlobalActor
    func observe() -> Task<Void, any Error> {
      _withLifetimeTask(
        of: observer,
        consuming: stream
      ) { observer, item in  // No need to mark closure with @TestGlobalActor
        TestGlobalActor.shared.assertIsolated()
        observer.append(item)
      }
    }

    let task = await observe()
    try await task.value
  }

  @Test("Demonstrate mix where context isolation is inherited with explicit closure isolation")
  @MainActor
  func inherited_isolation_with_explicit_in_closure() async throws {
    let observer = Observer()
    let stream = makeStubStream()

    // In this example isolation is not passed explicitly, so the internal Task in _withLifetimeTask will run on the @MainActor,
    // so the stream will be consumed on the @MainActor, but the operation will be run on the marked @TestGlobalActor.
    let task = _withLifetimeTask(
      of: observer,
      consuming: stream
    ) { @TestGlobalActor observer, item in
      #if swift(<6.2)
        // Workaround to Sending value of non-Sendable type '@TestGlobalActor @Sendable (Observer, Int) async -> Void' risks causing data races
        // From https://github.com/swiftlang/swift/issues/76488
        await Task.yield()
      #endif
      TestGlobalActor.shared.assertIsolated()
      observer.append(item)
    }

    try await task.value
  }

  @Test("Demonstrate non isolated use case")
  nonisolated func test_non_isolated() async throws {
    let observer = Observer()
    let stream = makeStubStream()

    // In this example neither test nor _withLifetimeTask is using explicit isolation to it is running non-isolated (GlobalActor)
    let task = _withLifetimeTask(
      of: observer,
      consuming: stream
    ) { observer, item in
      // await is need as it is running without actor isolation (@GlobalActor)
      await observer.append(item)
    }

    try await task.value
  }

  // MARK: - Known Issue: Stream Doesn't Yield After Deallocation

  @Test("KNOWN ISSUE - when object deallocated after last yield then task continues running")
  @TestGlobalActor
  func known_issue_object_deallocated_after_last_yield_task_continues() async throws {
    @TestGlobalActor
    class Observer {
      var processedCount = 0

      func processElement(_: Int) {
        TestGlobalActor.assumeIsolated {
          self.processedCount += 1
        }
      }
    }

    await confirmation(expectedCount: 0) { confirm in
      // Use AsyncChannel to fully control the run of the test instead of using e.g. Task.sleep
      let testProgress = AsyncChannel<Void>()
      var testProbePoint = testProgress.makeAsyncIterator()
      let testFinished = LockIsolated(false)

      let stream = AsyncStream<Int> { continuation in
        let task = Task {
          // Yield the first and only value from the stream
          continuation.yield(1)
        }

        continuation.onTermination = { _ in
          if !testFinished.value {
            // Confirm shouldn't be called
            confirm()
          }
          task.cancel()
        }
      }

      var observer: Observer? = Observer()

      // Start the lifetime-bound task
      let task = _withLifetimeTask(
        of: observer!,
        consuming: stream
      ) { obs, element in
        TestGlobalActor.assumeIsolated {
          obs.processElement(element)
        }
        // Signal
        await testProgress.send(())
      }

      // Wait for first element to be processed
      await testProbePoint.next()
      let processedAfterFirstYield = observer!.processedCount

      // Deallocate observer while stream is sleeping
      observer = nil

      // ⚠️ The task continues running here because:
      // 1. The for loop is blocked waiting for the next yield
      // 2. It can't check if object is nil until stream yields again
      // 3. When stream yields again, it will finally detect deallocation and exit

      // Verify the known limitation
      #expect(processedAfterFirstYield == 1, "Should have processed the first element")
      #expect(!task.isCancelled, "Task is still running despite object deallocation")

      // Explicitly mark that by purpose the Task is canceled to allow finish the test
      testFinished.withValue { $0 = true }
      task.cancel()
    }
  }

  @Test("KNOWN ISSUE - stream that never yields keeps task running indefinitely")
  @TestGlobalActor
  func known_issue_stream_never_yields_task_runs_indefinitely() async throws {
    @TestGlobalActor
    class Observer {
      var processedCount = 0
    }

    try await confirmation(expectedCount: 0) { confirm in
      // Use AsyncChannel to fully control the run of the test instead of using e.g. Task.sleep
      let testProgress = AsyncChannel<Void>()
      var testProbePoint = testProgress.makeAsyncIterator()
      let testFinished = LockIsolated(false)

      let stream = AsyncStream<Int> { continuation in
        Task {
          await testProgress.send(())
        }
        continuation.onTermination = { _ in
          if !testFinished.value {
            // Confirm shouldn't be called
            confirm()
          }
        }
      }

      var observer: Observer? = Observer()

      // Start the lifetime-bound task
      let task = _withLifetimeTask(of: observer!, consuming: stream) { obs, _ in
        TestGlobalActor.assumeIsolated {
          obs.processedCount += 1
        }
      }

      // Wait a bit
      await testProbePoint.next()

      // Deallocate observer
      observer = nil

      // ⚠️ The task will continue running indefinitely because:
      // 1. The for loop is blocked waiting for the first yield
      // 2. Since no yields occur, it never gets a chance to check if object is nil
      // 3. Only manual cancellation can stop it

      // Wait a bit more to demonstrate the issue
      try await Task.sleep(for: .seconds(1))

      #expect(task.isCancelled == false, "Task is still running despite object deallocation ")

      // Explicitly mark that by purpose the Task is canceled to allow finish the test
      testFinished.withValue { $0 = true }
      task.cancel()
    }
  }
}

// MARK: - Test helpers

@TestGlobalActor
private class Observer {
  var items: [Int] = []

  func append(_ item: Int) {
    items.append(item)
  }
}

@MainActor
@Observable
private class Model {
  var items: [String] = []
  private var cancellables = Set<AnyLifetimeCancellable>()
  init(dataStream: AsyncStream<String>) {
    withLifetime(of: self, consuming: dataStream) { service, item in
      service.items.append(item)
    }
    .cancellable.store(in: &cancellables)
  }
}

private func makeStubStream() -> AsyncStream<Int> {
  AsyncStream<Int> { continuation in
    let task = Task {
      for i in 1...10 {
        continuation.yield(i)
      }
      continuation.finish()
    }

    continuation.onTermination = { _ in
      task.cancel()
    }
  }
}
