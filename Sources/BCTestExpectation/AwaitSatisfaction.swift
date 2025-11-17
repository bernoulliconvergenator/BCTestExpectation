import Testing
import Foundation

/// Wait on an expectation to be satisfied with an optional timeout.
///
/// - Parameters:
///   - of: a `BCTestExpectation` to wait on.
///   - timeout: optional duration to wait for satisfaction.
///
/// Does not return until `expectation` is satisfied or until timeout, if any, elapses.
///
/// Since using Approachable Concurrency, this nonisolated async function inherits isolation, if any.
nonisolated public func awaitSatisfaction(
   of expectation: BCTestExpectation,
   timeout: Duration = BCTestExpectation.forever
) async throws {
   try await awaitSatisfaction(of: [expectation], timeout: timeout)
}

/// Wait on a set of expectations to be satisfied with an optional timeout.
///
/// - Parameters:
///   - expectations: the `BCTestExpectation`s to wait on.
///   - timeout: optional duration to wait for satisfaction of each expectation.
///
/// Does not return until all expectations are satisfied or until timeout, if any, elapses.
///
/// Since using Approachable Concurrency, this nonisolated async function inherits isolation, if any.
nonisolated public func awaitSatisfaction(
   of expectations: Set<BCTestExpectation>,
   timeout: Duration = BCTestExpectation.forever
) async throws {
   do {
      try await withThrowingTaskGroup(of: Void.self) { group in
         for expectation in expectations {
            let addedTask = group.addTaskUnlessCancelled {
               try await expectation.awaitSatisfaction(timeout: timeout)
            }
            if !addedTask { break }
         }

         // It is considered programmer error to await satisfaction of a BCTestExpectation more than once, so BCTestExpectation
         // awaitSatisfaction(timeout:) throws BCTestExpectation.AwaitError.alreadyAwaited if the BCTestExpectation has already
         // been awaited.
         // To catch this error and abort the test, we for try await all child tasks. If the error is thrown, the already awaited
         // BCTestExpectation reports 2 errors: already having been awaited and unsatisfied. Also, the thrown error ends the for
         // try await loop, causing all other child tasks to be cancelled. Fortunately, awaitSatisfaction(timeout:) cooperatively
         // cancels.
         for try await _ in group {}
      }
   } catch {
      if case BCTestExpectation.AwaitError.alreadyAwaited(let str, let sourceLocation) = error {
         Issue.record(error, Comment(rawValue: str), sourceLocation: sourceLocation)
      } else if case BCTestExpectation.AwaitError.foreverTimeoutFor0ExpectedCount(let str, let sourceLocation) = error {
         Issue.record(error, Comment(rawValue: str), sourceLocation: sourceLocation)
      } else {
         throw error
      }
   }
}

