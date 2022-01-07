//
//  File.swift
//  
//
//  Created by Lazar Sidor on 07.01.2022.
//

import Foundation

public protocol HttpClientInterface: AnyObject {
    func defaultRequestHeaders() -> [String: String]
}

public class DefaultHttpClientConfiguration: HttpClientInterface {
    public func defaultRequestHeaders() -> [String : String] {
        return [:]
    }
}

public final class HttpClientConfiguration: DefaultHttpClientConfiguration {
    
}
