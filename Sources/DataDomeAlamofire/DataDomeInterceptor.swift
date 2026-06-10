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

    /// Called before the request is fired.
    ///
    /// - If the request carries no `Cookie` header (or has no URL), it is forwarded unchanged.
    /// - Otherwise the current DataDome cookie is fetched from the SDK and merged into the header:
    ///   an existing DataDome entry has its value replaced in place, otherwise the cookie is appended.
    ///   All other cookies are preserved in their original order. When the SDK has no cookie yet, the
    ///   request is forwarded unchanged.
    /// - Parameters:
    ///   - urlRequest: The request about to be sent.
    ///   - session: The session firing the request.
    ///   - completion: The completion handler.
    public func adapt(_ urlRequest: URLRequest,
                      for session: Session,
                      completion: @escaping @Sendable (Result<URLRequest, Error>) -> Void) {
        // Foundation header lookup is case-insensitive.
        guard let cookieHeader = urlRequest.value(forHTTPHeaderField: "Cookie"),
              let url = urlRequest.url else {
            completion(.success(urlRequest))
            return
        }

        Task {
            guard let cookie = await self.dataDome.getCookie(forURL: url) else {
                // SDK has no cookie yet: leave the caller's Cookie header untouched.
                completion(.success(urlRequest))
                return
            }

            var modifiedRequest = urlRequest
            let merged = Self.mergeCookie(into: cookieHeader, name: cookie.name, value: cookie.value)
            modifiedRequest.setValue(merged, forHTTPHeaderField: "Cookie")
            completion(.success(modifiedRequest))
        }
    }

    /// Merges a single cookie into an existing `Cookie` header value.
    ///
    /// Cookies are matched by exact name (the token before the first `=`), so a name that is a prefix
    /// of another (e.g. `datadome` vs `datadome_x`) is not mistaken for a match. An existing entry has
    /// its value replaced in place, preserving order; otherwise the cookie is appended.
    /// - Parameters:
    ///   - header: The original `Cookie` header value, e.g. `"a=1; datadome=old; b=2"`.
    ///   - name: The cookie name to merge.
    ///   - value: The new value for that cookie.
    /// - Returns: The rebuilt `Cookie` header value, e.g. `"a=1; datadome=new; b=2"`.
    static func mergeCookie(into header: String, name: String, value: String) -> String {
        var pairs: [(name: String, value: String)] = header
            .split(separator: ";")
            .compactMap { segment in
                let trimmed = segment.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                if let eq = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[trimmed.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
                    let val = String(trimmed[trimmed.index(after: eq)...])
                    return (key, val)
                }
                return (trimmed, "")
            }

        if let idx = pairs.firstIndex(where: { $0.name == name }) {
            pairs[idx].value = value
        } else {
            pairs.append((name, value))
        }

        return pairs.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
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

        let body = (request as? DataRequest)?.data
        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
        let ddResponse = DataDomeResponse(statusCode: httpResponse.statusCode,
                                          headers: headers,
                                          body: body)

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
