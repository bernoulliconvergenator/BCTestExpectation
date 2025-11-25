import Testing
import Observation
@testable import BCTestExpectation
@testable import TestSupport
@testable import BCLoggable

@MainActor struct ObservableTests: Loggable {

   // MARK: - test single change

   /// No timeout on expectation required
   @Test @BCTest func testSetNumberOfCookies_inRange() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let numberOfCookiesChange = try await expectationManager.expectation("number of cookies change")
      let newNumberOfCookies = 2
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      withObservationTracking {
         let _ = viewModel.numberOfCookies
      } onChange: {
         Task { @MainActor in
            log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
            #expect(viewModel.numberOfCookies == newNumberOfCookies)
            numberOfCookiesChange.satisfy()
         }
      }
      viewModel.setNumberOfCookies(newNumberOfCookies)
      try await awaitSatisfaction(of: [numberOfCookiesChange])
   }

   /// Requires timeout on expectation to ensure asynchronous event does not occur.
   @Test @BCTest func testSetNumberOfCookies_tooLow() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let numberOfCookiesChange = try await expectationManager.expectation("number of cookies change", expectedCount: 0)
      let newNumberOfCookies = 0
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      withObservationTracking {
         let _ = viewModel.numberOfCookies
      } onChange: {
         Task { @MainActor in
            log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
            #expect(viewModel.numberOfCookies == newNumberOfCookies)
            numberOfCookiesChange.satisfy()
         }
      }
      viewModel.setNumberOfCookies(newNumberOfCookies)
      try await awaitSatisfaction(of: [numberOfCookiesChange], timeout: .milliseconds(500))
   }

   /// Requires timeout on expectation to ensure asynchronous event does not occur.
   @Test @BCTest func testSetNumberOfCookies_tooHigh() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let numberOfCookiesChange = try await expectationManager.expectation("number of cookies change", expectedCount: 0)
      let newNumberOfCookies = 5
      #expect(viewModel.numberOfCookies != newNumberOfCookies)

      withObservationTracking {
         let _ = viewModel.numberOfCookies
      } onChange: {
         Task { @MainActor in
            log("onChange numberOfCookies=\(viewModel.numberOfCookies)")
            #expect(viewModel.numberOfCookies == newNumberOfCookies)
            numberOfCookiesChange.satisfy()
         }
      }
      viewModel.setNumberOfCookies(newNumberOfCookies)
      try await awaitSatisfaction(of: [numberOfCookiesChange], timeout: .milliseconds(500))
   }

   // MARK: - test sequence of changes to button state

   @Test @BCTest func testOnButtonTap_buttonState() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let buttonStateToOn = try await expectationManager.expectation("button state to on")
      let buttonStateToOff = try await expectationManager.expectation("button state to off")

      let initialButtonState = recursiveObserve {
         viewModel.buttonState
      } onChange: {
         log("onChange buttonState=\(viewModel.buttonState)")
         switch viewModel.buttonState {
         case .on:
            buttonStateToOn.satisfy()
            #expect(await !buttonStateToOff.isSatisfied())
         case .off:
            buttonStateToOff.satisfy()
         }
      }
      #expect(initialButtonState == .off)

      viewModel.onButtonTap()
      try await awaitSatisfaction(of: [buttonStateToOn, buttonStateToOff], timeout: .seconds(2))
   }

   // MARK: - test sequence of changes to throw state

   @Test @BCTest func testOnButtonTap_cookiesStateDescription() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let descriptionToThrowing = try await expectationManager.expectation("to throwing")
      let descriptionToThrown = try await expectationManager.expectation("to thrown")

      let initialCookiesStateDescription = recursiveObserve {
         viewModel.cookiesStateDescription
      } onChange: {
         log("onChange cookiesStateDescription=\(viewModel.cookiesStateDescription)")
         switch viewModel.cookiesStateDescription {
         case ViewModel.CookiesState.throwing.rawValue:
            descriptionToThrowing.satisfy()
            #expect(await !descriptionToThrown.isSatisfied())
         case ViewModel.CookiesState.thrown.rawValue:
            descriptionToThrown.satisfy()
         case ViewModel.CookiesState.unThrown.rawValue:
            Issue.record("cookiesStateDescription should not change to unThrown.rawValue")
         default:
            Issue.record("Unexpected cookiesStateDescription=\(viewModel.cookiesStateDescription)")
         }
      }
      #expect(initialCookiesStateDescription == ViewModel.CookiesState.unThrown.rawValue)

      viewModel.onButtonTap()
      try await awaitSatisfaction(of: [descriptionToThrowing, descriptionToThrown], timeout: .seconds(2))
   }

   // MARK: - test both button and throw state in one test

   @Test @BCTest func testOnButtonTap_recursiveObserve() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let buttonStateToOn = try await expectationManager.expectation("button state to on")
      let buttonStateToOff = try await expectationManager.expectation("button state to off")
      let descriptionToThrowing = try await expectationManager.expectation("to throwing")
      let descriptionToThrown = try await expectationManager.expectation("to thrown")

      let initialButtonState = recursiveObserve {
         viewModel.buttonState
      } onChange: {
         log("onChange buttonState=\(viewModel.buttonState)")
         switch viewModel.buttonState {
         case .on:
            buttonStateToOn.satisfy()
            #expect(await !buttonStateToOff.isSatisfied())
         case .off:
            buttonStateToOff.satisfy()
         }
      }
      #expect(initialButtonState == .off)

      let initialCookiesStateDescription = recursiveObserve {
         viewModel.cookiesStateDescription
      } onChange: {
         log("onChange cookiesStateDescription=\(viewModel.cookiesStateDescription)")
         switch viewModel.cookiesStateDescription {
         case ViewModel.CookiesState.throwing.rawValue:
            descriptionToThrowing.satisfy()
            #expect(await !descriptionToThrown.isSatisfied())
         case ViewModel.CookiesState.thrown.rawValue:
            descriptionToThrown.satisfy()
         case ViewModel.CookiesState.unThrown.rawValue:
            Issue.record("cookiesStateDescription should not change to unThrown.rawValue")
         default:
            Issue.record("Unexpected cookiesStateDescription=\(viewModel.cookiesStateDescription)")
         }
      }
      #expect(initialCookiesStateDescription == ViewModel.CookiesState.unThrown.rawValue)

      viewModel.onButtonTap()
      try await awaitSatisfaction(of: [
         buttonStateToOn, buttonStateToOff, descriptionToThrowing, descriptionToThrown
      ], timeout: .seconds(2))
   }

   @available(iOS 26, macOS 26, *)
   @Test @BCTest func testOnButtonTap_Observations() async throws {
      let viewModel = ViewModel(chimChim: ChimChim())
      let eThrowingCookies = try await expectationManager.expectation("throwing cookies")
      let eCookiesThrown = try await expectationManager.expectation("cookies thrown")

      let observations = Observations {
         (viewModel.buttonState, viewModel.cookiesStateDescription)
      }

      let t = Task {
         for await (buttonState, cookiesStateDescription) in observations {
            log("observed: buttonState=\(buttonState), cookiesStateDescription=\(cookiesStateDescription)")
            switch buttonState {
            case .on:
               #expect(cookiesStateDescription == "throwing")
               eThrowingCookies.satisfy()
            case .off:
               #expect(cookiesStateDescription == "thrown")
               eCookiesThrown.satisfy()
            }
         }
      }

      viewModel.onButtonTap()
      try await awaitSatisfaction(of: [eThrowingCookies, eCookiesThrown], timeout: .seconds(1.5))
      t.cancel()
   }
}
