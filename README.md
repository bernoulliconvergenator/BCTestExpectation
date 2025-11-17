# BCTestExpectation

The Swift package `BCTestExpectation` provides `XCTestExpectation`-like ergonomics for Swift Testing. `BCTestExpectation` is written using Swift Concurrency and adopts Approachable Concurrency.

With `XCTestExpectation` we might have tested completion callback code with:
```swift
func testDroneOnDeploy() async {
  let e = self.expectation()
  await mach5.deployDrone(onDeployed: { _ in expectation.fulfill() })
  wait(for: [e], timeout: 1.0)
}
```

With `BCTestExpectation`, we do nearly the same:
```swift
@Test @BCTest func testDroneOnDeploy() async throws {
  let expectation = expectationManager.expectation()
  await mach5.deployDrone(onDeployed: { _ in expectation.satisfy() })
  try await awaitSatisfaction(of: [expectation], timeout: .seconds(1))
}
```
Note addition of `@BCTest` macro in the function header.

Failures are also very similar. With `XCTestExpectation`, this test fails with `Asynchronous wait failed: Exceeded timeout of 0.5 seconds, with unfulfilled expectations: "fulfill".`
```swift
func testFailToFulfill() {
  let e = self.expectation()
  wait(for: [e], timeout: 0.5)
}
```
`BCTestExpectation` uses Swift Testing's `Issue` type. This `@BCTest` test fails with `Caught error: BCTestExpectation wait for satisfaction timed out: my expectation: satisfied 0 times, expected 1` 
```swift
@Test @BCTest func failToSatisfy() async throws {
  let expectation = try await expectationManager.expectation("my expectation")
  try await awaitSatisfaction(of: expectation, timeout: .milliseconds(500))
}
```

In the `@BCTest` functions above, `expectation` is a `BCTestExpectation` and `expectationManager` is a `BCTestExpectationManager`. The `@BCTest` macro expands to:
```swift
@Test @BCTest func testDroneOnDeploy() async throws {
  let expectationManager = BCTestExpectationManager()
  let expectation = expectationManager.expectation()
  await mach5.deployDrone(onDeployed: { _ in expectation.satisfy() })
  try await awaitSatisfaction(of: [expectation], timeout: .seconds(1))
  await expectationManager.assertExpectationsSatisfied()
}
``` 
The first and last lines are the only additions. See the Implementation section for more details. 

A `BCTestExpectation` can await on asynchronous events, can be configured to be satisfied 0, 1, or more times, and can be configured to fail if not satisfied within a certain time or if over satisfied.

`BCTestExpectation` has more use than simplifying migration to Swift Testing from `XCTestExpectation`. Consider how we might test an `@Observable` view model with observable property `buttonState`:
```swift
@MainActor func onThrowCookiesButtonTap() {
  buttonState = .on
  Task {
    await chimChim.throwCookies()
    buttonState = .off
  }
}
```
Note that `buttonState` initially changes synchronously but the second change occurs asynchronously.

Using `BCTestExpectation` we can do:
```swift
@MainActor @Test @BCTest func testOnButtonTap_buttonState() async throws {
  let viewModel = ViewModel(chimChim: ChimChim())
  let buttonStateToOn = try await expectationManager.expectation("button state to on")
  let buttonStateToOff = try await expectationManager.expectation("button state to off")

  let initialButtonState = recursiveObserve {
    viewModel.buttonState
  } onChange: {
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
```
where `recursiveObserve` is
```swift
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
```

See the `BCTestTests` folder for many examples of test cases spanning satisfied, unsatisfied, over satisfied, and unexpected satisfied expectations. There are also test cases covering completion handling and `@Observable`.  

## Alternative built-in options for testing asynchronous code

Swift Testing and Swift Concurrency provide options for testing asynchronous code that are valid and lead to success, but can be complicated to figure out.

### Using Swift Testing `Confirmation` to test asynchronous code

Swift Testing's' `Confirmation` must be confirmed before execution of its closure parameter completes. If confirmation must occur after an asynchronously executed event, e.g. in a callback, a workaround is to use a `Task.sleep` after triggering the flow that results in the asynchronous event. The sleep duration needs to be long enough for the asynchronous event to occur, else the test can fail even though the code executes correctly. Unfortunately, the `Task.sleep` is non-short circuiting so the test always takes as long as the sleep duration.

Testing asynchronous completion handler code with `Confirmation` and a tail sleep:
```swift
@Test func testDroneOnDeploy() async {
  try await confirmation { confirm in 
    await mach5.deployDrone(onDeployed: { _ in confirm() })
    try await Task.sleep(for: .seconds(4)) // Must sleep long enough to allow callback invocation
  }
}
```

Testing an `@Observable` with `Confirmation` and a tail sleep to allow time for `withObservationTracking`'s `onChange` block to be invoked in the next runloop for didSet semantics so we can verify the change:
```swift
@Test func testSetNumberOfCookies_inRange_confirmation() async throws {
  let viewModel = ViewModel(chimChim: ChimChim())
  let newNumberOfCookies = 2
  #expect(viewModel.numberOfCookies != newNumberOfCookies) // required else onChange not triggered

  try await confirmation { confirm in
    withObservationTracking {
      let _ = viewModel.numberOfCookies
    } onChange: {
      Task { @MainActor in
        #expect(viewModel.numberOfCookies == newNumberOfCookies)
        confirm()
      }
    }
    viewModel.setNumberOfCookies(newNumberOfCookies)
    try await Task.sleep(for: .seconds(1)) // Must sleep to allow change to occur
  }
}
```

This need for a tail sleep with `Confirmation` is not obvious and forgetting to add it, while likely leading to failed tests, is not clarified by the failure. For comparison, when using `BCTestExpectation` forgetting to add `try await awaitSatisfaction(of: [numberOfCookiesChange], timeout: .seconds(1))` results in a clarifying `Issue`. 

Testing that an asynchronous event does *not* occur is tricky with `Confirmation` because forgetting the tail sleep when the `Confirmation`'s' `expectedCount` is `0` means the test passes without actually verifying the event did not occur. For comparison, `BCTestExpectation` enforces a required timeout when its `expectedCount` property is `0`. This test:
```swift
@Test @BCTest func zeroExpectedCount_noTimeout() async throws {
  let expectation = try await expectationManager.expectation(expectedCount: 0)
  try await awaitSatisfaction(of: expectation)
}
```
fails with `Caught error: A BCTestExpectation with 0 expected count cannot wait forever: <no description>: satisfied 0 times, expected 0`.

Also, with `BCTestExpectation` a timeout short circuits on satisfaction. 

More examples of using `Confirmation` to test asynchronous code can be found in `ConfirmationTests.swift`, `AlternativeCompletionTests.swift`, and `AlternativeObservableTests.swift`.

### Using Swift Concurrency `CheckedContinuation` to test asynchronous code

Swift Concurrency's `CheckedContinuation` waits to be resumed after an asynchronous event but offers no short circuiting timeout if the event does not occur. This means a test will run forever (or to Swift Testing's `timeLimit` trait the shortest of which is one minute) if the event never occurs. A workaround is to use a `TaskGroup`. One child task triggers the flow that results in the asynchronous event and another contains the timeout:
```swift
@Test func testDeployDrone_checkedContinuation_fixedAndSufficientTimeout() async throws {
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
```

Another consideration with `CheckedContinuation` is that it can only be resumed once, so lacks a facility for tracking multiple occurrences of an event or multiple events, which means additional test logic is necessary to resume after some number of asynchronous events occur.

More examples of using `CheckedContinuation` to test asynchronous code can be found in `CheckedContinuationTests.swift`, `AlternativeCompletionTests.swift`, and `AlternativeObservableTests.swift`.

### Using an `AsyncStream` of observed changes to test an `@Observable`

Returning to the observable `buttonState` change example, we could test this flow with an `AsyncStream`:
```swift
@Test func testOnButtonTap_buttonState_stream() async throws {
  let viewModel = ViewModel(chimChim: ChimChim())
  let stream = observationTrackingStream { viewModel.buttonState }

  var changeCount = 0
  viewModel.onButtonTap()
  loop: for await buttonState in stream {
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
```
where `observationTrackingStream` is:
```swift
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
```
 
## Implementation

The `BCTestExpectation` package comprises the `@BCTest` macro, two actor types, `BCTestExpectation` and `BCTestExpectationManager`, and a top level nonisolated async function `awaitSatisfaction(of:timeout:)`.

The `@BCTest` macro is a `BodyMacro` that prepends the function body with creation of a `BCTestExpectationManager` and appends the function body with a call to the manager's `assertExpectationsSatisfied()` method. Thus the manager is available within the function body to create expectations, and the verification of expectation satisfaction is guaranteed.

Only a `BCTestExpectationManager` can create a `BCTestExpectation`. The manager stores all expectations it creates. Only the manager can verify that all created expectations are satisfied.

The only public action available on a `BCTestExpectation` is to call `satisfy()`.

Waiting for satisfaction of one or more `BCTestExpectation` is performed by calling top level function `awaitSatisfaction(of:timeout:)`, passing it the expectation(s). Because this package adopts Approachable Concurrency, nonisolated async `awaitSatisfaction(of:timeout:)` inherits the caller's isolation, if any.

We define 'satisfaction' to require that `satisfy()` is called the number of expected times. Over satisfaction is defined as requiring both prior satisfaction and `satisfy()` called more times than expected. This means that a `BCTestExpectation` with an `expectedCount` of `0` can never be satisfied nor over satisfied.

Any `BCTestExpectation` that does not pass verification raises an `Issue`.
 
An anticipated `Issue` raised for a `BCTestExpectation` that will not pass verification can be caught by including the trait `.withKnownIssue` in the `@BCTest` expression, i.e., `@BCTest(.withKnownIssue)`.

`BCTestExpectation` has these invariants:
- an expectation can be satisfied before await starts
- an expectation can be satisfied during await
- a test fails if an expectation is satisfied after await ends
- a test aborts if an expectation has expected count 0 and a forever timeout
- a test aborts if an expectation is awaited more than once (programmer error)
- a test fails if an expectation is never awaited
- a test fails if expectation is not satisfied before await ends
- a test fails if an expectation’s await times out
- a test fails if await is not ended when expectation satisfaction asserted
- a test can be configured to fail if an expectation is over satisfied

### Expectations never meant to be satisfied

`BCTestExpectation` adopts `expectedCount` of `0` for expectations that are never meant to be satisfied. `XCTest` refers to these as 'inverted'.

An `BCTestExpectation` with `expectedCount` of `0` can never be satisfied because satisfaction requires that `satisfy()` is called exactly as many times as `expectedCount`. It also means that an `BCTestExpectation` with `expectedCount` of `0` can never be over satisfied. Accordingly, configuration parameter `issueForOverSatisfied` has no impact when `expectedCount` is set to `0`.

Awaiting satisfaction of an `BCTestExpectation` with `expectedCount` of `0` requires a `timeout` value less than `BCTestExpectation.forever` to prevent a test from running forever. If no timeout is required because a test verifies an event does not occur synchronously, consider redesigning the test with `Confirmation`.    

### Over satisfying expectations

`BCTestExpectation` is by default configured to raise an `Issue` if over satisfied -- but detecting over satisfaction of asynchronously occurring events can be a race. 

On starting the wait for satisfaction of an expectation, if not already satisfied (nor already awaited), we create an `AsyncStream.Continuation` and do not return until it finishes. `finish()` is called on the `Continuation` when the expectation is satisfied per the definition above, or when the wait for satisfaction times out. When the wait for satisfaction actually ends, though, depends on isolation and suspensions.

This synchronous flow correctly raises an over satisfied `Issue`:
```swift
@Test("should catch error BCTestExpectation.SatisfyError.overSatisfied")
@BCTest(.withKnownIssue)
func overSatisfyWithAwaitTimeout() async throws {
  let expectation = try await expectationManager.expectation()
  expectation.satisfy()
  expectation.satisfy()
  try await awaitSatisfaction(of: expectation, timeout: .milliseconds(250))
}
``` 

This actor isolated asynchronous flow also correctly raises an over satisfied `Issue`:
```swift
@MainActor
@Test("should catch error BCTestExpectation.SatisfyError.overSatisfied")
@BCTest(.withKnownIssue)
func overSatisfy_inTask() async throws {
  let expectation = try await expectationManager.expectation()
  Task {
    expectation.satisfy()
    expectation.satisfy()
  }
  try await awaitSatisfaction(of: expectation)
}
```

If on the other hand we suspend between calls to `satisfy()`, e.g. insert `try await Task.sleep(for: .milliseconds(500))` between calls, the test will likely not detect over satisfaction.

The outcome is less predictable if the `satisfy()` calls run parallel to the wait for satisfaction, e.g. by placing the calls in a detached `Task`. 

See `OverSatisfiedTests.swift` for these and more examples.

## Fragility

`BCTestExpectationManager` is not a singleton, so the macro expansion requires `BCTestExpectationManager` methods `init` and `assertNeedsSatisfied()` are public -- but you should not create another `BCTestExpectationManager` as there will be no guarantee the manager asserts satisfaction of expectations it creates. Failing to assert expectations satisfied for expectations created by a manager you created is a silent programmer error. 

## License

This package is released under the MIT license.
