//
//  AlamofireAdapter.swift
//  DataDomeAlamofire
//
//  Created by Med Hajlaoui on 07/07/2020.
//  Copyright © 2020 DataDome. All rights reserved.
//

import Foundation
import UIKit
import Alamofire
import DataDomeSDK

private typealias AlamofireCompletion = (Alamofire.RetryResult) -> Void

/// DataDome plugin integration using Alamofire request Adapter/Retrier
open class AlamofireAdapter: DataDomeAdapter {
    
    public required init() {
    }
    
    
    // MARK: - RequestRetrier
    
    /// A disctionary to store alamofire completion handlers
    private let completions = SynchronizedDictionary<String, AlamofireCompletion>()
    
    /// Called each time a request is processed
    /// - Parameters:
    ///   - request: The underlined request
    ///   - session: The session used to fire the request
    ///   - error: The error leading to this call
    ///   - completion: The completion handler
    public func retry(_ request: Alamofire.Request,
                      for session: Alamofire.Session,
                      dueTo error: Error,
                      completion: @escaping (Alamofire.RetryResult) -> Void) {
                
        // Validate the underline networking layer wrapped by Alamofire
        let urlSession = session.session
        guard let urlTask = request.task,
            let urlRequest = request.request else {
            completion(.doNotRetry)
            return
        }
        
        // Cache the callback to conform to the standard validation workflow
        let callback = Callback(request: urlRequest, task: urlTask, session: urlSession)
        CacheManager.shared.cache(callback: callback)
        
        // Cache the completion handler
        let identifier = urlTask.uniqueIdentifier()
        self.completions[identifier] = completion
        
        let data = (request as? Alamofire.DataRequest)?.data
        let response = urlTask.response
        let prototype = CompletionPrototype(data: data, response: response, error: error)
        let filter = ResponseFilter(request: urlRequest, session: urlSession, prototype: prototype, filterDelegate: self)
        self.validate(filter: filter)
    }
    
    /// Validate the input filter
    /// - Parameter filter: The filter to validate
    open func validate(filter: ResponseFilter) {
        filter.validate(mode: .alamofire)
    }
}

// MARK: - RequestAdapter
extension AlamofireAdapter: RequestRetrier {
    
    /// Called before the actual request call. We add to the request a custom user agent for debug purpose.
    /// To force DataDome to simulate a bot, use BLOCKUA as user agent by adding it to the environment variables
    /// - Parameters:
    ///   - urlRequest: The request
    ///   - session: The url session
    ///   - completion: The completion handler
    public func adapt(_ urlRequest: URLRequest,
                      for session: Alamofire.Session,
                      completion: @escaping (Result<URLRequest, Error>) -> Void) {
        
        var request = urlRequest
        
        // Add custom user agent if specified in environment variable for debug purposes
        if let header = ProcessInfo().environment["DATADOME_USER_AGENT"] {
            request.addValue(header, forHTTPHeaderField: "User-Agent")
        }
        
        return completion(.success(request))
    }
}

extension AlamofireAdapter: FilterDelegate {
    
    /// Called when the request should be ignore. Mainly when non protected requests produces error
    /// should be ignored and not retried
    /// - Parameters:
    ///   - task: The original task
    ///   - request: The underlined request
    @objc
    open func filter(task: URLSessionTask, shouldIgnore request: URLRequest) {
        let identifier = task.uniqueIdentifier()
        let completion = self.completions[identifier]
        self.completions.removeValue(forKey: identifier)
        
        // Do not retry this request, it should be ignored
        completion?(.doNotRetry)
    }
    
    /// Called when a request failed with an actual error.
    /// Should not be retried by the error should be reported
    /// - Parameters:
    ///   - task: The original task
    ///   - request: The underlined request
    @objc
    open func filter(task: URLSessionTask, didFailWith error: Error) {
        let identifier = task.uniqueIdentifier()
        let completion = self.completions[identifier]
        
        // Do not retry the request since it failed with an error
        completion?(.doNotRetryWithError(error))
    }
    
    /// Called when a captcha is validated. Several requests are queued and need to be retried
    /// - Parameters:
    ///   - task: The original task
    ///   - request: The underlined request
    @objc
    open func filter(task: URLSessionTask, didResolveCaptcha cookie: String) {
        Logger.info("Did resolve captcha with new cookie '\(cookie)'")
        EventTracker.shared.log(.captchaSuccess)
        
        // retry all pending requests
        Logger.info("Retrying failed requests")
        for identifier in self.completions.keys {
            let request = task.currentRequest
            EventTracker.shared.log(request: request, integrationMode: .alamofire)
            
            let completion = self.completions[identifier]
            self.completions.removeValue(forKey: identifier)
            
            // Retry the request since the captcha is validated and a new cookie is generated
            completion?(.retry)
        }
    }
}
