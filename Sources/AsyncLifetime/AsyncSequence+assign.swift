import Foundation

extension AsyncSequence {

  #if swift(<6.2)
    /// Assigns each element from the async sequence to a key path on the specified object, returning both task and cancellable.
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
    ///     init(dataStream: AsyncStream<[String]>) {
    ///         dataStream
    ///             .assign(to: \.items, weakOn: self)
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
    /// Assigns each element from the async sequence to a key path on the specified object, returning both task and cancellable.
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
    ///     init(dataStream: AsyncStream<[String]>) {
    ///         dataStream
    ///             .assign(to: \.items, weakOn: self)
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
    /// Assigns each element from the async sequence on the MainActor to a key path on the specified object, returning both task and cancellable.
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
    ///     init(dataStream: AsyncStream<[String]>) {
    ///         dataStream
    ///             .assignOnMainActor(to: \.items, weakOn: self)
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
    /// Assigns each element from the async sequence on the MainActor to a key path on the specified object, returning both task and cancellable.
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
    ///     init(dataStream: AsyncStream<[String]>) {
    ///         dataStream
    ///             .assignOnMainActor(to: \.items, weakOn: self)
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
