import Testing
import Foundation
@testable import TestSupport
@testable import BCLoggable

/*
 Sone of these tests may crash if run as a `Suite`. They perform correctly if run individually.
 */

@MainActor
@Suite(.serialized)
struct AlternativeCompletionTests: Loggable {

   // MARK: - Confirmation

   // Use of Confirmation requires a non-short circuiting tail sleep to allow an expected asynchronous event to occur.
   //
   // But there is a nuance to how to wait to confirm invocation of an asynchronous completion block that depends on how the
   // completion block is handled.

   /// Because non-escaping `onDeployed` callback of `deployJacks` is invoked before `deployJacks` returns, no tail sleep needed.
   @Test func testDeployJacks_confirmation() async throws {
      let mach5 = Mach5()
      await confirmation { confirm in
         await mach5.deployJacks(
            onDeployed: {
               confirm()
            }
         )
      }
   }

   /// Because escaping `onDeployed` callback of `deployDrone` is NOT guaranteed to be invoked before `deployDrone` returns, test
   /// can fail without tail sleep even though the callback is correctly invoked..
   @Test func testDeployDrone_confirmation_missingTailSleep() async throws {
      let mach5 = Mach5()
      await withKnownIssue {
         await confirmation { confirm in
            await mach5.deployDrone(
               onDeployed: { _ in
                  confirm()
               }
            )
         }
      }
   }

   /// Because escaping `onDeployed` callback of `deployDrone` is NOT guaranteed to be invoked before `deployDrone` returns, a
   ///  sufficient length tail sleep is required to test that the callback is correctly invoked.
   @Test func testDeployDrone_confirmation_withSufficientTailSleep() async throws {
      let mach5 = Mach5()
      try await confirmation { confirm in
         await mach5.deployDrone(
            onDeployed: { _ in
               confirm()
            }
         )
         try await Task.sleep(for: .seconds(4)) // not short circuiting
      }
   }

   /// Because escaping `onDeployed` callback of `deployDrone` is NOT guaranteed to be invoked before `deployDrone` returns, a
   /// too short tail sleep causes the test to fail even though the callback is correctly invoked.
   @Test func testDeployDrone_confirmation_withInsufficientTailSleep() async throws {
      let mach5 = Mach5()
      await withKnownIssue {
         try await confirmation { confirm in
            await mach5.deployDrone(
               onDeployed: { _ in
                  confirm()
               }
            )
            try await Task.sleep(for: .seconds(1)) // not short circuiting
         }
      }
   }

   // MARK: - CheckedContinuation

   // Only deployDrone's escaping onDeployed callback is interesting for CheckedContinuation.

   /// This test has a bug: because the first child task's completes almost immediately, the sleep task is cancelled before it can
   /// fire. Note that the sleep task is configured to timeout before the drone is deployed, but it never gets a chance to. More,
   /// if there was a code flaw that didn't invoke the `onDeployed` callback, this function would never exit.
   @Test func testDeployDrone_checkedContinuation_bug() async throws {
      let mach5 = Mach5()
      try await withCheckedThrowingContinuation { continuation in
         Task {
            try await withThrowingTaskGroup { group in
               group.addTask {
                  await mach5.deployDrone(
                     onDeployed: { _ in
                        if !Task.isCancelled {
                           log("resuming OK")
                           continuation.resume()
                        }
                     }
                  )
               }
               group.addTask {
                  // Task.sleep cooperatively cancels and throws if cancelled, so no need to check Task.cancelled
                  try await Task.sleep(for: .seconds(1))
                  log("resuming throwing timed out")
                  continuation.resume(throwing: Error.timedOut)
               }
               let _ = try await group.next()
               log("cancelling unfinished child tasks")
               group.cancelAll()
            }
         }
      }
   }

   /// This test fixes the bug by adding a nested `CheckedContinuation` that prevents the first child task from returning before
   /// the `onDeployed` callback is invoked. Ironically, this is verified by configuring the timeout task to be shorter than the
   /// time required to deploy the drone.
   @Test func testDeployDrone_checkedContinuation_fixedButInsufficientTimeout() async throws {
      let mach5 = Mach5()
      await withKnownIssue {
         try await withCheckedThrowingContinuation { continuation in
            Task {
               try await withThrowingTaskGroup { group in
                  group.addTask {
                     await withCheckedContinuation { nestedContinuation in
                        Task {
                           await mach5.deployDrone(
                              onDeployed: { _ in
                                 if !Task.isCancelled {
                                    log("resuming OK")
                                    continuation.resume()
                                 }
                                 nestedContinuation.resume()
                              }
                           )
                        }
                     }
                  }
                  group.addTask {
                     // Task.sleep cooperatively cancels and throws if cancelled, so no need to check Task.cancelled
                     try await Task.sleep(for: .seconds(1))
                     log("resuming throwing timed out")
                     continuation.resume(throwing: Error.timedOut)
                  }
                  let _ = try await group.next()
                  log("cancelling unfinished child tasks")
                  group.cancelAll()
               }
            }
         }
      }
   }

   /// This test both fixes the bug and has timeout task of sufficient length to allow `onDeployed` to be called and to correctly
   /// abort the test if it is not.
   @Test func testDeployDrone_checkedContinuation_fixedAndSufficientTimeout() async throws {
      let mach5 = Mach5()
      try await withCheckedThrowingContinuation { continuation in
         Task {
            try await withThrowingTaskGroup { group in
               group.addTask {
                  await withCheckedContinuation { nestedContinuation in
                     Task {
                        await mach5.deployDrone(
                           onDeployed: { _ in
                              if !Task.isCancelled {
                                 log("resuming OK")
                                 continuation.resume()
                              }
                              nestedContinuation.resume()
                           }
                        )
                     }
                  }
               }
               group.addTask {
                  // Task.sleep cooperatively cancels and throws if cancelled, so no need to check Task.cancelled
                  try await Task.sleep(for: .seconds(10))
                  log("resuming throwing timed out")
                  continuation.resume(throwing: Error.timedOut)
               }
               let _ = try await group.next()
               log("cancelling unfinished child tasks")
               group.cancelAll()
            }
         }
      }
   }

   enum Error: Swift.Error {
      case timedOut
   }
}
