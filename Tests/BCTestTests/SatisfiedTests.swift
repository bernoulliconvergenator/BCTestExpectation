import Testing
import Foundation
@testable import BCTestExpectation

@MainActor struct SatisfiedTests {
   @Test @BCTest func satisfy() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func multipleSatisfy() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func satisfyWithAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250))
   }

   @BCTest @Test func multipleSatisfyWithAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250))
   }

   @Test @BCTest func satisfyInTask() async throws {
      let expectation = try await expectationManager.expectation()

      Task {
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func satisfyInDetachedTask() async throws {
      let expectation = try await expectationManager.expectation()

      Task.detached {
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func multiplySatisfyInTask() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)

      Task {
         expectation.satisfy()
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func multiplySatisfyOnceInTask() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)

      Task {
         expectation.satisfy()
      }
      expectation.satisfy()

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func multiplySatisfyInDetachedTask() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)

      Task.detached {
         expectation.satisfy()
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func multiplySatisfyOnceInDetachedTask() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)

      Task.detached {
         expectation.satisfy()
      }
      expectation.satisfy()

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func satisfyInTaskBeforeAwaiting() async throws {
      let expectation = try await expectationManager.expectation()

      Task {
         expectation.satisfy()
      }

      try await Task.sleep(for: .milliseconds(200))
      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func satisfyInDetachedTaskBeforeAwaiting() async throws {
      let expectation = try await expectationManager.expectation()

      Task.detached {
         expectation.satisfy()
      }

      try await Task.sleep(for: .milliseconds(200))
      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func satisfyInTaskWhileAwaiting() async throws {
      let expectation = try await expectationManager.expectation()

      Task {
         try await Task.sleep(for: .milliseconds(100))
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func satisfyInDetachedTaskWhileAwaiting() async throws {
      let expectation = try await expectationManager.expectation()

      Task.detached {
         try await Task.sleep(for: .milliseconds(100))
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }
}
