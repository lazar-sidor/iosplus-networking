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
    func prepareHTTPHeaders(for request: URLRequest, completion: ((_ headers: HTTPHeaders) -> Void))
    func processResponseData(_ data: Data, _ request: URLRequest, _ response: Any?) -> Any?
    func processResponseErrors(_ data: Data, _ request: URLRequest) -> [NSError]?
    func handleHTTPStatusCode(_ code: Int)
    func handleNetworkReachabilityChange(_ status: HttpNetworkReachabilityMonitor.NetworkConnection)
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
    open func prepareHTTPHeaders(for request: URLRequest, completion: ((_ headers: HTTPHeaders) -> Void)) {
        completion([:])
    }
    
    open func processResponseData(_ data: Data, _ request: URLRequest, _ response: Any?) -> Any? {
        return nil
    }
    
    open func processResponseErrors(_ data: Data, _ request: URLRequest) -> [NSError]? {
        return nil
    }

    open func handleHTTPStatusCode(_ code: Int) {}
    open func handleNetworkReachabilityChange(_ status: HttpNetworkReachabilityMonitor.NetworkConnection) {}
}

open class HttpClientConfiguration: DefaultHttpClientConfiguration {
    public override init() {
        super.init()
    }
}
