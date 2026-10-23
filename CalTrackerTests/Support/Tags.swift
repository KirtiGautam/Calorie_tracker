import Testing

extension Tag {
    /// Tests that exercise networking code, always against mocks.
    @Tag static var networking: Self

    /// Tests that exercise SwiftData persistence, always in memory.
    @Tag static var persistence: Self
}
