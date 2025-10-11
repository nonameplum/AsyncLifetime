import Foundation
import Testing

@testable import AsyncLifetime

@Suite("LifetimeCancellable")
struct LifetimeCancellableTests {

  // MARK: - Initialization Tests

  @Test("Initialize with closure stores and executes closure")
  func initialize_with_closure() {
    let wasCancelled = LockIsolated(false)

    let cancellable = AnyLifetimeCancellable {
      wasCancelled.withValue { $0 = true }
    }

    #expect(wasCancelled.value == false, "Closure should not execute on init")

    cancellable.cancel()

    #expect(wasCancelled.value == true, "Closure should execute on cancel")
  }

  @Test("Initialize with another cancellable wraps correctly")
  func initialize_with_cancellable() {
    let wasCancelled = LockIsolated(false)

    let innerCancellable = AnyLifetimeCancellable {
      wasCancelled.withValue { $0 = true }
    }

    let outerCancellable = AnyLifetimeCancellable(innerCancellable)

    outerCancellable.cancel()

    #expect(wasCancelled.value == true, "Wrapped cancellable should execute")
  }

  @Test("Initialize with nested cancellables creates chain")
  func initialize_with_nested_cancellables() {
    let cancelCount = LockIsolated(0)

    let innerCancellable = AnyLifetimeCancellable {
      cancelCount.withValue { $0 += 1 }
    }

    let middleCancellable = AnyLifetimeCancellable(innerCancellable)
    let outerCancellable = AnyLifetimeCancellable(middleCancellable)

    outerCancellable.cancel()

    #expect(cancelCount.value == 1, "Only innermost closure executes")
  }

  // MARK: - Cancellation Tests

  @Test("cancel executes stored closure")
  func cancel_executes_closure() {
    let value = LockIsolated(0)

    let cancellable = AnyLifetimeCancellable {
      value.withValue { $0 = 42 }
    }

    cancellable.cancel()

    #expect(value.value == 42)
  }

  @Test("cancel is idempotent")
  func cancel_is_idempotent() {
    let callCount = LockIsolated(0)

    let cancellable = AnyLifetimeCancellable {
      callCount.withValue { $0 += 1 }
    }

    cancellable.cancel()
    cancellable.cancel()
    cancellable.cancel()

    #expect(callCount.value == 1, "Closure executes exactly once")
  }

  // MARK: - Automatic Cleanup Tests

  @Test("deinit cancels automatically")
  func deinit_cancels_automatically() {
    let wasCancelled = LockIsolated(false)

    do {
      let cancellable = AnyLifetimeCancellable {
        wasCancelled.withValue { $0 = true }
      }
      _ = cancellable
    }

    #expect(wasCancelled.value == true, "deinit should cancel")
  }

  @Test("deinit on uncancelled object executes closure")
  func deinit_uncancelled_executes_closure() {
    let executionOrder = LockIsolated<[String]>([])

    do {
      let cancellable = AnyLifetimeCancellable {
        executionOrder.withValue { $0.append("cancelled") }
      }
      _ = cancellable
      executionOrder.withValue { $0.append("before-deinit") }
    }

    #expect(executionOrder.value == ["before-deinit", "cancelled"])
  }

  @Test("deinit on already cancelled is safe")
  func deinit_already_cancelled_is_safe() {
    do {
      let cancellable = AnyLifetimeCancellable {}
      cancellable.cancel()
    }

    // Should not crash
  }

  @Test("deinit executes closure exactly once even if previously cancelled")
  func deinit_after_cancel_no_double_execution() {
    let callCount = LockIsolated(0)

    do {
      let cancellable = AnyLifetimeCancellable {
        callCount.withValue { $0 += 1 }
      }
      cancellable.cancel()
    }

    #expect(callCount.value == 1, "Closure executes once total")
  }

  // MARK: - Thread Safety Tests

  @Test("Concurrent cancel calls are thread safe")
  func concurrent_cancel_is_thread_safe() async {
    let callCount = LockIsolated(0)

    let cancellable = AnyLifetimeCancellable {
      callCount.withValue { $0 += 1 }
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<100 {
        group.addTask {
          cancellable.cancel()
        }
      }
    }

    #expect(callCount.value == 1, "Closure executes exactly once despite concurrent calls")
  }

  @Test("Concurrent cancel and deinit are safe")
  func concurrent_cancel_and_deinit_are_safe() async {
    let callCount = LockIsolated(0)

    let cancellable = LockIsolated<AnyLifetimeCancellable?>(
      AnyLifetimeCancellable {
        callCount.withValue { $0 += 1 }
      }
    )

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<50 {
        group.addTask {
          cancellable.withValue { $0?.cancel() }
        }
      }

      group.addTask {
        cancellable.withValue { $0 = nil }
      }
    }

    #expect(callCount.value == 1, "Closure executes exactly once")
  }

  @Test("Multiple threads calling cancel simultaneously")
  func multiple_threads_cancel_simultaneously() async {
    let results = LockIsolated<[Int]>([])

    let cancellable = AnyLifetimeCancellable {
      results.withValue { $0.append(1) }
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<1000 {
        group.addTask {
          cancellable.cancel()
        }
      }
    }

    #expect(results.value.count == 1, "Single execution despite 1000 concurrent attempts")
  }

  // MARK: - Hashable Tests

  @Test("Equality based on object identity")
  func equality_based_on_identity() {
    let cancellable1 = AnyLifetimeCancellable {}
    let cancellable2 = AnyLifetimeCancellable {}

    #expect(cancellable1 == cancellable1, "Same instance equals itself")
    #expect(cancellable1 != cancellable2, "Different instances not equal")
  }

  @Test("Different instances are not equal")
  func different_instances_not_equal() {
    let cancellable1 = AnyLifetimeCancellable { print("a") }
    let cancellable2 = AnyLifetimeCancellable { print("a") }

    #expect(cancellable1 != cancellable2, "Even with identical closures")
  }

  @Test("Same instance is equal to itself")
  func same_instance_equals_itself() {
    let cancellable = AnyLifetimeCancellable {}

    #expect(cancellable == cancellable)
  }

  @Test("Hash values are consistent")
  func hash_values_consistent() {
    let cancellable = AnyLifetimeCancellable {}

    let hash1 = cancellable.hashValue
    let hash2 = cancellable.hashValue

    #expect(hash1 == hash2, "Hash should be consistent")
  }

  @Test("Can be stored in Set")
  func can_be_stored_in_set() {
    let cancellable1 = AnyLifetimeCancellable {}
    let cancellable2 = AnyLifetimeCancellable {}

    var set = Set<AnyLifetimeCancellable>()
    set.insert(cancellable1)
    set.insert(cancellable2)

    #expect(set.count == 2)
    #expect(set.contains(cancellable1))
    #expect(set.contains(cancellable2))
  }

  @Test("Can be used as Dictionary key")
  func can_be_used_as_dictionary_key() {
    let cancellable1 = AnyLifetimeCancellable {}
    let cancellable2 = AnyLifetimeCancellable {}

    var dict = [AnyLifetimeCancellable: String]()
    dict[cancellable1] = "first"
    dict[cancellable2] = "second"

    #expect(dict[cancellable1] == "first")
    #expect(dict[cancellable2] == "second")
    #expect(dict.count == 2)
  }

  @Test("Same instance in Set appears once")
  func same_instance_in_set_once() {
    let cancellable = AnyLifetimeCancellable {}

    var set = Set<AnyLifetimeCancellable>()
    set.insert(cancellable)
    set.insert(cancellable)
    set.insert(cancellable)

    #expect(set.count == 1)
  }

  // MARK: - Set Storage Tests

  @Test("store in Set adds cancellable")
  func store_in_set_adds_cancellable() {
    var cancellables = Set<AnyLifetimeCancellable>()

    let cancellable = AnyLifetimeCancellable {}
    cancellable.store(in: &cancellables)

    #expect(cancellables.count == 1)
    #expect(cancellables.contains(cancellable))
  }

  @Test("Multiple cancellables in same Set")
  func multiple_cancellables_in_set() {
    var cancellables = Set<AnyLifetimeCancellable>()

    let cancellable1 = AnyLifetimeCancellable {}
    let cancellable2 = AnyLifetimeCancellable {}
    let cancellable3 = AnyLifetimeCancellable {}

    cancellable1.store(in: &cancellables)
    cancellable2.store(in: &cancellables)
    cancellable3.store(in: &cancellables)

    #expect(cancellables.count == 3)
  }

  @Test("Set deallocation cancels all stored cancellables")
  func set_deallocation_cancels_all() {
    let cancelledCount = LockIsolated(0)

    do {
      var cancellables = Set<AnyLifetimeCancellable>()

      for _ in 0..<5 {
        AnyLifetimeCancellable {
          cancelledCount.withValue { $0 += 1 }
        }.store(in: &cancellables)
      }

      #expect(cancellables.count == 5)
      #expect(cancelledCount.value == 0, "Not cancelled yet")
    }

    #expect(cancelledCount.value == 5, "All cancelled on Set deallocation")
  }

  @Test("Removing from Set does not cancel")
  func removing_from_set_does_not_cancel() {
    let wasCancelled = LockIsolated(false)

    var cancellables = Set<AnyLifetimeCancellable>()

    let cancellable = AnyLifetimeCancellable {
      wasCancelled.withValue { $0 = true }
    }
    cancellable.store(in: &cancellables)

    cancellables.remove(cancellable)

    #expect(wasCancelled.value == false, "Removal does not trigger cancel")
  }

  @Test("Stored cancellables maintain identity")
  func stored_cancellables_maintain_identity() {
    var cancellables = Set<AnyLifetimeCancellable>()

    let cancellable = AnyLifetimeCancellable {}
    cancellable.store(in: &cancellables)

    #expect(cancellables.first == cancellable)
  }

  @Test("Clearing Set cancels all cancellables")
  func clearing_set_cancels_all() {
    let cancelledCount = LockIsolated(0)

    var cancellables = Set<AnyLifetimeCancellable>()

    for _ in 0..<3 {
      AnyLifetimeCancellable {
        cancelledCount.withValue { $0 += 1 }
      }.store(in: &cancellables)
    }

    cancellables.removeAll()

    #expect(cancelledCount.value == 3, "All cancelled when cleared from Set")
  }

  @Test("Reassigning Set to empty cancels all previous cancellables")
  func reassigning_set_to_empty_cancels_all() {
    let cancelledCount = LockIsolated(0)

    var cancellables = Set<AnyLifetimeCancellable>()

    for _ in 0..<5 {
      AnyLifetimeCancellable {
        cancelledCount.withValue { $0 += 1 }
      }.store(in: &cancellables)
    }

    #expect(cancellables.count == 5)
    #expect(cancelledCount.value == 0, "Not cancelled yet")

    cancellables = Set<AnyLifetimeCancellable>()

    #expect(cancelledCount.value == 5, "All cancelled when Set reassigned")
    #expect(cancellables.count == 0, "New Set is empty")
  }

  @Test("Reassigning Set to new Set cancels previous cancellables")
  func reassigning_set_to_new_set_cancels_previous() {
    let oldCancelledCount = LockIsolated(0)
    let newCancelledCount = LockIsolated(0)

    var cancellables = Set<AnyLifetimeCancellable>()

    for _ in 0..<3 {
      AnyLifetimeCancellable {
        oldCancelledCount.withValue { $0 += 1 }
      }.store(in: &cancellables)
    }

    var newCancellables = Set<AnyLifetimeCancellable>()
    for _ in 0..<2 {
      AnyLifetimeCancellable {
        newCancelledCount.withValue { $0 += 1 }
      }.store(in: &newCancellables)
    }

    #expect(oldCancelledCount.value == 0, "Old not cancelled yet")
    #expect(newCancelledCount.value == 0, "New not cancelled yet")

    cancellables = newCancellables

    #expect(oldCancelledCount.value == 3, "Old Set cancellables cancelled")
    #expect(newCancelledCount.value == 0, "New Set cancellables still active")
    #expect(cancellables.count == 2)
  }

  // MARK: - Array Storage Tests

  @Test("store in Array appends cancellable")
  func store_in_array_appends() {
    var cancellables: [AnyLifetimeCancellable] = []

    let cancellable = AnyLifetimeCancellable {}
    cancellable.store(in: &cancellables)

    #expect(cancellables.count == 1)
    #expect(cancellables[0] == cancellable)
  }

  @Test("Multiple cancellables in same Array")
  func multiple_cancellables_in_array() {
    var cancellables: [AnyLifetimeCancellable] = []

    let cancellable1 = AnyLifetimeCancellable {}
    let cancellable2 = AnyLifetimeCancellable {}
    let cancellable3 = AnyLifetimeCancellable {}

    cancellable1.store(in: &cancellables)
    cancellable2.store(in: &cancellables)
    cancellable3.store(in: &cancellables)

    #expect(cancellables.count == 3)
  }

  @Test("Array deallocation cancels all stored cancellables")
  func array_deallocation_cancels_all() {
    let cancelledCount = LockIsolated(0)

    do {
      var cancellables: [AnyLifetimeCancellable] = []

      for _ in 0..<5 {
        AnyLifetimeCancellable {
          cancelledCount.withValue { $0 += 1 }
        }.store(in: &cancellables)
      }

      #expect(cancellables.count == 5)
      #expect(cancelledCount.value == 0, "Not cancelled yet")
    }

    #expect(cancelledCount.value == 5, "All cancelled on Array deallocation")
  }

  @Test("Order is preserved in Array")
  func order_preserved_in_array() {
    var cancellables: [AnyLifetimeCancellable] = []

    let cancellable1 = AnyLifetimeCancellable {}
    let cancellable2 = AnyLifetimeCancellable {}
    let cancellable3 = AnyLifetimeCancellable {}

    cancellable1.store(in: &cancellables)
    cancellable2.store(in: &cancellables)
    cancellable3.store(in: &cancellables)

    #expect(cancellables[0] == cancellable1)
    #expect(cancellables[1] == cancellable2)
    #expect(cancellables[2] == cancellable3)
  }

  @Test("Duplicates allowed in Array")
  func duplicates_allowed_in_array() {
    var cancellables: [AnyLifetimeCancellable] = []

    let cancellable = AnyLifetimeCancellable {}

    cancellable.store(in: &cancellables)
    cancellable.store(in: &cancellables)
    cancellable.store(in: &cancellables)

    #expect(cancellables.count == 3)
  }

  // MARK: - Protocol Extension Tests

  @Test("Protocol extension store in Set works")
  func protocol_extension_store_in_set() {
    let wasCancelled = LockIsolated(false)

    do {
      var cancellables = Set<AnyLifetimeCancellable>()

      let customCancellable = CustomCancellable {
        wasCancelled.withValue { $0 = true }
      }

      customCancellable.store(in: &cancellables)

      #expect(cancellables.count == 1)
    }

    #expect(wasCancelled.value == true, "Custom cancellable stored and cancelled")
  }

  @Test("Protocol extension store in Collection works")
  func protocol_extension_store_in_collection() {
    let wasCancelled = LockIsolated(false)

    do {
      var cancellables: [AnyLifetimeCancellable] = []

      let customCancellable = CustomCancellable {
        wasCancelled.withValue { $0 = true }
      }

      customCancellable.store(in: &cancellables)

      #expect(cancellables.count == 1)
    }

    #expect(wasCancelled.value == true, "Custom cancellable stored and cancelled")
  }

  @Test("Type erases to AnyLifetimeCancellable")
  func type_erases_correctly() {
    var cancellables = Set<AnyLifetimeCancellable>()

    let customCancellable = CustomCancellable()
    customCancellable.store(in: &cancellables)

    #expect(cancellables.count == 1)
    #expect(cancellables.first != nil)
  }

  // MARK: - Integration Tests

  @Test("Batch cancellation via forEach")
  func batch_cancellation_foreach() {
    let cancelledCount = LockIsolated(0)

    var cancellables = Set<AnyLifetimeCancellable>()

    for _ in 0..<10 {
      AnyLifetimeCancellable {
        cancelledCount.withValue { $0 += 1 }
      }.store(in: &cancellables)
    }

    cancellables.forEach { $0.cancel() }

    #expect(cancelledCount.value == 10, "All cancellables cancelled")
  }

  @Test("Selective cancellation removes from Set")
  func selective_cancellation() {
    let cancelled1 = LockIsolated(false)
    let cancelled2 = LockIsolated(false)

    var cancellables = Set<AnyLifetimeCancellable>()

    do {
      let cancellable1 = AnyLifetimeCancellable {
        cancelled1.withValue { $0 = true }
      }
      let cancellable2 = AnyLifetimeCancellable {
        cancelled2.withValue { $0 = true }
      }

      cancellable1.store(in: &cancellables)
      cancellable2.store(in: &cancellables)

      #expect(cancellables.count == 2)

      cancellables.remove(cancellable1)

      #expect(cancellables.count == 1)
    }

    #expect(cancelled1.value == true, "Removed cancellable cancelled on deallocation")
    #expect(cancelled2.value == false, "Remaining cancellable not cancelled yet")
  }

  @Test("Nested cancellables parent cancels children")
  func nested_cancellables_cancel_chain() {
    let childCancelled = LockIsolated(false)
    let parentCancelled = LockIsolated(false)

    let childCancellable = AnyLifetimeCancellable {
      childCancelled.withValue { $0 = true }
    }

    let parentCancellable = AnyLifetimeCancellable {
      childCancellable.cancel()
      parentCancelled.withValue { $0 = true }
    }

    parentCancellable.cancel()

    #expect(parentCancelled.value == true)
    #expect(childCancelled.value == true, "Child cancelled via parent")
  }

  @Test("Cancellable from closure called once despite multiple cancel")
  func closure_called_once_multiple_cancel() {
    let executionLog = LockIsolated<[String]>([])

    let cancellable = AnyLifetimeCancellable {
      executionLog.withValue { $0.append("executed") }
    }

    cancellable.cancel()
    executionLog.withValue { $0.append("after-first") }

    cancellable.cancel()
    executionLog.withValue { $0.append("after-second") }

    cancellable.cancel()
    executionLog.withValue { $0.append("after-third") }

    #expect(executionLog.value == ["executed", "after-first", "after-second", "after-third"])
  }

  @Test("Empty Set storage and deallocation")
  func empty_set_storage() {
    do {
      let cancellables = Set<AnyLifetimeCancellable>()
      _ = cancellables
    }

    // Should not crash
  }

  @Test("Store same cancellable in multiple collections")
  func store_in_multiple_collections() {
    let callCount = LockIsolated(0)

    let cancellable = AnyLifetimeCancellable {
      callCount.withValue { $0 += 1 }
    }

    var set1 = Set<AnyLifetimeCancellable>()
    var set2 = Set<AnyLifetimeCancellable>()
    var array = [AnyLifetimeCancellable]()

    cancellable.store(in: &set1)
    cancellable.store(in: &set2)
    cancellable.store(in: &array)

    #expect(set1.count == 1)
    #expect(set2.count == 1)
    #expect(array.count == 1)

    cancellable.cancel()

    #expect(callCount.value == 1, "Cancelled once despite multiple storage")
  }

  // MARK: - Store Reuse Tests

  @Test("AnyLifetimeCancellable store reuses same instance in Set")
  func any_lifetime_cancellable_store_reuses_instance_in_set() {
    let cancelCount = LockIsolated(0)

    let cancellable = AnyLifetimeCancellable {
      cancelCount.withValue { $0 += 1 }
    }

    var set = Set<AnyLifetimeCancellable>()

    // Store the same AnyLifetimeCancellable twice
    cancellable.store(in: &set)
    cancellable.store(in: &set)

    // Fixed: Same instance is reused, Set deduplicates
    #expect(set.count == 1, "Same wrapper instance stored, Set deduplicates")

    // Cancel all wrappers - should only cancel once
    set.forEach { $0.cancel() }

    #expect(cancelCount.value == 1, "Single cancellation occurs")
  }

  @Test("AnyLifetimeCancellable store reuses same instance in Array")
  func any_lifetime_cancellable_store_reuses_instance_in_array() {
    let cancellable = AnyLifetimeCancellable {}

    var array: [AnyLifetimeCancellable] = []

    // Store the same AnyLifetimeCancellable twice
    cancellable.store(in: &array)
    cancellable.store(in: &array)

    #expect(array.count == 2, "Both store() calls append to array")

    // Fixed: Same wrapper instance is stored both times
    #expect(array[0] == array[1], "Same wrapper instance in both positions")
    #expect(array[0] == cancellable, "Stored instance matches original")
  }
}
