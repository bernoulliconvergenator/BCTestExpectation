import Testing

/*
 Trait .serialized is required else tests:
 - withKnownIssueInDetachedTaskBeforeResume
 - withKnownIssueInDetachedTaskAfterResume
 crash with "Fatal error: Internal inconsistency: No test reporter for test"

 Also note test withKnownIssueInTaskAfterResumeAfterDelay should raise issue but does not.
 */

@MainActor
@Suite(.serialized)
struct CheckedContinuationSuite {
   @Test func passInTaskBeforeResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            #expect(!myBool)
            continuation.resume()
         }
      }
   }

   @Test func passInTaskAfterResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            continuation.resume()
            #expect(!myBool)
         }
      }
   }

   @Test func withKnownIssueBeforeResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         withKnownIssue { #expect(myBool) }
         continuation.resume()
      }
   }

   @Test func withKnownIssueAfterResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         continuation.resume()
         withKnownIssue { #expect(myBool) }
      }
   }

   // MARK: - in Task

   @Test func withKnownIssueInTaskBeforeResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            withKnownIssue { #expect(myBool) }
            continuation.resume()
         }
      }
   }

   @Test func withKnownIssueInTaskAfterResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            continuation.resume()
            withKnownIssue { #expect(myBool) }
         }
      }
   }

   // MARK: - in detached Task

   // Swift Testing cannot raise issues in detached Tasks
   @Test(
      .disabled(
         "Crashes: Fatal error: Internal inconsistency: Issue reporter is not a TestReporter for test nil and test case nil."
      )
   )
   func withKnownIssueInDetachedTaskBeforeResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task.detached {
            withKnownIssue { #expect(myBool) }
            continuation.resume()
         }
      }
   }

   @Test(
      .disabled(
         "Crashes: Fatal error: Internal inconsistency: Issue reporter is not a TestReporter for test nil and test case nil."
      )
   )
   func withKnownIssueInDetachedTaskAfterResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task.detached {
            continuation.resume()
            withKnownIssue { #expect(myBool) }
         }
      }
   }

   // MARK: - in Task after delay

   @Test func withKnownIssueInTaskAfterDelayBeforeResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            try? await Task.sleep(for: .milliseconds(200))
            withKnownIssue { #expect(myBool) }
            continuation.resume()
         }
      }
   }

   @Test func withKnownIssueInTaskAfterDelayAfterResume() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            try? await Task.sleep(for: .milliseconds(200))
            continuation.resume()
            withKnownIssue { #expect(myBool) }
         }
      }
   }

   // *********************************************
   // *** !! Should raise issue BUT DOES NOT !! ***
   // *********************************************
   @Test func withKnownIssueInTaskAfterResumeAfterDelay() async throws {
      let myBool = false
      await withCheckedContinuation { continuation in
         Task {
            continuation.resume()
            try? await Task.sleep(for: .milliseconds(200))
            withKnownIssue { #expect(myBool) }
         }
      }
   }
}
