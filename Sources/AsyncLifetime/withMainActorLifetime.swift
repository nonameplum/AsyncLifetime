import Foundation

// MARK: - Main Actor Lifetime Functions

#if swift(<6.2)
  /// Creates a task and cancellable for processing elements from an async sequence while an object remains alive, running
  /// on the main actor.
  ///
  /// This function provides both the task and cancellable for more flexible lifetime management.
  /// Use this when you need direct access to the underlying task.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///     var items: [String] = []
  ///     private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///     init(dataStream: AsyncStream<String>) {
  ///         let (task, cancellable) = withMainActorLifetimeTask(of: self, consuming: dataStream) { service, item in
  ///             service.items.append(item)
  ///         }
  ///
  ///         // Can access both task and cancellable
  ///         print("Task created: \(task)")
  ///         cancellable.store(in: &cancellables)
  ///     }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values after the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  ///
  /// - Parameters:
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A tuple containing the task and a cancellable object.
  @MainActor
  public func withMainActorLifetime<Instance, OperationError, Stream>(
    of object: Instance,
    consuming stream: Stream,
    forEach operation:
      @MainActor
    @escaping (
      _ object: Instance,
      _ element: Stream.Element
    ) throws(OperationError) -> Void
  ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject & Sendable,
    OperationError: Error,
    Stream: AsyncSequence,
    Stream.Element: Sendable
  {
    withLifetime(isolation: MainActor.shared, of: object, consuming: stream, forEach: operation)
  }
#else
  /// Creates a task and cancellable for processing elements from an async sequence while an object remains alive, running
  /// on the main actor.
  ///
  /// This function provides both the task and cancellable for more flexible lifetime management.
  /// Use this when you need direct access to the underlying task.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///     var items: [String] = []
  ///     private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///     init(dataStream: AsyncStream<String>) {
  ///         let (task, cancellable) = withMainActorLifetimeTask(of: self, consuming: dataStream) { service, item in
  ///             service.items.append(item)
  ///         }
  ///
  ///         // Can access both task and cancellable
  ///         print("Task created: \(task)")
  ///         cancellable.store(in: &cancellables)
  ///     }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values after the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  ///
  /// - Parameters:
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A tuple containing the task and a cancellable object.
  @MainActor
  public func withMainActorLifetime<Instance, OperationError, Stream>(
    of object: Instance,
    consuming stream: Stream,
    forEach operation:
      @MainActor
    @escaping (
      _ object: Instance,
      _ element: Stream.Element
    ) throws(OperationError) -> Void
  ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject,
    OperationError: Error,
    Stream: AsyncSequence,
    Stream.Element: Sendable
  {
    withLifetime(isolation: MainActor.shared, of: object, consuming: stream, forEach: operation)
  }
#endif

#if swift(<6.2)
  /// Creates a task and cancellable for processing elements from an async sequence while an object remains alive, running
  /// on the main actor.
  ///
  /// This function provides both the task and cancellable for more flexible lifetime management.
  /// Use this when you need direct access to the underlying task.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///     var items: [String] = []
  ///     private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///     init(dataStream: AsyncStream<String>) {
  ///         let (task, cancellable) = withMainActorLifetimeTask(of: self, consuming: dataStream) { service, item in
  ///             service.items.append(item)
  ///         }
  ///
  ///         // Can access both task and cancellable
  ///         print("Task created: \(task)")
  ///         cancellable.store(in: &cancellables)
  ///     }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values after the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  ///
  /// - Parameters:
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A tuple containing the task and a cancellable object.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @MainActor
  public func withMainActorLifetime<Instance, Stream>(
    of object: Instance,
    consuming stream: Stream,
    forEach operation:
      @MainActor
    @escaping (
      _ object: Instance,
      _ element: Stream.Element
    ) -> Void
  ) -> (task: Task<Void, Never>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject & Sendable,
    Stream: AsyncSequence,
    Stream.Element: Sendable,
    Stream.Failure == Never
  {
    withLifetime(isolation: MainActor.shared, of: object, consuming: stream, forEach: operation)
  }
#else
  /// Creates a task and cancellable for processing elements from an async sequence while an object remains alive, running
  /// on the main actor.
  ///
  /// This function provides both the task and cancellable for more flexible lifetime management.
  /// Use this when you need direct access to the underlying task.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// @MainActor
  /// @Observable
  /// class Model {
  ///     var items: [String] = []
  ///     private var cancellables = Set<AnyLifetimeCancellable>()
  ///
  ///     init(dataStream: AsyncStream<String>) {
  ///         let (task, cancellable) = withMainActorLifetimeTask(of: self, consuming: dataStream) { service, item in
  ///             service.items.append(item)
  ///         }
  ///
  ///         // Can access both task and cancellable
  ///         print("Task created: \(task)")
  ///         cancellable.store(in: &cancellables)
  ///     }
  /// }
  /// ```
  ///
  /// ## Important: Known Limitation
  ///
  /// ⚠️ **Stream Yield Dependency**: This function can only detect object deallocation when the stream yields a new value.
  /// If your stream stops yielding values after the object is deallocated, the task will continue running until the next
  /// yield (which may never come).
  ///
  /// - Parameters:
  ///   - object: The object whose lifetime bounds the async sequence processing. Uses weak reference to prevent retain
  /// cycles.
  ///   - stream: The async sequence to process.
  ///   - operation: The closure to execute for each element.
  /// - Returns: A tuple containing the task and a cancellable object.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @MainActor
  public func withMainActorLifetime<Instance, Stream>(
    of object: Instance,
    consuming stream: Stream,
    forEach operation:
      @MainActor
    @escaping (
      _ object: Instance,
      _ element: Stream.Element
    ) -> Void
  ) -> (task: Task<Void, Never>, cancellable: any LifetimeCancellable)
  where
    Instance: AnyObject,
    Stream: AsyncSequence,
    Stream.Element: Sendable,
    Stream.Failure == Never
  {
    withLifetime(isolation: MainActor.shared, of: object, consuming: stream, forEach: operation)
  }
#endif
