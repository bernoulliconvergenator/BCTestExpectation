import Testing
import Observation
import Foundation
@testable import BCTestExpectation

/// Tests that catch `unAwaited`, `timedOut`, and `unsatisfied` errors.
@MainActor struct UnsatisfiedTests {

   // MARK: - neglect to satisfy

   @Test(
      .disabled("since no timeout on await on never satisfied expectation, test hits timeLimit and fails, as expected"),
      .timeLimit(.minutes(1))
   )
   @BCTest(.withKnownIssue)
   func awaitedButNeverSatisfiedWithoutAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation()
      // expectation.satisfy()
      try await awaitSatisfaction(of: expectation)
   }

   @Test("should catch error BCTestExpectation.SatisfyError.timedOut")
   @BCTest(.withKnownIssue)
   func awaitedButNeverSatisfiedWithAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation()
      // expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250)) // will timeout
   }

   // MARK: - neglect to await

   @Test("should catch error BCTestExpectation.SatisfyError.unAwaited")
   @BCTest(.withKnownIssue)
   func satisfiedButNeverAwaited() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()
      // try await awaitSatisfaction(of: expectation)
   }

   // MARK: - neglect to satisfy. neglect to await

   @Test("should catch error BCTestExpectation.SatisfyError.unAwaited")
   @BCTest(.withKnownIssue)
   func neverSatisfiedNorAwaited() async throws {
      let _ = try await expectationManager.expectation()
      // expectation.satisfy()
      // try await awaitSatisfaction(of: expectation)
   }

   // MARK: - satisfy after await completed

   @Test("should catch error BCTestExpectation.SatisfyError.timedOut")
   @BCTest(.withKnownIssue)
   func awaitedBeforeSatisfied() async throws {
      let expectation = try await expectationManager.expectation()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250)) // will timeout
      expectation.satisfy()
   }

   // MARK: - assert before await complete

   @Test("should catch error BCTestExpectation.SatisfyError.unAwaited")
   @BCTest(.withKnownIssue)
   func asynchronouslyAssertedBeforeAwaited() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()

      Task.detached {
         try await Task.sleep(for: .milliseconds(250))
         try await awaitSatisfaction(of: expectation)
      }
   }

   @Test("should catch error BCTestExpectation.SatisfyError.unAwaited")
   @BCTest(.withKnownIssue)
   func asynchronouslyAssertedWhileAwaiting() async throws {
      let expectation = try await expectationManager.expectation()

      // 0.00 async await
      // 0:00.2 assert
      // 0:00.4 async satisfy

      Task.detached {
         try await awaitSatisfaction(of: expectation)
      }

      let _ = Task.detached {
         try await Task.sleep(for: .milliseconds(400))
         expectation.satisfy()
      }

      try await Task.sleep(for: .milliseconds(200))
   }

   // MARK: - await cooperative cancellation

   @Test("should catch error BCTestExpectation.SatisfyError.unsatisfied")
   @BCTest(.withKnownIssue)
   @MainActor func awaitedButCooperativelyCanceled_neverSatisfied() async throws {
      let expectation = try await expectationManager.expectation()

      let awaitTask = Task.detached {
         try await awaitSatisfaction(of: expectation)
      }

      try await Task.sleep(for: .milliseconds(250))
      // expectation.satisfy()
      awaitTask.cancel()
   }

   @Test("should catch error BCTestExpectation.SatisfyError.unsatisfied")
   @BCTest(.withKnownIssue)
   @MainActor func awaitedButCooperativelyCanceled_satisfiedAfterCancel() async throws {
      let expectation = try await expectationManager.expectation()

      let awaitTask = Task.detached {
         try await awaitSatisfaction(of: expectation)
      }

      try await Task.sleep(for: .milliseconds(250))
      awaitTask.cancel()

      try await Task.sleep(for: .milliseconds(250))
      expectation.satisfy()
   }

   // MARK: - under satisfied

   @Test("should catch error BCTestExpectation.SatisfyError.timedOut")
   @BCTest(.withKnownIssue)
   @MainActor func awaitedButUnderSatisfiedWithAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 2)
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250)) // will timeout
   }
}
