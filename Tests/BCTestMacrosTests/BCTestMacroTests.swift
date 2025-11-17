import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

#if canImport(BCTestMacros)
import BCTestMacros

nonisolated let testMacros: [String: Macro.Type] = ["BCTest": BCTestMacro.self]
#endif

nonisolated final class BCTestMacroTests: XCTestCase {

   // MARK: - legal invocations

   func testEmptyBody() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest func test() async {}
         """,
         expandedSource:
         """
         @Test func test() async {
             let expectationManager = BCTestExpectationManager()
             await expectationManager.assertExpectationsSatisfied()
         }
         """,
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   func testEmptyBody_withNoIssueArg() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest(.noIssue) func test() async {}
         """,
         expandedSource:
         """
         @Test func test() async {
             let expectationManager = BCTestExpectationManager()
             await expectationManager.assertExpectationsSatisfied()
         }
         """,
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   func testOneStatementBody() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest func test() async {
            log()
         }
         """,
         expandedSource:
         """
         @Test func test() async {
             let expectationManager = BCTestExpectationManager()
             log()
             await expectationManager.assertExpectationsSatisfied()
         }
         """,
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   func testOneLinerBody() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         #"""
         @Test @BCTest func test() async { for idx in 0...2 { log("\(idx)") } }
         """#,
         expandedSource:
         #"""
         @Test func test() async {
             let expectationManager = BCTestExpectationManager()
             for idx in 0 ... 2 {
                 log("\(idx)")
             }
             await expectationManager.assertExpectationsSatisfied()
         }
         """#,
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   func testOneLinerBodyWithSemicolons() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest func test() async { log(); log() }
         """,
         expandedSource:
         """
         @Test func test() async {
             let expectationManager = BCTestExpectationManager()
             log();
             log()
             await expectationManager.assertExpectationsSatisfied()
         }
         """,
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   // MARK: - with known issue

   func testWithKnownIssue() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest(.withKnownIssue) func test() async {}
         """,
         expandedSource:
         """
         @Test func test() async {
             let expectationManager = BCTestExpectationManager()
             await withKnownIssue {
                 await expectationManager.assertExpectationsSatisfied()
             }
         }
         """,
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   // MARK: - illegal invocations

   func testNonAsyncDiagnostic() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest func test() {}
         """,
         expandedSource:
         """
         @Test func test() {}
         """,
         diagnostics: [
            DiagnosticSpec(message: BCTestMacro.Error.onlyApplicableToAsyncTest.description, line: 1, column: 7)
         ],
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }

   func testThrowingNonAsyncDiagnostic() throws {
#if canImport(BCTestMacros)
      assertMacroExpansion(
         """
         @Test @BCTest func test() throws {}
         """,
         expandedSource:
         """
         @Test func test() throws {}
         """,
         diagnostics: [
            DiagnosticSpec(message: BCTestMacro.Error.onlyApplicableToAsyncTest.description, line: 1, column: 7)
         ],
         macros: testMacros
      )
#else
      XCTFail("BCTestMacros is not available on this platform.")
#endif
   }
}
