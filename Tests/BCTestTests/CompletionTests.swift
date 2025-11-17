import Testing
import Foundation
@testable import BCTestExpectation
@testable import TestSupport

@MainActor struct CompletionTests {
   /// Because non-escaping `onDeployed` callback of `deployJacks` is invoked before `deployJacks` returns, no timeout needed.
   @Test @BCTest func testDeployJacks() async throws {
      let mach5 = Mach5()
      let expectation = try await expectationManager.expectation()

      await mach5.deployJacks {
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: [expectation])
   }

   /// Even though escaping `onDeployed` callback of `deployDrone` is not guaranteed to be invoked before `deployDrone` returns,
   /// no timeout needed.
   @Test @BCTest func testDeployDrone() async throws {
      let mach5 = Mach5()
      let expectation = try await expectationManager.expectation()

      await mach5.deployDrone { _ in
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: [expectation])
   }

   /// Even though escaping `onDeployed` callback of `deployDrone` is not guaranteed to be invoked before `deployDrone` returns
   /// and so no timeout is needed, a timeout can be used to guarantee test does not run forever await satisfaction.
   @Test @BCTest func testDeployDrone_withSufficientTimeout() async throws {
      let mach5 = Mach5()
      let expectation = try await expectationManager.expectation()

      await mach5.deployDrone { _ in
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: [expectation], timeout: .seconds(10)) // Timeout is cancelled if satisfied
   }

   /// Even though escaping `onDeployed` callback of `deployDrone` is not guaranteed to be invoked before `deployDrone` returns
   /// and so no timeout is needed, a timeout can be used to guarantee test does not run forever await satisfaction -- BUT if
   /// the timeout is too short, it can cause the test to fail even though code executed correctly.
   @Test
   @BCTest(.withKnownIssue)
   func testDeployDrone_withInSufficientTimeout() async throws {
      let mach5 = Mach5()
      let expectation = try await expectationManager.expectation()

      await mach5.deployDrone { _ in
         expectation.satisfy()
      }

      try await awaitSatisfaction(of: [expectation], timeout: .seconds(1))
   }
}
