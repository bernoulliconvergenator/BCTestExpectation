import Testing
import Foundation
@testable import BCTestExpectation

@MainActor struct UnexpectedSatisfyTests {

   // MARK: - missing timeout

   @Test @BCTest func zeroExpectedCount_noTimeout() async throws {
      await withKnownIssue {
         let expectation = try await expectationManager.expectation(expectedCount: 0)
         try await awaitSatisfaction(of: expectation)
      }
   }

   @Test @BCTest func zeroExpectedCount_noTimeout_noIssueForOverSatisfaction() async throws {
      await withKnownIssue {
         let expectation = try await expectationManager.expectation(expectedCount: 0, issueForOverSatisfied: false)
         try await awaitSatisfaction(of: expectation)
      }
   }

   // MARK: - with timeout

   @Test @BCTest func zeroExpectedCount_yesTimeout() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 0)
      try await awaitSatisfaction(of: expectation, timeout: .seconds(1))
   }

   @Test @BCTest func zeroExpectedCount_yesTimeout_noIssueForOverSatisfaction() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 0, issueForOverSatisfied: false)
      try await awaitSatisfaction(of: expectation, timeout: .seconds(1))
   }

   // MARK: - unexpected call to satisfy()

   @Test
   @BCTest(.withKnownIssue)
   func zeroExpectedCount_yesTimeout_callsSatisfy() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 0)
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .seconds(1))
   }

   @Test
   @BCTest(.withKnownIssue)
   func zeroExpectedCount_yesTimeout_callsSatisfyMultipleTimes() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 0)
      expectation.satisfy()
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .seconds(1))
   }

   @Test
   @BCTest(.withKnownIssue)
   func zeroExpectedCount_yesTimeout_callsSatisfy_withIssueForOverSatisfaction() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 0, issueForOverSatisfied: true)
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .seconds(1))
   }

   @Test
   @BCTest(.withKnownIssue)
   func zeroExpectedCount_yesTimeout_callsSatisfyMultipleTimes_withIssueForOverSatisfaction() async throws {
      let expectation = try await expectationManager.expectation(expectedCount: 0, issueForOverSatisfied: true)
      expectation.satisfy()
      expectation.satisfy()
      expectation.satisfy()
      try await awaitSatisfaction(of: expectation, timeout: .seconds(1))
   }
}
