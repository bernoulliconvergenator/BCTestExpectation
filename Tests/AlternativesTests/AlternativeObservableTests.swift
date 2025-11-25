import Testing
import Observation
@testable import TestSupport
@testable import BCLoggable

/*
 Sone of these tests may crash if run as a `Suite`. They perform correctly if run individually.
 */

@MainActor
@Suite(.serialized)
struct AlternativeObservableTests: Loggable {

   // MARK: - test single change with CheckedContinuation

   @Test func testSetNumberOfCookies_inRange_checkedContinuation() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 2
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      await withCheckedContinuation { continuation in
         withObservationTracking {
            let _ = viewModel.numberOfCookies
         } onChange: {
            Task { @MainActor in
               log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
               #expect(viewModel.numberOfCookies == newNumberOfCookies)
               continuation.resume()
            }
         }
         viewModel.setNumberOfCookies(newNumberOfCookies)
      }
   }

   // MARK: - test single change with Confirmation

   // Requires a tail Task.sleep to allow asynchronous event to occur and be confirmed.
   @Test func testSetNumberOfCookies_inRange_confirmation() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 2
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      try await confirmation { confirm in
         withObservationTracking {
            let _ = viewModel.numberOfCookies
         } onChange: {
            Task { @MainActor in
               log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
               #expect(viewModel.numberOfCookies == newNumberOfCookies)
               confirm()
            }
         }
         viewModel.setNumberOfCookies(newNumberOfCookies)
         try await Task.sleep(for: .seconds(1)) // Must sleep to allow change to occur
      }
   }

   // Same test as above without tail Task.sleep cannot pass
   @Test func testSetNumberOfCookies_inRange_confirmation_noSleep() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 2
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      await withKnownIssue {
         await confirmation { confirm in
            withObservationTracking {
               let _ = viewModel.numberOfCookies
            } onChange: {
               Task { @MainActor in
                  log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
                  #expect(viewModel.numberOfCookies == newNumberOfCookies)
                  confirm()
               }
            }
            viewModel.setNumberOfCookies(newNumberOfCookies)
            // missing tail Task.sleep here
         }
      }
   }

   // Testing for an asynchronous event that does not occur requires tail Task.sleep. Same with BCTestExpectation.
   @Test func testSetNumberOfCookies_tooLow() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 0
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      try await confirmation(expectedCount: 0) { confirm in
         withObservationTracking {
            let _ = viewModel.numberOfCookies
         } onChange: {
            Task { @MainActor in
               log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
               #expect(viewModel.numberOfCookies == newNumberOfCookies)
               confirm()
            }
         }
         viewModel.setNumberOfCookies(newNumberOfCookies)
         try await Task.sleep(for: .seconds(1)) // Must sleep to allow change to occur, in case it does
      }
   }

   // BUT same test as above without tail Task.sleep also passes! So it doesn't actually ensure event doesn't happen.
   @Test func testSetNumberOfCookies_tooLow_noSleep() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 0
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      await confirmation(expectedCount: 0) { confirm in
         withObservationTracking {
            let _ = viewModel.numberOfCookies
         } onChange: {
            Task { @MainActor in
               log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
               #expect(viewModel.numberOfCookies == newNumberOfCookies)
               confirm()
            }
         }
         viewModel.setNumberOfCookies(newNumberOfCookies)
         // missing tail Task.sleep here
      }
   }

   // Requires tail Task.sleep to ensure asynchronous event does not occur. Same with BCTestExpectation.
   @Test func testSetNumberOfCookies_tooHigh() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 5
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      try await confirmation(expectedCount: 0) { confirm in
         withObservationTracking {
            let _ = viewModel.numberOfCookies
         } onChange: {
            Task { @MainActor in
               log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
               #expect(viewModel.numberOfCookies == newNumberOfCookies)
               confirm()
            }
         }
         viewModel.setNumberOfCookies(newNumberOfCookies)
         try await Task.sleep(for: .seconds(1)) // Must sleep to allow change to occur, in case it does
      }
   }

   // Same test as above without tail Task.sleep also passes, but doesn't ensure even does not happen.
   @Test func testSetNumberOfCookies_tooHigh_noSleep() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let newNumberOfCookies = 5
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      await confirmation(expectedCount: 0) { confirm in
         withObservationTracking {
            let _ = viewModel.numberOfCookies
         } onChange: {
            Task { @MainActor in
               log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
               #expect(viewModel.numberOfCookies == newNumberOfCookies)
               confirm()
            }
         }
         viewModel.setNumberOfCookies(newNumberOfCookies)
         // missing tail Task.sleep here
      }
   }

   // MARK: - test multiple changes to button state using Confirmation

   // Funky. Double check on argument changeCount to confirm change order and record expected umber of events.
   @Test func testOnButtonTap_buttonState_confirmation() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      try await confirmation(expectedCount: 2) { confirmation in
         @MainActor func observe(changeCount: Int) {
            withObservationTracking {
               let _ = viewModel.buttonState
            } onChange: { [observe] in // capture local function with global isolation workaround for non-Sendable Swift bug
               Task { @MainActor in
                  log("onChange buttonState=\(viewModel.buttonState)")
                  switch viewModel.buttonState {
                  case .on:
                     #expect(changeCount == 0)
                     if changeCount == 0 { confirmation() }
                     observe(changeCount + 1)
                  case .off:
                     #expect(changeCount == 1)
                     if changeCount == 1 { confirmation() }
                     observe(changeCount + 1)
                  }
               }
            }
         }
         observe(changeCount: 0)
         viewModel.onButtonTap()
         try await Task.sleep(for: .seconds(2)) // MUST sleep to allow events to occur, sleep non-short circuiting
      }
   }

   // MARK: - test multiple change to button state using CheckedContinuation

   private enum Error: Swift.Error {
      case unexpectedChange
   }

   @Test func testOnButtonTap_buttonState_checkedContinuation() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
         @MainActor func observe(changeCount: Int) {
            withObservationTracking {
               let _ = viewModel.buttonState
            } onChange: { [observe] in // capture local function with global isolation workaround for non-Sendable Swift bug
               Task { @MainActor in
                  log("onChange buttonState=\(viewModel.buttonState)")
                  switch viewModel.buttonState {
                  case .on:
                     #expect(changeCount == 0)
                     observe(changeCount + 1)
                  case .off:
                     #expect(changeCount == 1)
                     if changeCount == 1 {
                        continuation.resume()
                     } else {
                        continuation.resume(throwing: Error.unexpectedChange)
                     }
                  }
               }
            }
         }
         observe(changeCount: 0)
         viewModel.onButtonTap()
      }
   }

   // MARK: - test multiple changes to button state using an AsyncStream

   // Observe using a `observationTrackingStream`. No need for `Confirmation`, `CheckedContinuation`, nor `BCTestExpectation`,
   // but requires correctly added `break loop` statements and no way to include a timeout.

   // No way to timeout if expected events do not occur, so test could run forever.
   @Test func testOnButtonTap_buttonState_stream() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let stream = observationTrackingStream { viewModel.buttonState }

      var changeCount = 0
      viewModel.onButtonTap()
      loop: for await buttonState in stream {
         log("changeCount=\(changeCount) buttonState=\(buttonState)")
         defer { changeCount += 1 }
         switch changeCount {
         case 0:
            #expect(buttonState == .off)
         case 1:
            #expect(buttonState == .on)
         case 2:
            #expect(buttonState == .off)
            break loop
         default:
            Issue.record("should not get here")
            break loop
         }
      }
   }

   // MARK: - test sequence of changes to throw state

   // No way to timeout if expected events do not occur, so test could run forever.
   @Test func testOnButtonTap_cookiesStateDescription_stream() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let stream = observationTrackingStream { viewModel.cookiesStateDescription }

      var changeCount = 0
      viewModel.onButtonTap()
      loop: for await cookiesStateDescription in stream {
         log("changeCount=\(changeCount) cookiesStateDescription=\(cookiesStateDescription)")
         defer { changeCount += 1 }
         switch changeCount {
         case 0:
            #expect(cookiesStateDescription == ViewModel.CookiesState.unThrown.rawValue)
         case 1:
            #expect(cookiesStateDescription == ViewModel.CookiesState.throwing.rawValue)
         case 2:
            #expect(cookiesStateDescription == ViewModel.CookiesState.thrown.rawValue)
            break loop
         default:
            Issue.record("should not get here")
            break loop
         }
      }
   }

   // MARK: - test both button and throw state in one test

   @Test func testOnButtonTap_stream() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let buttonStateStream = observationTrackingStream { viewModel.buttonState }
      let cookiesStateStream = observationTrackingStream { viewModel.cookiesStateDescription }

      var buttonStateChangeCount = 0
      viewModel.onButtonTap()
      loop: for await buttonState in buttonStateStream {
         log("buttonStateChangeCount=\(buttonStateChangeCount) buttonState=\(buttonState)")
         defer { buttonStateChangeCount += 1 }
         switch buttonStateChangeCount {
         case 0:
            #expect(buttonState == .off)
         case 1:
            #expect(buttonState == .on)
         case 2:
            #expect(buttonState == .off)
            break loop
         default:
            Issue.record("should not get here")
            break loop
         }
      }

      // Because stream buffers values and exists until out of scope, we can later read buffered values
      var cookiesStateChangeCount = 0
      loop: for await cookiesStateDescription in cookiesStateStream {
         log("cookiesStateChangeCount=\(cookiesStateChangeCount) cookiesStateDescription=\(cookiesStateDescription)")
         defer { cookiesStateChangeCount += 1 }
         switch cookiesStateChangeCount {
         case 0:
            #expect(cookiesStateDescription == ViewModel.CookiesState.unThrown.rawValue)
         case 1:
            #expect(cookiesStateDescription == ViewModel.CookiesState.throwing.rawValue)
         case 2:
            #expect(cookiesStateDescription == ViewModel.CookiesState.thrown.rawValue)
            break loop
         default:
            Issue.record("should not get here")
            break loop
         }
      }
   }
}
