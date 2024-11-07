//
//  NetworkManager.swift
//  DataDomeCoreDevApplication
//
//  Created by Alexandre Brispot on 14/03/2024.
//

import Foundation

import Alamofire
import DataDomeAlamofire

enum NetworkManagerError: Error {
    case unknowned
}

final class NetworkManager {
    static var shared: NetworkManager = NetworkManager()
    
    private let alamofireSession = Alamofire.Session(configuration:  URLSessionConfiguration.default)
    private let dataDome = DataDomeAlamofire.AlamofireInterceptor(captchaDelegate: nil)
    private let interceptor: Alamofire.Interceptor

    private let headers = [
        "Accept": "application/json",
        "User-Agent": "BLOCKUA", // For testing purpose only - This will force a Captcha challenge if no DataDome cookie is present
        "Cache-Control": "max-age=0, no-cache, must-revalidate, proxy-revalidate" // For testing purpose only - This will bypass all cache
    ]
        
    private init() {
        interceptor = Interceptor(adapter: dataDome.sessionAdapter,
                                  retrier: dataDome.sessionRetrier)
    }
    
    func protectedData(from url: URL, withId id: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            alamofireSession
                .request(url, headers: HTTPHeaders(headers), interceptor: interceptor)
                .validate()
                .responseData { response in
                    switch response.result {
                    case let .success(data):
                        continuation.resume(returning: data)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}
