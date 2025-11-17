import Testing
import Foundation

/// A provider and manager of instances of `BCTestExpectation`.
///
/// A `BCTestExpectation` can only be created by a `BCTestExpectationManager` and satisfaction of a `BCTestExpectation` can only
/// be asserted by invoking `assertExpectationsSatisfied()` on the manager that created it.
///
/// A `BCTestExpectationManager` and assertion of satisfaction of expectations it created are provided by the `@BCTest` macro.
public actor BCTestExpectationManager {
   private var expectations: Set<BCTestExpectation> = []
   private var didAssert = false

   // MARK: - init

   public init() {}

   // MARK: - new BCTestExpectation

   /// Create and manage a new `BCTestExpectation`. Only available before having called `assertExpectationsSatisfied()`. It is an
   /// error to create a new `BCTestExpectation` after asserting satisfaction of managed expectations.
   ///
   /// - Parameters:
   ///   - comment: Optional text that appears in test failures
   ///   - expectedCount: The number of times `satisfy()` must be called to pass verification
   ///   - issueForOverSatisfied: Whether or not to raise an `Issue` if `satisfy()` is called more than `expectedCount` times
   ///   - sourceLocation: Location in source to attribute issues
   public func expectation(
      _ comment: Comment? = nil,
      expectedCount: Int = 1,
      issueForOverSatisfied: Bool = true,
      sourceLocation: SourceLocation = #_sourceLocation
   ) throws -> BCTestExpectation {
      guard !didAssert else {
         throw Error.alreadyAsserted
      }

      let expectation = BCTestExpectation(
         comment: comment,
         expectedCount: expectedCount,
         issueForOverSatisfied: issueForOverSatisfied,
         sourceLocation: sourceLocation
      )
      expectations.insert(expectation)
      return expectation
   }

   // MARK: - assert expectations satisfied

   /// Assert satisfaction on all expectations created by this manager.
   public func assertExpectationsSatisfied() async {
      didAssert = true

      for expectation in expectations {
         await expectation.assertSatisfied()
      }
   }
}

// MARK: - error

nonisolated extension BCTestExpectationManager {
   public enum Error: Swift.Error, CustomStringConvertible {
      case alreadyAsserted

      public var description: String {
         switch self {
         case .alreadyAsserted: return "Cannot create new test expectations after asserting satisfaction"
         }
      }
   }
}
