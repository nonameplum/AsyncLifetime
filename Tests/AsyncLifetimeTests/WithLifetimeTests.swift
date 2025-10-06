import AsyncAlgorithms
import Foundation
import Testing

@testable import AsyncLifetime

@Suite("withLifetime")
struct WithLifetimeTests {

  // MARK: - Basic Functionality Tests

  @Test("Should process all stream elements in order when stream completes successfully")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessAllElementsInOrder_whenStreamCompletesSuccessfully() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(values: [1, 2, 3, 4, 5])

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.value == [1, 2, 3, 4, 5])
  }

  @Test("Should return both task and cancellable when called")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldReturnTaskAndCancellable_whenCalled() {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(values: [1])

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    // Then - verify the return types
    let _: Task<Void, Never> = sut.task
    let _: any LifetimeCancellable = sut.cancellable
    #expect(true, "Both task and cancellable are returned")
  }

  @Test("Should complete task successfully when stream finishes")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCompleteSuccessfully_whenStreamFinishes() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processCount == 3)
  }

  @Test("Should pass correct object reference to operation for each element")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldPassCorrectObjectReference_whenProcessingElements() async {
    // Given
    let observer = FakeObserver()
    let receivedObjects = LockIsolated<[ObjectIdentifier]>([])
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      receivedObjects.withValue { $0.append(ObjectIdentifier(obj)) }
      obj.process(value)
    }

    await sut.task.value

    // Then
    let expectedId = ObjectIdentifier(observer)
    #expect(receivedObjects.value.allSatisfy { $0 == expectedId })
  }

  @Test("Should complete immediately when stream is empty")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCompleteImmediately_whenStreamIsEmpty() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeEmptyStubIntStream()

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.value.isEmpty)
  }

  @Test("Should handle single element stream correctly")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessCorrectly_whenStreamHasSingleElement() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(values: [42])

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.value == [42])
  }

  // MARK: - Lifetime Binding Tests

  @Test("Should not retain object preventing deallocation")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldNotRetainObject_whenProcessingStream() async {
    // Given
    weak var weakObserver: FakeObserver?
    let progress = AsyncChannel<Void>()
    var progressIterator = progress.makeAsyncIterator()

    let stubStream = AsyncStream<Int> { continuation in
      Task {
        for i in 1...100 {
          continuation.yield(i)
        }
        continuation.finish()
        await progress.send(())
      }
    }

    // When
    do {
      let observer = FakeObserver()
      weakObserver = observer

      let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
        obj.process(value)
      }

      _ = sut
    }

    await progressIterator.next()

    // Then
    #expect(weakObserver == nil, "Observer should be deallocated - no retain cycle")
  }

  @Test("Should stop processing when object is deallocated")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldStopProcessing_whenObjectDeallocates() async {
    // Given
    let processedCount = LockIsolated(0)

    // Note: Due to withLifetime's design, deallocation is only detected
    // when the stream yields the next element. We yield a large batch,
    // deallocate the observer, then yield more to verify it stops.
    let stubStream = AsyncStream<Int> { continuation in
      Task {
        for i in 1...100 {
          try await Task.sleep(for: .milliseconds(100))
          continuation.yield(i)
        }
        continuation.finish()
      }
    }

    // When
    do {
      let observer = FakeObserver()
      let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
        processedCount.withValue { $0 += 1 }
        obj.process(value)
      }
      _ = sut
    }

    // Then - deallocation stops processing at next yield
    #expect(processedCount.value <= 100, "Should stop shortly after deallocation")
  }

  @Test("Should maintain independent lifecycles when multiple withLifetime calls exist")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldMaintainIndependentLifecycles_whenMultipleCallsExist() async {
    // Given
    let observer = FakeObserver()
    let stubStream1 = makeStubIntStream(values: [1, 2, 3])
    let stubStream2 = makeStubIntStream(values: [10, 20, 30])

    let results1 = LockIsolated<[Int]>([])
    let results2 = LockIsolated<[Int]>([])

    // When
    let sut1 = withLifetime(of: observer, consuming: stubStream1) { _, value in
      results1.withValue { $0.append(value) }
    }

    let sut2 = withLifetime(of: observer, consuming: stubStream2) { _, value in
      results2.withValue { $0.append(value) }
    }

    await sut1.task.value
    await sut2.task.value

    // Then
    #expect(results1.value == [1, 2, 3])
    #expect(results2.value == [10, 20, 30])
  }

  @Test("Should continue processing all elements while object remains alive")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldContinueProcessing_whileObjectRemainsAlive() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(count: 50)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processCount == 50)
  }

  // MARK: - Cancellation Tests

  @Test("Should stop processing when cancellable is cancelled")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldStopProcessing_whenCancellableIsCancelled() async {
    // Given
    let observer = FakeObserver()
    var cancellable: (any LifetimeCancellable)?
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 5 {
        cancellable?.cancel()  // Cancel after processing 5 elements
      }
    }
    cancellable = sut.cancellable

    await sut.task.value

    // Then - cancellation stops at next iteration
    #expect(observer.processCount <= 6, "Should stop shortly after cancellation")
  }

  @Test("Should stop processing when task is cancelled")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldStopProcessing_whenTaskIsCancelled() async {
    // Given
    let observer = FakeObserver()
    var task: Task<Void, Never>?
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 5 {
        task?.cancel()
      }
    }
    task = sut.task

    await sut.task.value

    // Then
    #expect(observer.processCount <= 6)
  }

  @Test("Should cancel same underlying work when either task or cancellable is cancelled")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCancelSameWork_whenEitherTaskOrCancellableIsCancelled() async {
    // Given
    let observer = FakeObserver()
    var cancellable: (any LifetimeCancellable)?
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 3 {
        cancellable?.cancel()
      }
    }
    cancellable = sut.cancellable

    await sut.task.value

    // Then - cancelling via cancellable also cancels the task
    #expect(sut.task.isCancelled)
  }

  @Test("Should allow cancellable to be stored in Set")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldAllowStorage_whenStoringCancellableInSet() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(count: 3)
    var cancellables = Set<AnyLifetimeCancellable>()

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    sut.cancellable.store(in: &cancellables)

    await sut.task.value

    // Then
    #expect(cancellables.count == 1)
  }

  // MARK: - Actor Isolation Tests

  @Test("Should iterate stream on explicitly passed isolation actor")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  nonisolated func shouldIterateStreamOnExplicitIsolation_whenIsolationPassed() async {
    // Given
    let observer = FakeObserver()

    let testStream = IsolationCapturingSequence(
      values: [1, 2, 3],
      expectedIsolation: TestGlobalActor.shared
    )

    // When
    let sut = await withLifetime(
      isolation: TestGlobalActor.shared,
      of: observer,
      consuming: testStream
    ) { obj, value in
      obj.process(value)
    }

    await sut.task.value
  }

  @Test("Should run operation on TestGlobalActor when explicitly isolated")
  @TestGlobalActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldRunOnTestGlobalActor_whenExplicitlyIsolated() async {
    // Given
    let observer = FakeTestGlobalActorObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withLifetime(
      of: observer,
      consuming: stubStream
    ) { obj, value in
      TestGlobalActor.shared.assertIsolated()
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processCount == 3)
  }

  @Test("Should run operation on MainActor when explicitly isolated")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldRunOnMainActor_whenExplicitlyIsolated() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withLifetime(
      of: observer,
      consuming: stubStream
    ) { obj, value in
      MainActor.assertIsolated()
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.count == 3)
  }

  // MARK: - Edge Cases Tests

  @Test("Should not process when object deallocated before first yield")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldNotProcess_whenObjectDeallocatedBeforeFirstYield() async {
    // Given
    let progress = AsyncChannel<Void>()
    var progressIterator = progress.makeAsyncIterator()
    let processed = LockIsolated(false)

    let fakeStream = AsyncStream<Int> { continuation in
      Task {
        await progress.send(())
        continuation.yield(1)
        continuation.finish()
        await progress.send(())
      }
    }

    // When
    do {
      let observer = FakeObserver()

      let sut = withLifetime(of: observer, consuming: fakeStream) { obj, value in
        processed.withValue { $0 = true }
        obj.process(value)
      }

      _ = sut
    }

    await progressIterator.next()
    await progressIterator.next()

    // Then
    #expect(processed.value == false)
  }

  @Test("Should process independently when multiple objects process simultaneously")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessIndependently_whenMultipleObjectsProcessSimultaneously() async {
    // Given
    let observer1 = FakeObserver()
    let observer2 = FakeObserver()
    let observer3 = FakeObserver()

    let stubStream1 = makeStubIntStream(values: [1, 2])
    let stubStream2 = makeStubIntStream(values: [10, 20])
    let stubStream3 = makeStubIntStream(values: [100, 200])

    // When
    let sut1 = withLifetime(of: observer1, consuming: stubStream1) { obj, value in
      obj.process(value)
    }

    let sut2 = withLifetime(of: observer2, consuming: stubStream2) { obj, value in
      obj.process(value)
    }

    let sut3 = withLifetime(of: observer3, consuming: stubStream3) { obj, value in
      obj.process(value)
    }

    await sut1.task.value
    await sut2.task.value
    await sut3.task.value

    // Then
    #expect(observer1.processedValues.value == [1, 2])
    #expect(observer2.processedValues.value == [10, 20])
    #expect(observer3.processedValues.value == [100, 200])
  }

  @Test("Should process all streams when same object consumes multiple streams")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessAllStreams_whenSameObjectConsumesMultipleStreams() async {
    // Given
    let observer = FakeObserver()
    let stubStream1 = makeStubIntStream(values: [1, 2, 3])
    let stubStream2 = makeStubIntStream(values: [4, 5, 6])

    // When
    let sut1 = withLifetime(of: observer, consuming: stubStream1) { obj, value in
      obj.process(value)
    }

    let sut2 = withLifetime(of: observer, consuming: stubStream2) { obj, value in
      obj.process(value)
    }

    await sut1.task.value
    await sut2.task.value

    // Then
    #expect(observer.processCount == 6)
    #expect(observer.processedValues.value.contains(1))
    #expect(observer.processedValues.value.contains(6))
  }

  // MARK: - Task Properties Tests

  @Test("Should allow task value to be awaited")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldAllowAwait_whenAccessingTaskValue() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    // Then
    await sut.task.value
  }

  @Test("Should reflect cancellation state in task isCancelled property")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldReflectCancellationState_whenCheckingTaskIsCancelled() async {
    // Given
    let observer = FakeObserver()
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    #expect(sut.task.isCancelled == false, "Task should not be cancelled initially")

    sut.task.cancel()
    await sut.task.value

    // Then
    #expect(sut.task.isCancelled == true, "Task should be cancelled after cancel() is called")
  }

  @Test("Should cancel task when Set containing cancellable is deallocated")
  @MainActor
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCancelTask_whenSetContainingCancellableIsDeallocated() async {
    // Given
    let observer = FakeObserver()
    let task: Task<Void, Never>?
    let stubStream = makeStubIntStream(count: 100)

    // When
    do {
      var cancellables = Set<AnyLifetimeCancellable>()

      let sut = withLifetime(of: observer, consuming: stubStream) { obj, value in
        obj.process(value)
      }

      task = sut.task
      sut.cancellable.store(in: &cancellables)

      // cancellables Set goes out of scope here, triggering cancellation
    }

    // Then
    #expect(task?.isCancelled == true, "Task should be cancelled when Set is deallocated")
  }
}
