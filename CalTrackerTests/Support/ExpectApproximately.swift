import Testing

/// Expects `actual` to be within `tolerance` of `expected`, recording an issue when it's `nil` or too far off.
func expectApproximately(
    _ actual: Double?,
    _ expected: Double,
    tolerance: Double = 1e-9,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let actual else {
        Issue.record("Expected \(expected), got nil", sourceLocation: sourceLocation)
        return
    }
    #expect(abs(actual - expected) <= tolerance, "Expected \(expected), got \(actual)", sourceLocation: sourceLocation)
}
