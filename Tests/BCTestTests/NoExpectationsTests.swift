import Testing
@testable import BCTestExpectation
@testable import BCLoggable

nonisolated struct NoExpectationsTests: Loggable {
   @Test @BCTest func zeroExpectations() async throws {
      log()
   }
}
