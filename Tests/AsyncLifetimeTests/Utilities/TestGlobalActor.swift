import Dispatch

private struct TestGlobalActorDispatchQueueKey: Sendable, Hashable {
  static let shared = TestGlobalActorDispatchQueueKey()
  static let key = DispatchSpecificKey<Self>()
  private init() {}
}

@available(iOS 13.0, *)
@globalActor
public actor TestGlobalActor {
  /// The shared actor instance.
  public static let shared = TestGlobalActor()

  /// The underlying dispatch queue that runs the actor Jobs.
  nonisolated let dispatchQueue: DispatchSerialQueue

  /// The underlying unowned serial executor.
  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    dispatchQueue.asUnownedSerialExecutor()
  }

  nonisolated var isSync: Bool {
    DispatchQueue.getSpecific(key: TestGlobalActorDispatchQueueKey.key)
      == TestGlobalActorDispatchQueueKey.shared
  }

  private init() {
    let dispatchQueue = DispatchQueue(label: "com.plum.test.actor.queue", qos: .userInitiated)
    guard let serialQueue = dispatchQueue as? DispatchSerialQueue else {
      preconditionFailure("Dispatch queue \(dispatchQueue.label) was not initialized to be serial!")
    }

    serialQueue.setSpecific(
      key: TestGlobalActorDispatchQueueKey.key,
      value: TestGlobalActorDispatchQueueKey.shared
    )

    self.dispatchQueue = serialQueue
  }

  static func assumeIsolated<T: Sendable>(
    _ operation: @TestGlobalActor () throws -> T
  ) rethrows -> T {
    typealias YesActor = @TestGlobalActor () throws -> T
    typealias NoActor = () throws -> T

    shared.preconditionIsolated()

    // To do the unsafe cast, we have to pretend it's @escaping.
    return try withoutActuallyEscaping(operation) {
      (_ fn: @escaping YesActor) throws -> T in
      let rawFn = unsafeBitCast(fn, to: NoActor.self)
      return try rawFn()
    }
  }
}
