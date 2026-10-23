import Foundation

/// The explicit lifecycle of asynchronously loaded content.
enum Loadable<Value> {
    /// Nothing has been requested.
    case idle

    /// A request is in flight.
    case loading

    /// The request finished with a value.
    case loaded(Value)

    /// The request failed with a message ready to show the person.
    case failed(LocalizedStringResource)
}
