import Testing

@MainActor
@Suite(.serialized)
struct ConfirmationTests {

   // MARK: - unawaited Task results

   @Test func cannotConfirmInUnawaitedTask() async throws {
      await withKnownIssue {
         let _ = await confirmation(expectedCount: 1) { confirm in
            Task {
               confirm()
            }
         }
      }
   }

   @Test func cannotConfirmInUnawaitedDetachedTask() async throws {
      await withKnownIssue {
         let _ = await confirmation(expectedCount: 1) { confirm in
            Task.detached {
               confirm()
            }
         }
      }
   }

   @Test func withKnownIssueAndConfirmationInUnawaitedTask() async throws {
      let myBool = false
      await withKnownIssue {
         let _ = await confirmation(expectedCount: 1) { confirm in
            Task {
               withKnownIssue { #expect(myBool) }
               confirm()
            }
         }
      }
   }

   @Test(
      .disabled(
         "Crashes:Fatal error: Internal inconsistency: Issue reporter is not a TestReporter for test nil and test case nil."
      )
   )
   func withKnownIssueAndConfirmationInUnawaitedDetachedTask() async throws {
      let myBool = false
      await withKnownIssue {
         let _ = await confirmation(expectedCount: 1) { confirm in
            Task.detached {
               withKnownIssue { #expect(myBool) }
               confirm()
            }
         }
      }
   }

   // MARK: - awaited Task results

   @Test func canConfirmInAwaitedTask() async throws {
      let _ = await confirmation(expectedCount: 1) { confirm in
         // Arguably no reason for Task here, only used to demonstrate hoop required
         let t = Task {
            confirm()
         }
         let _ = await t.result
      }
   }

   @Test func canConfirmInAwaitedDetachedTask() async throws {
      let _ = await confirmation(expectedCount: 1) { confirm in
         // Arguably one may want to test a flow that hops isolation domains
         let t = Task.detached {
            confirm()
         }
         let _ = await t.result
      }
   }

   @Test func withKnownIssueAndConfirmationInAwaitedTaskResult() async throws {
      let myBool = false
      let _ = await confirmation(expectedCount: 1) { confirm in
         let t = Task {
            withKnownIssue { #expect(myBool) }
            confirm()
         }
         let _ = await t.result
      }
   }

   @Test(
      .disabled(
         "Crashes:Fatal error: Internal inconsistency: Issue reporter is not a TestReporter for test nil and test case nil."
      )
   )
   func withKnownIssueAndConfirmationInAwaitedDetachedTaskResult() async throws {
      let myBool = false
      let _ = await confirmation(expectedCount: 1) { confirm in
         let t = Task.detached {
            withKnownIssue { #expect(myBool) }
            confirm()
         }
         let _ = await t.result
      }
   }
}
