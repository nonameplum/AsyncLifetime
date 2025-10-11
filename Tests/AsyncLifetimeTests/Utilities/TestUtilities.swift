import Foundation

// MARK: - Test Utilities

/// Thread-safe container for testing concurrent access
final class LockIsolated<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) {
    _value = value
  }

  var value: Value {
    lock.withLock { _value }
  }

  func withValue<Result>(_ operation: (inout Value) throws -> Result) rethrows -> Result {
    try lock.withLock {
      try operation(&_value)
    }
  }
}

// MARK: - Stub Stream Factories

/// Creates a stub stream that yields a fixed sequence of integers
func makeStubIntStream(values: [Int]) -> AsyncStream<Int> {
  AsyncStream<Int> { continuation in
    Task {
      for value in values {
        continuation.yield(value)
      }
      continuation.finish()
    }
  }
}

/// Creates a stub stream that yields integers from 1 to count
func makeStubIntStream(count: Int) -> AsyncStream<Int> {
  makeStubIntStream(values: Array(1...count))
}

/// Creates a stub stream that never yields any values
func makeEmptyStubIntStream() -> AsyncStream<Int> {
  AsyncStream<Int> { continuation in
    continuation.finish()
  }
}

/// Creates a stub stream that yields values then throws an error
func makeStubIntStream(values: [Int], thenError error: Error) -> AsyncThrowingStream<Int, Error> {
  AsyncThrowingStream<Int, Error> { continuation in
    Task {
      for value in values {
        continuation.yield(value)
      }
      continuation.finish(throwing: error)
    }
  }
}

// MARK: - Fake Stream Factories

/// Creates a fake stream that yields indefinitely with controlled interval
func makeFakeInfiniteIntStream(interval: Duration = .milliseconds(1)) -> AsyncStream<Int> {
  AsyncStream<Int> { continuation in
    Task {
      var counter = 1
      while !Task.isCancelled {
        continuation.yield(counter)
        counter += 1
        try? await Task.sleep(for: interval)
      }
      continuation.finish()
    }
  }
}

/// Creates a fake controllable stream for precise test control
func makeFakeControllableIntStream() -> (
  stream: AsyncStream<Int>,
  yield: @Sendable (Int) -> Void,
  finish: @Sendable () -> Void
) {
  let (stream, continuation) = AsyncStream<Int>.makeStream()

  return (
    stream: stream,
    yield: { value in continuation.yield(value) },
    finish: { continuation.finish() }
  )
}

// MARK: - IsolationCapturingSequence

// Custom async sequence that captures isolation when next() is called
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
struct IsolationCapturingSequence: AsyncSequence, Sendable {
  typealias Element = Int
  let values: [Int]
  let expectedIsolation: (any Actor)?
  let file: StaticString
  let line: UInt

  init(
    values: [Int],
    expectedIsolation: (any Actor)?,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.values = values
    self.expectedIsolation = expectedIsolation
    self.file = file
    self.line = line
  }

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(values: values, expectedIsolation: expectedIsolation, file: file, line: line)
  }

  struct AsyncIterator: AsyncIteratorProtocol {
    var values: [Int]
    var index = 0
    let expectedIsolation: (any Actor)?
    let file: StaticString
    let line: UInt

    mutating func next(isolation actor: isolated (any Actor)? = #isolation) async -> Int? {
      expectedIsolation?.assertIsolated(
        "Expected \(String(describing: expectedIsolation)), got \(String(describing: actor))",
        file: file,
        line: line
      )

      guard index < values.count else { return nil }
      let value = values[index]
      index += 1
      return value
    }
  }
}

// MARK: - Fake Test Objects

class FakeObserver {
  let processedValues = LockIsolated<[Int]>([])
  var processCount: Int { processedValues.value.count }

  func process(_ value: Int) {
    processedValues.withValue { $0.append(value) }
  }
}

#if swift(<6.2)
  extension FakeObserver: @unchecked Sendable {}
#endif

@TestGlobalActor
class FakeTestGlobalActorObserver {
  var processedValues: [Int] = []
  var processCount: Int { processedValues.count }

  func process(_ value: Int) {
    processedValues.append(value)
  }
}

@MainActor
class FakeMainActorObserver {
  var processedValues: [Int] = []

  func process(_ value: Int) {
    processedValues.append(value)
  }
}

// MARK: - Test Cancellables

@testable import AsyncLifetime

/// Reusable test cancellable with configurable behavior
struct CustomCancellable: LifetimeCancellable {
  let id: UUID
  let cancelClosure: @Sendable () -> Void

  init(id: UUID = UUID(), cancelClosure: @escaping @Sendable () -> Void = {}) {
    self.id = id
    self.cancelClosure = cancelClosure
  }

  func cancel() {
    cancelClosure()
  }

  static func == (lhs: CustomCancellable, rhs: CustomCancellable) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

// MARK: - Test Errors

enum TestError: Error, Equatable {
  case operationFailed
  case streamFailed
}
