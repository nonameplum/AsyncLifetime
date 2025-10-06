// MARK: - Internal Implementation

/*
 Internal task-based implementation with known limitations.

 ⚠️ **Internal Use Only**: This function has a fundamental limitation where it can only detect object deallocation
 when the stream yields a value. If the stream stops yielding and the object is deallocated, the task continues
 running indefinitely.

 This is why the public API returns cancellables instead of tasks - to force explicit lifetime management.

 */

#if swift(<6.2)
  @discardableResult
  func _withLifetimeTask<Instance, OperationError, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async throws(OperationError) -> Void
  ) -> Task<Void, any Error>
  where
    Instance: AnyObject,
    OperationError: Error,
    Stream: AsyncSequence,
    Stream.Element: Sendable
  {
    var task: Task<Void, any Error>?
    task = Task { [weak object] in
      // Capture isolation to affect the task's static isolation
      _ = isolation

      // Exit eagerly if object has been deallocated
      guard object != nil else { return }

      if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
        var iterator = stream.makeAsyncIterator()
        while let element = try await iterator.next(isolation: isolation) {
          guard !Task.isCancelled,
            let object
          else {
            task?.cancel()
            // continue is required to allow the stream to trigger onTermination
            continue
          }

          try await operation(object, element)
        }
      } else {
        for try await element in stream {
          guard !Task.isCancelled,
            let object
          else {
            task?.cancel()
            // continue is required to allow the stream to trigger onTermination
            continue
          }

          try await operation(object, element)
        }
      }
    }
    return task!
  }
#else
  @discardableResult
  func _withLifetimeTask<Instance, OperationError, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext(always) forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async throws(OperationError) -> Void
  ) -> Task<Void, any Error>
  where
    Instance: AnyObject,
    OperationError: Error,
    Stream: AsyncSequence,
    Stream.Element: Sendable
  {
    var task: Task<Void, any Error>?
    task = Task { [weak object] in
      // Capture isolation to affect the task's static isolation
      _ = isolation

      // Exit eagerly if object has been deallocated
      guard object != nil else { return }

      if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
        var iterator = stream.makeAsyncIterator()
        while let element = try await iterator.next(isolation: isolation) {
          guard !Task.isCancelled,
            let object
          else {
            task?.cancel()
            // continue is required to allow the stream to trigger onTermination
            continue
          }

          try await operation(object, element)
        }
      } else {
        for try await element in stream {
          guard !Task.isCancelled,
            let object
          else {
            task?.cancel()
            // continue is required to allow the stream to trigger onTermination
            continue
          }

          try await operation(object, element)
        }
      }
    }
    return task!
  }
#endif

#if swift(<6.2)
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @discardableResult
  func _withLifetimeTask<Instance, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async -> Void
  ) -> Task<Void, Never>
  where
    Instance: AnyObject,
    Stream: AsyncSequence,
    Stream.Element: Sendable,
    Stream.Failure == Never
  {
    var task: Task<Void, Never>?
    task = Task { [weak object] in
      // Capture isolation to affect the task's static isolation
      _ = isolation

      // Exit eagerly if object has been deallocated
      guard object != nil else { return }

      var iterator = stream.makeAsyncIterator()
      while let element = await iterator.next(isolation: isolation) {
        guard !Task.isCancelled,
          let object
        else {
          task?.cancel()
          // continue is required to allow the stream to trigger onTermination
          continue
        }

        await operation(object, element)
      }
    }
    return task!
  }
#else
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @discardableResult
  func _withLifetimeTask<Instance, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext(always) forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async -> Void
  ) -> Task<Void, Never>
  where
    Instance: AnyObject,
    Stream: AsyncSequence,
    Stream.Element: Sendable,
    Stream.Failure == Never
  {
    var task: Task<Void, Never>?
    task = Task { [weak object] in
      // Capture isolation to affect the task's static isolation
      _ = isolation

      // Exit eagerly if object has been deallocated
      guard object != nil else { return }

      var iterator = stream.makeAsyncIterator()
      while let element = await iterator.next(isolation: isolation) {
        guard !Task.isCancelled,
          let object
        else {
          task?.cancel()
          // continue is required to allow the stream to trigger onTermination
          continue
        }

        await operation(object, element)
      }
    }
    return task!
  }
#endif
