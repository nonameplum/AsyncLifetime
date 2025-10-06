import AsyncAlgorithms
import Foundation
import Testing

@testable import AsyncLifetime

@Suite("withMainActorLifetime")
@MainActor
struct WithMainActorLifetimeTests {

  // MARK: - Basic Functionality Tests (Non-Throwing Variant)

  @Test("Should process all stream elements in order when stream completes successfully")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessAllElementsInOrder_whenStreamCompletesSuccessfully_nonThrowing() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1, 2, 3, 4, 5])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues == [1, 2, 3, 4, 5])
  }

  @Test("Should return both task and cancellable when called")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldReturnTaskAndCancellable_whenCalled_nonThrowing() {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    // Then
    let _: Task<Void, Never> = sut.task
    let _: any LifetimeCancellable = sut.cancellable
    #expect(true, "Both task and cancellable are returned")
  }

  @Test("Should complete task successfully when stream finishes")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCompleteSuccessfully_whenStreamFinishes_nonThrowing() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.count == 3)
  }

  @Test("Should pass correct object reference to operation for each element")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldPassCorrectObjectReference_whenProcessingElements_nonThrowing() async {
    // Given
    let observer = FakeMainActorObserver()
    let receivedObjects = LockIsolated<[ObjectIdentifier]>([])
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      receivedObjects.withValue { $0.append(ObjectIdentifier(obj)) }
      obj.process(value)
    }

    await sut.task.value

    // Then
    let expectedId = ObjectIdentifier(observer)
    #expect(receivedObjects.value.allSatisfy { $0 == expectedId })
  }

  @Test("Should complete immediately when stream is empty")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCompleteImmediately_whenStreamIsEmpty_nonThrowing() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeEmptyStubIntStream()

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.isEmpty)
  }

  @Test("Should handle single element stream correctly")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessCorrectly_whenStreamHasSingleElement_nonThrowing() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [42])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues == [42])
  }

  // MARK: - Basic Functionality Tests (Throwing Variant)

  @Test("Should process all stream elements in order when stream completes successfully")
  func shouldProcessAllElementsInOrder_whenStreamCompletesSuccessfully_throwing() async throws {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1, 2, 3, 4, 5])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    try await sut.task.value

    // Then
    #expect(observer.processedValues == [1, 2, 3, 4, 5])
  }

  @Test("Should return both task and cancellable when called")
  func shouldReturnTaskAndCancellable_whenCalled_throwing() {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    // Then
    let _: Task<Void, any Error> = sut.task
    let _: any LifetimeCancellable = sut.cancellable
    #expect(true, "Both task and cancellable are returned")
  }

  @Test("Should complete task successfully when stream finishes")
  func shouldCompleteSuccessfully_whenStreamFinishes_throwing() async throws {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    try await sut.task.value

    // Then
    #expect(observer.processedValues.count == 3)
  }

  // MARK: - Lifetime Binding Tests

  @Test("Should not retain object preventing deallocation")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldNotRetainObject_whenProcessingStream() async {
    // Given
    weak var weakObserver: FakeMainActorObserver?
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
      let observer = FakeMainActorObserver()
      weakObserver = observer

      let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
        obj.process(value)
      }

      _ = sut
    }

    await progressIterator.next()

    // Then
    #expect(weakObserver == nil, "Observer should be deallocated - no retain cycle")
  }

  @Test("Should stop processing when object is deallocated")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldStopProcessing_whenObjectDeallocates() async {
    // Given
    let processedCount = LockIsolated(0)

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
      let observer = FakeMainActorObserver()
      let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
        processedCount.withValue { $0 += 1 }
        obj.process(value)
      }
      _ = sut
    }

    // Then
    #expect(processedCount.value <= 100, "Should stop shortly after deallocation")
  }

  @Test("Should maintain independent lifecycles when multiple withMainActorLifetime calls exist")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldMaintainIndependentLifecycles_whenMultipleCallsExist() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream1 = makeStubIntStream(values: [1, 2, 3])
    let stubStream2 = makeStubIntStream(values: [10, 20, 30])

    let results1 = LockIsolated<[Int]>([])
    let results2 = LockIsolated<[Int]>([])

    // When
    let sut1 = withMainActorLifetime(of: observer, consuming: stubStream1) { _, value in
      results1.withValue { $0.append(value) }
    }

    let sut2 = withMainActorLifetime(of: observer, consuming: stubStream2) { _, value in
      results2.withValue { $0.append(value) }
    }

    await sut1.task.value
    await sut2.task.value

    // Then
    #expect(results1.value == [1, 2, 3])
    #expect(results2.value == [10, 20, 30])
  }

  @Test("Should continue processing all elements while object remains alive")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldContinueProcessing_whileObjectRemainsAlive() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 50)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.count == 50)
  }

  // MARK: - Cancellation Tests

  @Test("Should stop processing when cancellable is cancelled")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldStopProcessing_whenCancellableIsCancelled() async {
    // Given
    let observer = FakeMainActorObserver()
    var cancellable: (any LifetimeCancellable)?
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 5 {
        cancellable?.cancel()
      }
    }
    cancellable = sut.cancellable

    await sut.task.value

    // Then
    #expect(observer.processedValues.count <= 6, "Should stop shortly after cancellation")
  }

  @Test("Should stop processing when task is cancelled")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldStopProcessing_whenTaskIsCancelled() async {
    // Given
    let observer = FakeMainActorObserver()
    var task: Task<Void, Never>?
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 5 {
        task?.cancel()
      }
    }
    task = sut.task

    await sut.task.value

    // Then
    #expect(observer.processedValues.count <= 6)
  }

  @Test("Should cancel same underlying work when either task or cancellable is cancelled")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCancelSameWork_whenEitherTaskOrCancellableIsCancelled() async {
    // Given
    let observer = FakeMainActorObserver()
    var cancellable: (any LifetimeCancellable)?
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 3 {
        cancellable?.cancel()
      }
    }
    cancellable = sut.cancellable

    await sut.task.value

    // Then
    #expect(sut.task.isCancelled)
  }

  @Test("Should allow cancellable to be stored in Set")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldAllowStorage_whenStoringCancellableInSet() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 3)
    var cancellables = Set<AnyLifetimeCancellable>()

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    sut.cancellable.store(in: &cancellables)

    await sut.task.value

    // Then
    #expect(cancellables.count == 1)
  }

  // MARK: - MainActor Isolation Tests

  @Test("Should iterate stream on MainActor isolation")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  nonisolated func shouldIterateOnMainActorIsolation_whenWithMainActorLifeIsUsed() async {
    // Given
    let observer = FakeObserver()

    let testStream = IsolationCapturingSequence(
      values: [1, 2, 3],
      expectedIsolation: MainActor.shared
    )

    // When
    let sut = await withMainActorLifetime(
      of: observer,
      consuming: testStream
    ) { obj, value in
      obj.process(value)
    }

    await sut.task.value
  }

  @Test("Should run operation on MainActor")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldRunOnMainActor_whenCalled() async {
    // Given
    let observer = FakeMainActorObserver()
    let testStream = IsolationCapturingSequence(
      values: [1, 2, 3],
      expectedIsolation: MainActor.shared
    )

    // When
    let sut = withMainActorLifetime(of: observer, consuming: testStream) { obj, value in
      MainActor.assertIsolated()
      obj.process(value)
    }

    await sut.task.value

    // Then
    #expect(observer.processedValues.count == 3)
  }

  // MARK: - Error Handling Tests (Throwing Variant)

  @Test("Should propagate error to task when operation throws")
  func shouldPropagateErrorToTask_whenOperationThrows() async throws {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1, 2, 3])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 2 {
        throw TestError.operationFailed
      }
    }

    // Then
    await #expect(throws: TestError.operationFailed) {
      try await sut.task.value
    }
    #expect(observer.processedValues.count <= 2)
  }

  @Test("Should propagate error to task when stream throws")
  func shouldPropagateErrorToTask_whenStreamThrows() async throws {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1, 2], thenError: TestError.streamFailed)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    // Then
    await #expect(throws: TestError.streamFailed) {
      try await sut.task.value
    }
  }

  @Test("Should stop processing immediately when error is thrown")
  func shouldStopProcessingImmediately_whenErrorIsThrown() async throws {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(values: [1, 2, 3, 4, 5])

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
      if value == 3 {
        throw TestError.operationFailed
      }
    }

    // Then
    do {
      try await sut.task.value
    } catch {
      // Expected
    }

    #expect(observer.processedValues == [1, 2, 3])
  }

  // MARK: - Edge Cases Tests

  @Test("Should not process when object deallocated before first yield")
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
      let observer = FakeMainActorObserver()

      let sut = withMainActorLifetime(of: observer, consuming: fakeStream) { obj, value in
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
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessIndependently_whenMultipleObjectsProcessSimultaneously() async {
    // Given
    let observer1 = FakeMainActorObserver()
    let observer2 = FakeMainActorObserver()
    let observer3 = FakeMainActorObserver()

    let stubStream1 = makeStubIntStream(values: [1, 2])
    let stubStream2 = makeStubIntStream(values: [10, 20])
    let stubStream3 = makeStubIntStream(values: [100, 200])

    // When
    let sut1 = withMainActorLifetime(of: observer1, consuming: stubStream1) { obj, value in
      obj.process(value)
    }

    let sut2 = withMainActorLifetime(of: observer2, consuming: stubStream2) { obj, value in
      obj.process(value)
    }

    let sut3 = withMainActorLifetime(of: observer3, consuming: stubStream3) { obj, value in
      obj.process(value)
    }

    await sut1.task.value
    await sut2.task.value
    await sut3.task.value

    // Then
    #expect(observer1.processedValues == [1, 2])
    #expect(observer2.processedValues == [10, 20])
    #expect(observer3.processedValues == [100, 200])
  }

  @Test("Should process all streams when same object consumes multiple streams")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldProcessAllStreams_whenSameObjectConsumesMultipleStreams() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream1 = makeStubIntStream(values: [1, 2, 3])
    let stubStream2 = makeStubIntStream(values: [4, 5, 6])

    // When
    let sut1 = withMainActorLifetime(of: observer, consuming: stubStream1) { obj, value in
      obj.process(value)
    }

    let sut2 = withMainActorLifetime(of: observer, consuming: stubStream2) { obj, value in
      obj.process(value)
    }

    await sut1.task.value
    await sut2.task.value

    // Then
    #expect(observer.processedValues.count == 6)
    #expect(observer.processedValues.contains(1))
    #expect(observer.processedValues.contains(6))
  }

  // MARK: - Task Properties Tests

  @Test("Should allow task value to be awaited")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldAllowAwait_whenAccessingTaskValue() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 3)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    // Then
    await sut.task.value
  }

  @Test("Should reflect cancellation state in task isCancelled property")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldReflectCancellationState_whenCheckingTaskIsCancelled() async {
    // Given
    let observer = FakeMainActorObserver()
    let stubStream = makeStubIntStream(count: 100)

    // When
    let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
      obj.process(value)
    }

    #expect(sut.task.isCancelled == false, "Task should not be cancelled initially")

    sut.task.cancel()
    await sut.task.value

    // Then
    #expect(sut.task.isCancelled == true, "Task should be cancelled after cancel() is called")
  }

  @Test("Should cancel task when Set containing cancellable is deallocated")
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func shouldCancelTask_whenSetContainingCancellableIsDeallocated() async {
    // Given
    let observer = FakeMainActorObserver()
    let task: Task<Void, Never>?
    let stubStream = makeStubIntStream(count: 100)

    // When
    do {
      var cancellables = Set<AnyLifetimeCancellable>()

      let sut = withMainActorLifetime(of: observer, consuming: stubStream) { obj, value in
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
