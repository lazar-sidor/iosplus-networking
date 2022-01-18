//
//  File.swift
//  
//
//  Created by Lazar Sidor on 07.01.2022.
//

import Foundation

public protocol HttpClientLoggingInterface: AnyObject {
    func logRequest()
    func logError(_ error: Error)
}

public protocol HttpLoggerProtocol: AnyObject {
    /// Defines context for identifying log message.
    func set(identificator: String?)
    
    /// Defines functions for each of log level.
    func verbose(_ category: String, _ msg: String)
    func debug(_ category: String, _ msg: String)
    func info(_ category: String, _ msg: String)
    func warning(_ category: String, _ msg: String)
    func error(_ category: String, _ msg: String)
}

public protocol HttpClientInterface: AnyObject {
    func defaultRequestHTTPHeaders() -> [String: String]
    func processResponseData(_ data: Data) -> Any?
    func processResponseErrors(_ data: Data) -> [NSError]?
}

open class DefaultHttpClientConfiguration: HttpClientInterface, HttpLoggerProtocol {
    
    // MARK: - HttpLoggerProtocol
    
    public func set(identificator: String?) {
        
    }
    
    public func verbose(_ category: String, _ msg: String) {
        print("⚪ \(msg)")
    }
    
    public func debug(_ category: String, _ msg: String) {
        print("🟢 \(msg)")
    }
    
    public func info(_ category: String, _ msg: String) {
        print("🔵 \(msg)")
    }
    
    public func warning(_ category: String, _ msg: String) {
        print("🟠 \(msg)")
    }
    
    public func error(_ category: String, _ msg: String) {
        print("🔴 \(msg)")
    }
    
    // MARK: - HttpClientInterface
    
    open func defaultRequestHTTPHeaders() -> [String : String] {
        return [:]
    }
    
    open func processResponseData(_ data: Data) -> Any? {
        return nil
    }
    
    open func processResponseErrors(_ data: Data) -> [NSError]? {
        return nil
    }
}

open class HttpClientConfiguration: DefaultHttpClientConfiguration {
    public override init() {
        super.init()
    }
}
