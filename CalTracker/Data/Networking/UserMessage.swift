import Foundation

/// Returns a friendly, localized message for `error`, never the raw `localizedDescription`.
func userMessage(for error: any Error) -> LocalizedStringResource {
    if let urlError = error as? URLError {
        return switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .errorOffline
        case .timedOut: .errorTimeout
        default: .errorServer
        }
    }

    if let apiError = error as? APIError {
        return switch apiError {
        case .rateLimited: .errorRateLimited
        case .decoding: .errorUnexpectedData
        case .invalidURL, .invalidResponse, .httpStatus: .errorServer
        }
    }

    if error is DecodingError {
        return .errorUnexpectedData
    }

    if let logFoodError = error as? LogFoodError {
        return switch logFoodError {
        case .invalidAmount: .errorInvalidAmount
        }
    }

    return .errorGeneric
}
