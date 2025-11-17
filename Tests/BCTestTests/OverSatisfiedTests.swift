import Testing
import Foundation
@testable import BCTestExpectation

@MainActor struct OverSatisfiedTests {

   // MARK: - over satisfy

   @Test("should catch error BCTestExpectation.SatisfyError.overSatisfied")
   @BCTest(.withKnownIssue)
   func overSatisfyWithoutAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation)
   }

   @Test("should catch error BCTestExpectation.SatisfyError.overSatisfied")
   @BCTest(.withKnownIssue)
   func overSatisfyWithAwaitTimeout() async throws {
      let expectation = try await expectationManager.expectation()
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250))
   }

   // MARK: - in Task over satisfy

   /// Because actor isolated, both calls to `satisfy()` in `Task` execute before `awaitSatisfaction(timeout:)`'s `for await`
   /// loop exits, and so over satisfaction detected.
   @Test("should catch error BCTestExpectation.SatisfyError.overSatisfied")
   @BCTest(.withKnownIssue)
   func overSatisfy_inTask() async throws {
      let expectation = try await expectationManager.expectation()

      Task {
         expectation.satisfy()
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   // MARK: - in detached Task over satisfy

   /// Calls to `satisfy()` in `Task.detached` are not actor isolated, so it is a race with outcome determined by the scheduler
   /// whether first call to `satisfy()` (that invokes `finish()` on the `AsyncStream`'s `Continuation`) causes the `for await`
   /// loop in `awaitSatisfaction(timeout:)` to exit or not.
   @Test("should catch error BCTestExpectation.SatisfyError.overSatisfied")
   @BCTest(.withKnownIssue)
   func overSatisfy_inDetachedTask() async throws {
      let expectation = try await expectationManager.expectation()

      Task.detached {
         expectation.satisfy()
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   // MARK: - pause before over satisfy

   // In both cases, the suspension at Task.sleep before over satisfaction cause over satisfaction to be missed because the wait
   // for satisfaction is allowed to end

   @Test("suspension in Task means this does not catch error BCTestExpectation.SatisfyError.overSatisfied")
   @BCTest()
   func overSatisfy_inTask_withPauseBeforeOverSatisfy() async throws {
      let expectation = try await expectationManager.expectation()

      Task {
         expectation.satisfy()
         try await Task.sleep(for: .milliseconds(100))
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test("suspension in Task.detached means this does not catch error BCTestExpectation.SatisfyError.overSatisfied")
   @BCTest()
   func overSatisfy_inDetachedTask_withPauseBeforeOverSatisfy() async throws {
      let expectation = try await expectationManager.expectation()

      Task.detached {
         expectation.satisfy()
         // because of this pause, awaitSatisfaction(of:) will have completed and not detect second satisfaction
         try await Task.sleep(for: .milliseconds(100))
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   // MARK: - no issue for over satisfy

   @Test @BCTest func overSatisfyWithoutAwaitTimeout_overSatisfyOK() async throws {
      let expectation = try await expectationManager.expectation(issueForOverSatisfied: false)
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func overSatisfyWithAwaitTimeout_overSatisfyOK() async throws {
      let expectation = try await expectationManager.expectation(issueForOverSatisfied: false)
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250))
   }

   @Test @BCTest func overSatisfyInTask_overSatisfyOK() async throws {
      let expectation = try await expectationManager.expectation(issueForOverSatisfied: false)

      Task {
         expectation.satisfy()
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }

   @Test @BCTest func overSatisfyInDetachedTask_overSatisfyOK() async throws {
      let expectation = try await expectationManager.expectation(issueForOverSatisfied: false)

      Task.detached {
         expectation.satisfy()
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: expectation)
   }
}
