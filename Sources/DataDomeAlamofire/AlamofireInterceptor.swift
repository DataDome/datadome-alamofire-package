//
//  AlamofireInterceptor.swift
//  DataDomeAlamofire
//
//  Created by Cyril Bosselut on 05/05/2020.
//  Copyright © 2020 DataDome. All rights reserved.
//

import Foundation
import Alamofire

open class AlamofireInterceptor<T: AlamofireAdapter> {
    public let proxy: T
    public private(set) lazy var sessionAdapter: RequestAdapter = proxy
    public private(set) lazy var sessionRetrier: RequestRetrier = proxy
    
    public init() {
        self.proxy = T()
    }
}
