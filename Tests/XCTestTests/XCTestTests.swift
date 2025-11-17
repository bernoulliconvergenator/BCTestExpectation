import XCTest
import Foundation

nonisolated class XCTestTests: XCTestCase {
   // MARK: - fulfilled

   func testFulfill() {
      let e = self.expectation(description: "fulfill")
      e.fulfill()
      wait(for: [e])
   }

   // This test fails.
   func testFailToFulfill() {
      let e = self.expectation(description: "fulfill")
      wait(for: [e], timeout: 0.5)
   }

   // MARK: - inverted

   // Verify an inverted XCTestExpectation requires timeout else test waits forever for unfulfilled expectation

   // **************************
   // !! This test never ends !!
   // **************************
   func testInvertedFulfill_noTimeout_NEVER_ENDS() {
      let e = self.expectation(description: "inverted fulfill no timeout")
      e.isInverted = true
      wait(for: [e])
   }

   func testInvertedFulfill_yesTimeout() {
      let e = self.expectation(description: "inverted fulfill yes timeout")
      e.isInverted = true
      wait(for: [e], timeout: 1.0)
   }

   // MARK: - over satisfied

   // This test fails.
   func testOverSatisfy() {
      let e = self.expectation(description: "expectation")
      e.expectedFulfillmentCount = 1
      e.fulfill()
      e.fulfill()
      wait(for: [e])
   }

   // This test contains a race, but to date, has never failed. It does not detect over satisfaction.
   func testOverSatisfy_inTask() {
      let e = self.expectation(description: "expectation")
      e.expectedFulfillmentCount = 1
      Task {
         e.fulfill()
         e.fulfill()
      }
      wait(for: [e])
   }

   // This test contains a race, and to date, has always failed. It detects over satisfaction.
   func testOverSatisfy_inDetachedTask() {
      let e = self.expectation(description: "expectation")
      Task.detached {
         e.fulfill()
         e.fulfill()
      }
      wait(for: [e])
   }
}
