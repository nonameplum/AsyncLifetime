import Foundation

extension AsyncSequence {

  /// Assigns each element from the async sequence to a key path on the specified object, returning both task and cancellable.
  ///
  /// Returns both the task and a cancellable for flexible lifetime management.
  /// Use this when you need direct access to the underlying task on the main actor.
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
  ///         dataStream
  ///             .assignOnMainActorTask(to: \.items, weakOn: self)
  ///             .cancellable
  ///             .store(in: &cancellables)
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - keyPath: The key path to assign values to on the target object.
  ///   - object: The object to assign values to. Uses weak reference to prevent retain cycles.
  /// - Returns: A tuple containing the task and a cancellable object.
  #if swift(<6.2)
    public func assign<Root>(
      isolation: isolated (any Actor)? = #isolation,
      to keyPath: ReferenceWritableKeyPath<Root, Self.Element>,
      weakOn object: Root
    ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
    where Self: Sendable, Root: AnyObject & Sendable, Self.Element: Sendable {
      withLifetime(isolation: isolation, of: object, consuming: self) { object, element in
        object[keyPath: keyPath] = element
      }
    }
  #else
    public func assign<Root>(
      isolation: isolated (any Actor)? = #isolation,
      to keyPath: ReferenceWritableKeyPath<Root, Self.Element>,
      weakOn object: Root
    ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
    where Self: Sendable, Root: AnyObject, Self.Element: Sendable {
      withLifetime(isolation: isolation, of: object, consuming: self) { object, element in
        object[keyPath: keyPath] = element
      }
    }
  #endif

  #if swift(<6.2)
    /// Assigns each element from the async sequence to a key path on the specified object, returning both task and cancellable.
    ///
    /// Returns both the task and a cancellable for flexible lifetime management.
    /// Use this when you need direct access to the underlying task on the main actor.
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
    ///         dataStream
    ///             .assignOnMainActorTask(to: \.items, weakOn: self)
    ///             .cancellable
    ///             .store(in: &cancellables)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: The key path to assign values to on the target object.
    ///   - object: The object to assign values to. Uses weak reference to prevent retain cycles.
    /// - Returns: A tuple containing the task and a cancellable object.
    @MainActor
    public func assignOnMainActor<Root>(
      to keyPath: ReferenceWritableKeyPath<Root, Self.Element>,
      weakOn object: Root
    ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
    where Self: Sendable, Root: AnyObject & Sendable, Self.Element: Sendable {
      withMainActorLifetime(of: object, consuming: self) { object, element in
        object[keyPath: keyPath] = element
      }
    }
  #else
    /// Assigns each element from the async sequence to a key path on the specified object, returning both task and cancellable.
    ///
    /// Returns both the task and a cancellable for flexible lifetime management.
    /// Use this when you need direct access to the underlying task on the main actor.
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
    ///         dataStream
    ///             .assignOnMainActorTask(to: \.items, weakOn: self)
    ///             .cancellable
    ///             .store(in: &cancellables)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: The key path to assign values to on the target object.
    ///   - object: The object to assign values to. Uses weak reference to prevent retain cycles.
    /// - Returns: A tuple containing the task and a cancellable object.
    @MainActor
    public func assignOnMainActor<Root>(
      to keyPath: ReferenceWritableKeyPath<Root, Self.Element>,
      weakOn object: Root
    ) -> (task: Task<Void, any Error>, cancellable: any LifetimeCancellable)
    where Self: Sendable, Root: AnyObject, Self.Element: Sendable {
      withMainActorLifetime(of: object, consuming: self) { object, element in
        object[keyPath: keyPath] = element
      }
    }
  #endif
}
