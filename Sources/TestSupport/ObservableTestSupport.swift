import Testing
import Foundation
import Observation

// MARK: - model

actor ChimChim {
   private var numberOfCookies: Int = 1

   func setNumberOfCookies(_ numberOfCookies: Int) -> Int {
      guard numberOfCookies > 0 else { return numberOfCookies }
      self.numberOfCookies = numberOfCookies
      return numberOfCookies
   }

   func throwCookies() async {
      await #expect(throws: Never.self) {
         try await Task.sleep(for: .seconds(1))
      }
   }
}

// MARK: - ViewModel

@MainActor @Observable final class ViewModel {
   enum ButtonState { case on, off }
   private(set) var buttonState: ButtonState = .off

   enum CookiesState: String {
      case unThrown = "need to throw"
      case throwing = "throwing"
      case thrown = "thrown"
   }
   private var cookiesState: CookiesState = .unThrown
   var cookiesStateDescription: String { cookiesState.rawValue }

   @ObservationIgnored private let chimChim: ChimChim
   /// Observable reflection of ChimChim's numberOfCookies
   private(set) var numberOfCookies: Int = 1

   init(chimChim: ChimChim) {
      self.chimChim = chimChim
      Task { await self.chimChim.setNumberOfCookies(numberOfCookies) }
   }

   func onButtonTap() {
      buttonState = .on
      cookiesState = .throwing
      Task {
         await chimChim.throwCookies()
         buttonState = .off
         cookiesState = .thrown
      }
   }

   func setNumberOfCookies(_ numberOfCookies: Int) {
      guard numberOfCookies > 0 && numberOfCookies < 4 else { return }
      Task {
         self.numberOfCookies = await chimChim.setNumberOfCookies(numberOfCookies)
      }
   }
}

// MARK: - Observable stream

@MainActor func observationTrackingStream<T: Sendable>(
   property: @escaping @MainActor () -> T
) -> AsyncStream<T> {
   AsyncStream { continuation in
      observe(property: property, continuation: continuation)
   }
}

@MainActor private func observe<T: Sendable>(
   property: @escaping @MainActor () -> T,
   continuation: AsyncStream<T>.Continuation
) {
   let curVal = withObservationTracking {
      property()
   } onChange: {
      Task { @MainActor in observe(property: property, continuation: continuation) }
   }
   continuation.yield(curVal)
}

// MARK: - recursive observe

@discardableResult
@MainActor func recursiveObserve<T: Sendable>(
   property: @escaping @MainActor () -> T,
   onChange: @escaping @MainActor () async -> Void
) -> T {
   let curVal = withObservationTracking {
      property()
   } onChange: {
      Task { @MainActor in
         await onChange()
         recursiveObserve(property: property, onChange: onChange)
      }
   }
   return curVal
}
