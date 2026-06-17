//
//  NetworkManager.swift
//  DataDomeCoreDevApplication
//
//  Created by Alexandre Brispot on 14/03/2024.
//

import Foundation

import Alamofire
import CoreDataDome
import DataDomeAlamofire

enum NetworkManagerError: Error {
    case unknowned
}

final class NetworkManager: Sendable {
    static let shared = NetworkManager()

    private let alamofireSession = Alamofire.Session(configuration:  URLSessionConfiguration.default)
    private let dataDome: DataDome
    private let interceptor: DataDomeInterceptor

    private let headers = [
        "Accept": "application/json",
        "User-Agent": "BLOCKUA", // For testing purpose only - This will force a Captcha challenge if no DataDome cookie is present
        "Cache-Control": "max-age=0, no-cache, must-revalidate, proxy-revalidate" // For testing purpose only - This will bypass all cache
    ]

    private init() {
        // Reads the client-side key (and optional domain) from the app's Info.plist `DataDome` dictionary.
        let configuration = try! DataDomeConfiguration.configurationFromBundle()
        dataDome = DataDome(configuration: configuration)
        interceptor = DataDomeInterceptor(dataDome: dataDome)
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

    /// Clears the DataDome cookie from both the shared HTTP cookie storage and the WKWebView store.
    func clearCookies() async {
        await dataDome.unsafeClearCachedData()
    }
}
