nonisolated extension Array {
    /// Splits the array into consecutive slices of at most `size` elements, in order.
    ///
    /// - Precondition: `size` is greater than 0.
    func chunked(into size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { start in
            self[start..<Swift.min(start + size, count)]
        }
    }
}
