import Foundation
import Synchronization
@testable import CalTracker

/// An `HTTPClient` that returns a canned response or error and records every request it receives.
nonisolated final class MockHTTPClient: HTTPClient {
    private let outcome: Result<(data: Data, statusCode: Int), any Error>
    private let recordedRequests = Mutex<[URLRequest]>([])

    /// Creates a client that answers every request with `data` and `statusCode`.
    init(data: Data, statusCode: Int = 200) {
        outcome = .success((data, statusCode))
    }

    /// Creates a client that fails every request with `error`.
    init(error: any Error) {
        outcome = .failure(error)
    }

    /// The requests received so far, in order.
    var requests: [URLRequest] {
        recordedRequests.withLock { $0 }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recordedRequests.withLock { $0.append(request) }
        let (data, statusCode) = try outcome.get()
        guard
            let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            throw URLError(.badURL)
        }
        return (data, response)
    }
}
