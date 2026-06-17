//
//  DataDomeInterceptor.swift
//  DataDomeAlamofire
//
//  Copyright © 2020 DataDome. All rights reserved.
//

import Foundation
import Alamofire
import CoreDataDome

/// DataDome integration for Alamofire.
///
/// Conforms to Alamofire's `RequestInterceptor` (adapter + retrier):
/// - `adapt` is a pass-through, leaving the outgoing request untouched.
/// - `retry` validates every failing response through the CoreDataDome SDK. When a request fails
///   validation (e.g. a `403` DataDome challenge flagged by Alamofire's `.validate()`), the SDK
///   presents the challenge/block page and resolves it; the request is retried only when the SDK
///   reports that a challenge was resolved.
///
/// Attach an instance directly to a request or session as the `RequestInterceptor`:
/// ```swift
/// let interceptor = DataDomeInterceptor(dataDome: dataDome)
/// session.request(url, interceptor: interceptor)
/// ```
public final class DataDomeInterceptor: RequestInterceptor, Sendable {
    /// The CoreDataDome SDK instance used to validate responses.
    private let dataDome: DataDome

    /// Creates an interceptor backed by the provided CoreDataDome SDK instance.
    /// - Parameter dataDome: The `DataDome` instance that validates intercepted responses.
    public init(dataDome: DataDome) {
        self.dataDome = dataDome
    }

    // MARK: - RequestAdapter

    /// Called before the request is fired. The request is forwarded unchanged.
    /// - Parameters:
    ///   - urlRequest: The request about to be sent.
    ///   - session: The session firing the request.
    ///   - completion: The completion handler.
    public func adapt(_ urlRequest: URLRequest,
                      for session: Session,
                      completion: @escaping @Sendable (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }

    // MARK: - RequestRetrier

    /// Called when a request finishes with an error. The response is validated through DataDome and
    /// retried only when the SDK resolves a challenge.
    /// - Parameters:
    ///   - request: The underlying request.
    ///   - session: The session used to fire the request.
    ///   - error: The error that triggered this call.
    ///   - completion: The completion handler producing the retry decision.
    public func retry(_ request: Request,
                      for session: Session,
                      dueTo error: Error,
                      completion: @escaping @Sendable (RetryResult) -> Void) {
        guard let url = request.request?.url,
              let httpResponse = request.response else {
            completion(.doNotRetry)
            return
        }

        let dataRequest = request as? DataRequest
        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
        
        let ddResponse = DataDomeResponse(statusCode: httpResponse.statusCode,
                                          headers: headers,
                                          bodyProvider: { dataRequest?.data })

        let dataDome = self.dataDome
        Task {
            switch await dataDome.validateResponse(ddResponse, requestURL: url) {
            case .needRetry:
                // A challenge was resolved and a fresh cookie is set; retry the request.
                completion(.retry)
            case .allowed, .blocked, .error:
                // Not a DataDome challenge, hard-blocked, or validation error: let the original
                // result/error propagate to the caller.
                completion(.doNotRetry)
            @unknown default:
                completion(.doNotRetry)
            }
        }
    }
}
