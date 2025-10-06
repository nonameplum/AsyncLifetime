import Foundation

// MARK: - General Lifetime Functions with Actor Isolation

#if swift(<6.2)
  /// Creates a cancellable for processing elements from an async sequence while an object remains alive, with
  /// configurable actor isolation.
  ///
  /// This is the primary lifetime management function, automatically binding async sequence processing to object
  /// lifetimes.
  /// The function uses weak references to prevent retain cycles and automatically cancels processing when the object is
  /// deallocated.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///   var items: [String] = []
  ///   private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///   init(dataStream: AsyncStream<String>) {
  ///     withLifetime(of: self, consuming: dataStream) { service, item in
  ///       service.items.append(item)
  ///     }
  ///     .cancellable.store(in: &cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values, and the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  /// For guaranteed cleanup, store the returned cancellable and call `cancel()` explicitly when needed.
  ///
  /// - Parameters:
  ///   - isolation: The actor on which the operation should run. Defaults to the current actor context.
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A cancellable object that can be used to stop the processing.
  @discardableResult
  public func withLifetime<Instance, OperationError, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async throws(OperationError) -> Void
  ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject,
    OperationError: Error,
    Stream: AsyncSequence,
    Stream.Element: Sendable
  {
    let task = _withLifetimeTask(
      isolation: isolation,
      of: object,
      consuming: stream,
      forEach: operation
    )
    return (task, AnyLifetimeCancellable(task.cancel))
  }
#else
  /// Creates a cancellable for processing elements from an async sequence while an object remains alive, with
  /// configurable actor isolation.
  ///
  /// This is the primary lifetime management function, automatically binding async sequence processing to object
  /// lifetimes.
  /// The function uses weak references to prevent retain cycles and automatically cancels processing when the object is
  /// deallocated.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///   var items: [String] = []
  ///   private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///   init(dataStream: AsyncStream<String>) {
  ///     withLifetime(of: self, consuming: dataStream) { service, item in
  ///       service.items.append(item)
  ///     }
  ///     .cancellable.store(in: &cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values, and the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  /// For guaranteed cleanup, store the returned cancellable and call `cancel()` explicitly when needed.
  ///
  /// - Parameters:
  ///   - isolation: The actor on which the operation should run. Defaults to the current actor context.
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A cancellable object that can be used to stop the processing.
  @discardableResult
  public func withLifetime<Instance, OperationError, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext(always) forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async throws(OperationError) -> Void
  ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject,
    OperationError: Error,
    Stream: AsyncSequence,
    Stream.Element: Sendable
  {
    let task = _withLifetimeTask(
      isolation: isolation,
      of: object,
      consuming: stream,
      forEach: operation
    )
    return (task, AnyLifetimeCancellable(task.cancel))
  }
#endif

#if swift(<6.2)
  /// Creates a cancellable for processing elements from an async sequence while an object remains alive, with
  /// configurable actor isolation.
  ///
  /// This is the primary lifetime management function, automatically binding async sequence processing to object
  /// lifetimes.
  /// The function uses weak references to prevent retain cycles and automatically cancels processing when the object is
  /// deallocated.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///   var items: [String] = []
  ///   private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///   init(dataStream: AsyncStream<String>) {
  ///     withLifetime(of: self, consuming: dataStream) { service, item in
  ///       service.items.append(item)
  ///     }
  ///     .cancellable.store(in: &cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values, and the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  /// For guaranteed cleanup, store the returned cancellable and call `cancel()` explicitly when needed.
  ///
  /// - Parameters:
  ///   - isolation: The actor on which the operation should run. Defaults to the current actor context.
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A cancellable object that can be used to stop the processing.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @discardableResult
  public func withLifetime<Instance, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async -> Void
  ) -> (task: Task<Void, Never>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject,
    Stream: AsyncSequence,
    Stream.Element: Sendable,
    Stream.Failure == Never
  {
    let task = _withLifetimeTask(
      isolation: isolation,
      of: object,
      consuming: stream,
      forEach: operation
    )
    return (task, AnyLifetimeCancellable(task.cancel))
  }
#else
  /// Creates a cancellable for processing elements from an async sequence while an object remains alive, with
  /// configurable actor isolation.
  ///
  /// This is the primary lifetime management function, automatically binding async sequence processing to object
  /// lifetimes.
  /// The function uses weak references to prevent retain cycles and automatically cancels processing when the object is
  /// deallocated.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///   var items: [String] = []
  ///   private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///   init(dataStream: AsyncStream<String>) {
  ///     withLifetime(of: self, consuming: dataStream) { service, item in
  ///       service.items.append(item)
  ///     }
  ///     .cancellable.store(in: &cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values, and the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  /// For guaranteed cleanup, store the returned cancellable and call `cancel()` explicitly when needed.
  ///
  /// - Parameters:
  ///   - isolation: The actor on which the operation should run. Defaults to the current actor context.
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A cancellable object that can be used to stop the processing.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @discardableResult
  public func withLifetime<Instance, Stream>(
    isolation: isolated (any Actor)? = #isolation,
    of object: sending Instance,
    consuming stream: Stream,
    @_inheritActorContext(always) forEach operation:
      sending @escaping (
        _ object: Instance,
        _ element: Stream.Element
      ) async -> Void
  ) -> (task: Task<Void, Never>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject,
    Stream: AsyncSequence,
    Stream.Element: Sendable,
    Stream.Failure == Never
  {
    let task = _withLifetimeTask(
      isolation: isolation,
      of: object,
      consuming: stream,
      forEach: operation
    )
    return (task, AnyLifetimeCancellable(task.cancel))
  }
#endif
