/// Options for configuring whether a `BCTestExpectationManager` assertion of satisfaction of all expectations will or won't
/// raise at least one `Issue`.
nonisolated public enum BCTestMacroTrait {
   case noIssue
   case withKnownIssue
}

/// Adds to the head of a Swift `@Test` body an instantiation of `BCTestExpectationManager` named `expectationManager`, and adds
/// to bottom of the Swift `@Test` body an invocation of `assertExpectationsSatisfied()` on `expectationManager`.
///
/// - Parameters:
///   - trait: a `BCTestMacroTrait`. The default is `.noIssue`
///
/// To record an `Issue` for an anticipated unsatisfied `BCTestExpectation`, pass trait `withKnownIssue` which will wrap the
/// macro-added invocation of `assertExpectationsSatisfied()` on the `BCTestExpectationManager` inside a `withKnownIssue`
/// expression. Note that embedding the function body in a `withKnownIssue` expression will not also wrap the invocation of
/// `assertExpectationsSatisfied()`because the invocation appended after the body.
///
/// The `@BCTest` macro can only be attributed to a Swift Testing `@Test`.
@attached(body)
public macro BCTest(_ trait: BCTestMacroTrait = .noIssue) = #externalMacro(module: "BCTestMacros", type: "BCTestMacro")

