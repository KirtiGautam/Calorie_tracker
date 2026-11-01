import Foundation
import Synchronization
@testable import CalTracker

/// An `HTTPClient` that returns canned responses or errors and records every request it receives.
nonisolated final class MockHTTPClient: HTTPClient {
    /// One canned answer: a body with a status code, or a transport error.
    typealias Outcome = Result<(data: Data, statusCode: Int), any Error>

    /// The answers in request order. The last one repeats once the others are used up.
    private let outcomes: [Outcome]
    private let recordedRequests = Mutex<[URLRequest]>([])

    /// Creates a client that answers every request with `data` and `statusCode`.
    init(data: Data, statusCode: Int = 200) {
        outcomes = [.success((data, statusCode))]
    }

    /// Creates a client that fails every request with `error`.
    init(error: any Error) {
        outcomes = [.failure(error)]
    }

    /// Creates a client that answers successive requests with `outcomes` in order, repeating the last one.
    init(sequence outcomes: [Outcome]) {
        precondition(outcomes.isEmpty == false, "MockHTTPClient needs at least one outcome")
        self.outcomes = outcomes
    }

    /// The requests received so far, in order.
    var requests: [URLRequest] {
        recordedRequests.withLock { $0 }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let index = recordedRequests.withLock { requests in
            requests.append(request)
            return requests.count - 1
        }
        let (data, statusCode) = try outcomes[min(index, outcomes.count - 1)].get()
        guard
            let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            throw URLError(.badURL)
        }
        return (data, response)
    }

    /// A Gramwise error envelope body with `code`.
    static func envelope(code: String) -> Data {
        Data(#"{"error": {"code": "\#(code)", "message": "test", "details": null}}"#.utf8)
    }
}
