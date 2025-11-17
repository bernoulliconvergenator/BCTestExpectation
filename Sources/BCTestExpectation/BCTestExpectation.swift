import Testing
import Foundation
@testable import BCLoggable

/// An expected outcome in an asynchronous Swift Testing `@Test`.
///
/// `BCTestExpectation` does not have a public `init`. Create a `BCTestExpectation` with a `BCTestExpectationManager` provided
/// by the `@BCTest` macro.
///
/// A `BCTestExpectation` must be both satisfied and its satisfaction awaited, else the Swift Testing `@Test` will fail.
///
/// Satisfaction requires invoking `satisfy()` `expectedCount` times. Await satisfaction by passing a `BCTestExpectation` to an
/// invocation of top level nonisolated async func `awaitSatisfaction(of:timeOut:)`.
public actor BCTestExpectation: Hashable, Loggable {
   public static let forever = Duration.seconds(Int64.max)
   public nonisolated let id = UUID()

   private let comment: Comment?
   private let expectedCount: Int
   private let issueForOverSatisfied: Bool
   private let sourceLocation: SourceLocation

   private var receivedCount: Int = 0
   private var continuation: AsyncStream<Void>.Continuation?

   private enum AwaitState { case notStarted, started, ended }
   private var awaitState = AwaitState.notStarted

   private var didSatisfy = false
   private var didTimeout = false

   // MARK: - init

   internal init(
      comment: Comment?,
      expectedCount: Int,
      issueForOverSatisfied: Bool,
      sourceLocation: SourceLocation
   ) {
      self.comment = comment
      self.expectedCount = max(expectedCount, 0)
      self.issueForOverSatisfied = issueForOverSatisfied
      self.sourceLocation = sourceLocation
   }

   // MARK: - satisfy

   /// Returns current state of satisfaction.
   public func isSatisfied() -> Bool {
      didSatisfy
   }

   /// Increments received count and if received count then equals expected count, marks as satisfied.
   ///
   /// `nonisolated` to avoid suspending caller's test which may require synchronous code to accurately test a flow.
   public nonisolated func satisfy() {
      Task { await _satisfy() }
   }

   private func _satisfy() {
      log("satisfied: \(comment ?? "")")
      receivedCount += 1
      guard receivedCount == expectedCount else { return }

      // Invariant: an expectation cannot be satisfied after await ends
      didSatisfy = awaitState != .ended

      continuation?.finish()
      continuation = nil
   }

   // MARK: - await satisfaction

   /// Await satisfaction -- if not yet awaited -- with optional timeout.
   ///
   /// Satisfaction can only be awaited once.
   ///
   /// If satisfaction has not yet been awaited, this method only returns on satisfaction or time out, whichever occurs first.
   ///
   /// If already satisfied, this method returns immediately.
   ///
   /// If satisfaction has already been awaited, throws `AwaitError.alreadyAwaited` whether or not satisfied.
   internal func awaitSatisfaction(timeout: Duration) async throws(AwaitError) {
      log("awaiting satisfaction of: \(comment ?? "")")

      guard expectedCount > 0 || timeout < Self.forever else {
         awaitState = .ended
         // Invariant: an expected count of 0 cannot wait forever
         let str = (comment?.rawValue ?? "<no description>") + ": satisfied \(receivedCount) times, expected \(expectedCount)"
         throw .foreverTimeoutFor0ExpectedCount(str, sourceLocation)
      }

      guard awaitState == .notStarted else {
         // Invariant: a test fails if satisfaction awaited more than once
         let str = (comment?.rawValue ?? "<no description>") + ": satisfied \(receivedCount) times, expected \(expectedCount)"
         throw .alreadyAwaited(str, sourceLocation)
      }

      awaitState = .started
      defer { awaitState = .ended }

      // return if already satisfied, else wait for satisfaction with optional timeout
      guard !didSatisfy else { return }

      let stream = AsyncStream<Void> { continuation = $0 }

      var timeoutTask: Task<Void, Error>?
      if timeout < Self.forever {
         timeoutTask = Task {
            try await Task.sleep(for: timeout)
            guard continuation != nil else { return }
            didTimeout = true
            continuation?.finish()
            continuation = nil
         }
      }

      // Invariant: wait for satisfaction can be canceled
      for await _ in stream {}

      timeoutTask?.cancel()
   }

   // MARK: - assert satisfaction

   /// Raise an `Issue` if not satisfied nor awaited.
   internal func assertSatisfied() {
      let stateStr = (comment?.rawValue ?? "<no description>") + ": satisfied \(receivedCount) times, expected \(expectedCount)"

      switch awaitState {
      case .notStarted:
         // Invariant: a test fails if satisfaction not awaited (wait for satisfaction required for test passing)
         Issue.record(SatisfyError.unAwaited, Comment(rawValue: stateStr), sourceLocation: sourceLocation)
      case .started:
         // Invariant: a test fails if wait for satisfaction is not ended when satisfaction asserted
         Issue.record(SatisfyError.unAwaited, Comment(rawValue: stateStr), sourceLocation: sourceLocation)
         continuation?.finish()
         continuation = nil
      case .ended:
         guard expectedCount > 0 else {
            // inverted expectations are expected to time out, and there is no short-circuiting if satisfy() was called
            if receivedCount > 0 {
               Issue.record(SatisfyError.unexpected, Comment(rawValue: stateStr), sourceLocation: sourceLocation)
            }
            return
         }

         guard !didTimeout else {
            // Invariant: a test fails if wait times out for expectation with expected count > 0
            Issue.record(SatisfyError.timedOut, Comment(rawValue: stateStr), sourceLocation: sourceLocation)
            return
         }

         guard didSatisfy else {
            // Invariant: a test fails if expectation with expected count > 0 not satisfied before wait for satisfaction ends
            Issue.record(SatisfyError.unsatisfied, Comment(rawValue: stateStr), sourceLocation: sourceLocation)
            return
         }

         if receivedCount > expectedCount && issueForOverSatisfied {
            // Invariant: a test can be configured to fail if satisfied more times than specified
            Issue.record(SatisfyError.overSatisfied, Comment(rawValue: stateStr), sourceLocation: sourceLocation)
         }
      }
   }

   // MARK: - error

   public enum AwaitError: Error, CustomStringConvertible, Sendable {
      case foreverTimeoutFor0ExpectedCount(String, SourceLocation)
      case alreadyAwaited(String, SourceLocation)

      public var description: String {
         switch self {
         case .foreverTimeoutFor0ExpectedCount: return "A BCTestExpectation with 0 expected count cannot wait forever"
         case .alreadyAwaited: return "BCTestExpectation satisfaction can only be awaited once"
         }
      }
   }

   internal enum SatisfyError: Error, CustomStringConvertible {
      case unAwaited
      case timedOut
      case unsatisfied
      case overSatisfied
      case unexpected
      case zeroExpectedCountZeroTimeout

      public var description: String {
         switch self {
         case .unAwaited: return "BCTestExpectation satisfaction must be awaited"
         case .timedOut: return "BCTestExpectation wait for satisfaction timed out"
         case .unsatisfied: return "BCTestExpectation is not satisfied"
         case .overSatisfied: return "BCTestExpectation is over satisfied"
         case .unexpected: return "Unexpected BCTestExpectation occurred"
         case .zeroExpectedCountZeroTimeout: return "BCTestExpectation with expected count of 0 has no timeout"
         }
      }
   }

   // MARK: - hashable

   public static func == (lhs: BCTestExpectation, rhs: BCTestExpectation) -> Bool {
      lhs.id == rhs.id
   }

   nonisolated public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
   }
}
