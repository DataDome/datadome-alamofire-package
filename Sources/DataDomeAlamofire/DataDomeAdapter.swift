//
//  DataDomeAdapter.swift
//  DataDomeAlamofire
//
//  Created by Med Hajlaoui on 09/07/2020.
//  Copyright © 2020 DataDome. All rights reserved.
//

import Foundation
import Alamofire
import DataDomeSDK

public protocol DataDomeAdapter: Alamofire.RequestAdapter {
    func validate(filter: ResponseFilter)
}
