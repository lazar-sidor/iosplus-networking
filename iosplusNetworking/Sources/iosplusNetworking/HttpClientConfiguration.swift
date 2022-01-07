//
//  File.swift
//  
//
//  Created by Lazar Sidor on 07.01.2022.
//

import Foundation

public protocol HttpClientInterface: AnyObject {
    func defaultRequestHTTPHeaders() -> [String: String]
}

public class DefaultHttpClientConfiguration: HttpClientInterface {
    public func defaultRequestHTTPHeaders() -> [String : String] {
        return [:]
    }
}

public class HttpClientConfiguration: DefaultHttpClientConfiguration {
    
}
