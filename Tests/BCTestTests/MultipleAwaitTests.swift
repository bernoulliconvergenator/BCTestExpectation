import Testing
import Foundation
@testable import BCTestExpectation

@MainActor struct MultipleAwaitTests {

   // MARK: - multiple await

   @Test("should catch error BCTestExpectation.AwaitError.alreadyAwaited")
   @BCTest func multipleAwait() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()

      try await awaitSatisfaction(of: expectation)

      await withKnownIssue {
         try await awaitSatisfaction(of: expectation) // !!
      }
   }

   // MARK: - multiple await in Task

   @Test @BCTest func concurrentMultipleAwait() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()

      Task {
         try await awaitSatisfaction(of: expectation)

         await withKnownIssue {
            try await awaitSatisfaction(of: expectation) // !!
         }
      }

      try await Task.sleep(for: .milliseconds(300)) // required since awaiting satisfaction  concurrently
      // crashes if no wait, "Fatal error: Internal inconsistency: No test reporter for test"
   }

   // MARK: - multiple await in detached Task

   @Test(
      "should catch error BCTestExpectation.AwaitError.alreadyAwaited",
      .disabled(
         "crashes: Fatal error: Internal inconsistency: Issue reporter is not a TestReporter for test nil and test case nil."
      )
   )
   @BCTest func parallelMultipleAwait() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()

      Task.detached {
         try await awaitSatisfaction(of: expectation)

         await withKnownIssue {
            try await awaitSatisfaction(of: expectation) // !!
         }
      }

      try await Task.sleep(for: .milliseconds(300)) // required since awaiting satisfaction concurrently
   }
}
