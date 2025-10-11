import Foundation
import os

/// A protocol that represents an object that can be cancelled to terminate its associated lifetime-bound operations.
///
/// This protocol is similar to `Cancellable` from Combine but is designed specifically for async sequence
/// lifetime management. When an object conforming to this protocol is cancelled, any associated async
/// operations should be terminated gracefully.
///
/// ## Usage
///
/// Objects conforming to this protocol are typically returned from ``withLifetime(isolation:of:consuming:forEach:)``
/// and related functions to allow manual cancellation of async operations bound to an object's lifetime.
///
/// ```swift
/// let cancellable = asyncSequence.assign(to: \.value, weakOn: viewModel)
/// // Later, when you need to stop the operation
/// cancellable.cancel()
/// ```
public protocol LifetimeCancellable: Sendable {
  /// Cancels the associated lifetime-bound operation.
  ///
  /// After calling this method, any ongoing async operations should terminate gracefully.
  /// Calling `cancel()` multiple times should be safe and have no additional effect.
  func cancel()
}

extension LifetimeCancellable {
  /// Stores this cancellable in the specified collection.
  ///
  /// This method appends the cancellable to a collection for later batch cancellation
  /// or automatic cleanup when the collection is deallocated.
  ///
  /// If this cancellable is already an `AnyLifetimeCancellable`, it will be stored directly,
  /// preserving instance identity. Otherwise, a new wrapper will be created.
  ///
  /// - Parameter collection: A mutable collection to store the cancellable in.
  public func store<Cancellables: RangeReplaceableCollection>(
    in collection: inout Cancellables
  ) where Cancellables.Element == AnyLifetimeCancellable {
    if let anyLifetimeCancellable = self as? AnyLifetimeCancellable {
      anyLifetimeCancellable.store(in: &collection)
    } else {
      AnyLifetimeCancellable(self).store(in: &collection)
    }
  }

  /// Stores this cancellable in the specified set.
  ///
  /// This method inserts the cancellable into a set for later batch cancellation
  /// or automatic cleanup when the set is deallocated.
  ///
  /// If this cancellable is already an `AnyLifetimeCancellable`, it will be stored directly,
  /// preserving instance identity. Otherwise, a new wrapper will be created.
  ///
  /// - Parameter set: A mutable set to store the cancellable in.
  public func store(in set: inout Set<AnyLifetimeCancellable>) {
    if let anyLifetimeCancellable = self as? AnyLifetimeCancellable {
      anyLifetimeCancellable.store(in: &set)
    } else {
      AnyLifetimeCancellable(self).store(in: &set)
    }
  }
}

/// A type-erased lifetime cancellable that wraps any ``LifetimeCancellable`` object.
///
/// Use `AnyLifetimeCancellable` to store cancellables in collections or when you need
/// to hide the specific type of a cancellable object.
///
/// ## Automatic Cleanup
///
/// `AnyLifetimeCancellable` automatically cancels its wrapped cancellable when deallocated,
/// ensuring that resources are properly cleaned up even if `cancel()` is never called explicitly.
///
/// ```swift
/// var cancellables = Set<AnyLifetimeCancellable>()
///
/// asyncSequence
///     .assign(to: \.value, weakOn: viewModel)
///     .store(in: &cancellables)
///
/// // When cancellables is deallocated, all stored cancellables are automatically cancelled
/// ```
public final class AnyLifetimeCancellable: LifetimeCancellable, Hashable, @unchecked Sendable {
  private var _cancel = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)

  /// Initializes the cancellable object with the given cancel-time closure.
  ///
  /// - Parameter cancel: A closure that the `cancel()` method executes.
  public init(_ cancel: @escaping @Sendable () -> Void) {
    _cancel.withLock {
      $0 = cancel
    }
  }

  /// Initializes the cancellable object with another cancellable object.
  ///
  /// - Parameter canceller: The cancellable object to wrap.
  public init<OtherCancellable: LifetimeCancellable>(_ canceller: OtherCancellable) {
    _cancel.withLock {
      $0 = canceller.cancel
    }
  }

  /// Cancels the wrapped cancellable.
  ///
  /// This method is safe to call multiple times. After the first call,
  /// subsequent calls have no effect.
  public func cancel() {
    let cancel = _cancel.withLock {
      let cancel = $0
      $0 = nil
      return cancel
    }
    cancel?()
  }

  /// Returns a Boolean value indicating whether two cancellable objects are equal.
  ///
  /// Two `AnyLifetimeCancellable` objects are considered equal if they are the same instance.
  public static func == (lhs: AnyLifetimeCancellable, rhs: AnyLifetimeCancellable) -> Bool {
    ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  /// Hashes the essential components of this cancellable by feeding them into the given hasher.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  deinit {
    let cancel = _cancel.withLock {
      let cancel = $0
      $0 = nil
      return cancel
    }
    cancel?()
  }
}

extension AnyLifetimeCancellable {
  /// Stores this cancellable in the specified collection.
  ///
  /// This method appends the cancellable to a collection for later batch cancellation
  /// or automatic cleanup when the collection is deallocated.
  ///
  /// - Parameter collection: A mutable collection to store the cancellable in.
  public func store<Cancellables: RangeReplaceableCollection>(
    in collection: inout Cancellables
  ) where Cancellables.Element == AnyLifetimeCancellable {
    collection.append(self)
  }

  /// Stores this cancellable in the specified set.
  ///
  /// This method inserts the cancellable into a set for later batch cancellation
  /// or automatic cleanup when the set is deallocated.
  ///
  /// - Parameter set: A mutable set to store the cancellable in.
  public func store(in set: inout Set<AnyLifetimeCancellable>) {
    set.insert(self)
  }
}
