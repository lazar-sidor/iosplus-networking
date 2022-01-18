//
//  HttpClient.swift
//  
//
//  Created by Lazar Sidor on 04.01.2022.
//

import UIKit

public enum HTTPStatus: Int {
    case ok = 200
    case noContent = 204
    case badRequest = 400
    case notAuthorized = 401
    case forbidden = 403
    case notFound = 404
    case internalServerError = 500
    
    func asString() -> String? {
        switch self {
        case .ok:
            return "OK"
        case .noContent:
            return "No Content"
        case .badRequest:
            return "Bad Request"
        case .notAuthorized:
            return "Not Authorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not Found"
        case .internalServerError:
            return "Internal Server Error"
        }
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

public enum HTTPContentType: String {
    case applicationJson = "application/json"
}

public enum HTTPResponseType: Int {
    case empty
    case singleItem
    case collection
}

public struct ApiEndpoint {
    public var route: ApiRoute!
    public var httpMethod: HTTPMethod = .get
    public var contentType: HTTPContentType = .applicationJson
    public var headerParams: [String: String] = [:]
    public var inputJSONParams: Any? = nil
    public var httpResponseType: HTTPResponseType = .empty
    
    public init(route: ApiRoute,
                httpMethod: HTTPMethod = .get,
                contentType: HTTPContentType = .applicationJson,
                headerParams: [String: String] = [:],
                inputJSONParams: Any? = nil,
                httpResponseType: HTTPResponseType = .empty) {
        self.route = route
        self.httpMethod = httpMethod
        self.contentType = contentType
        self.headerParams = headerParams
        self.inputJSONParams = inputJSONParams
        self.httpResponseType = httpResponseType
    }
}

public struct ApiRoute {
    var baseUrl: URL!
    var path: String!
    
    public init(baseUrlPath: String, path:String) {
        self.baseUrl = URL.init(string: baseUrlPath)
        self.path = path
    }
    
    func url() -> URL {
        return baseUrl.appendingPathComponent(path)
    }
}

public class HttpClient {
    public var configuration: HttpClientConfiguration!
    private var httpLogger: HttpNetworkAPILogger!
    
    public convenience init(configuration: HttpClientConfiguration) {
        self.init()
        self.configuration = configuration
        self.httpLogger = HttpNetworkAPILogger(logger: configuration,
                                               verbose: true,
                                               requestDataFormatter: HttpNetworkAPILogger.JSONRequestDataFormatter,
                                               responseDataFormatter: HttpNetworkAPILogger.JSONResponseDataFormatter)
    }
    
    public init() {
        self.configuration = HttpClientConfiguration()
    }
    
    public func executeDataRequest<I: Encodable, O: Decodable>(url: URL,
                                                               httpMethod: HTTPMethod = .get,
                                                               contentType: HTTPContentType = .applicationJson,
                                                               headerParams: [String: String] = [:],
                                                               inputJSON: Any? = nil,
                                                               inputObject: I? = nil,
                                                               outputObject: O? = nil,
                                                               responseType: HTTPResponseType = .empty,
                                                               completion: @escaping ((_ response: Any?, _ responseError: Error?) -> Void)) {
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        
        for key in headerParams.keys {
            if let value = headerParams[key] {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let jsonObject = inputJSON {
            if jsonObject is [String: Any] || jsonObject is [[String: Any]] {
                do {
                    let body = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
                    request.httpBody = body
                    
                } catch {
                    httpLogger.reportError("Error converting model class to JSON")
                }
            }
        }
        else if let dataViewObject = inputObject {
            do {
                let jsonEncoder = JSONEncoder()
                jsonEncoder.dateEncodingStrategy = JSONEncoder.DateEncodingStrategy.iso8601
                let jsonData = try jsonEncoder.encode(dataViewObject)
                request.httpBody = jsonData
                
            } catch {
                httpLogger.reportError("Error converting model class to Dictionary")
            }
        }
        
        if httpMethod == .delete {
            invokeDeleteDataTask(request as URLRequest) { response, responseData, responseError in
                completion(response, responseError)
            }
            return
        }
        
        invokeDataTask(request as URLRequest,
                       successCompletion: { _, data in
            if data == nil {
                completion(nil, nil)
                
            } else {
                var outputData: Data = data!
                var customOutputError: NSError? = nil
                do {
                    if let processedData = self.configuration.processResponseData(data!) {
                        outputData = try JSONSerialization.data(withJSONObject: processedData, options: .prettyPrinted)
                    }
                    
                    if let processedErrors = self.configuration.processResponseErrors(data!) {
                        customOutputError = processedErrors.first
                    }
                } catch {
                    self.httpLogger.reportError(error.localizedDescription)
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
                
                if responseType == .collection {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.iso8601
                        let apiObjects: [O] = try decoder.decode([O].self, from: outputData)
                        
                        DispatchQueue.main.async {
                            completion(apiObjects, customOutputError)
                        }
                        
                    } catch {
                        self.httpLogger.reportError(error.localizedDescription)
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                    }
                } else if responseType == .singleItem {
                                       
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.iso8601
                        let apiObject: O = try decoder.decode(O.self, from: outputData)
                        
                        DispatchQueue.main.async {
                            completion(apiObject, customOutputError)
                        }
                    } catch {
                        self.httpLogger.reportError(error.localizedDescription)
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        completion(nil, customOutputError)
                    }
                }
            }
        }, failureCompletion: { apiError in
            DispatchQueue.main.async {
                completion(nil, apiError)
            }
        })
    }
    
}

extension HttpClient {
    private func invokeDataTask(_ request: URLRequest,
                                successCompletion: ((_ response: Any?, _ data: Data?) -> Void)?,
                                failureCompletion: ((_ responseError: Error?) -> Void)?) {
        httpLogger.willSend(request)
        
        let sessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?, apiResponse: URLResponse?, taskError: Error?) -> Void in
            
            self.handleDataTaskExecution(request: request, data: data, apiResponse: apiResponse, taskError: taskError) { taskResponse, responseData, responseError in
                if let error = responseError {
                    if failureCompletion != nil {
                        failureCompletion!(error)
                    }
                } else {
                    if successCompletion != nil {
                        successCompletion!(apiResponse, data)
                    }
                }
            }
        }
        
        sessionDataTask.resume()
    }
    
    private func invokeDeleteDataTask(_ request: URLRequest,
                                      completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?) -> Void)?) {
        
        httpLogger.willSend(request)
        
        let sessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?, apiResponse: URLResponse?, taskError: Error?) -> Void in
            self.handleDeleteTaskExecution(request: request, data: data, apiResponse: apiResponse, taskError: taskError, completion: completion)
        }
        
        sessionDataTask.resume()
    }
    
    private func invokeUploadTask(_ request: URLRequest,
                                  binaryData: Data,
                                  successCompletion: ((_ response: Any?, _ data: Data?) -> Void)?,
                                  failureCompletion: ((_ responseError: Error?) -> Void)?) {
        
        httpLogger.willSend(request)
        
        let sessionDataTask = URLSession.shared.uploadTask(with: request, from: binaryData) { (data: Data?, apiResponse: URLResponse?, taskError: Error?) -> Void in
            
            self.handleDataTaskExecution(request: request, data: data, apiResponse: apiResponse, taskError: taskError) { taskResponse, responseData, responseError in
                
                if let error = responseError {
                    if failureCompletion != nil {
                        failureCompletion!(error)
                    }
                } else {
                    if successCompletion != nil {
                        successCompletion!(apiResponse, data)
                    }
                }
            }
        }
        
        sessionDataTask.resume()
    }
    
    private func handleDataTaskExecution(request: URLRequest,
                                         data: Data?,
                                         apiResponse: URLResponse?,
                                         taskError: Error?,
                                         completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?) -> Void)?) {
        if apiResponse != nil && taskError == nil && data != nil {
            
            let httpResponse = apiResponse as! HTTPURLResponse
            let status: NSInteger = httpResponse.statusCode
            
            httpLogger.didReceive(httpResponse, responseData: data, target: request.url!)
            
            if status != HTTPStatus.ok.rawValue && status != HTTPStatus.noContent.rawValue {
                if status == HTTPStatus.notAuthorized.rawValue {
                    
                    DispatchQueue.main.async {
                        if completion != nil {
                            completion!(apiResponse, data, taskError)
                        }
                    }
                    return
                }
            }
        }
        
        if taskError != nil && completion != nil {
            self.httpLogger.reportError(taskError!.localizedDescription)
            DispatchQueue.main.async {
                completion!(apiResponse, data, taskError)
            }
            
        } else if completion != nil {
            DispatchQueue.main.async {
                completion!(apiResponse, data, nil)
            }
        }
    }
    
    private func handleDeleteTaskExecution(request: URLRequest,
                                           data: Data?,
                                           apiResponse: URLResponse?,
                                           taskError: Error?,
                                           completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?) -> Void)?) {
        if apiResponse != nil && taskError == nil && data != nil {
            let httpResponse = apiResponse as! HTTPURLResponse
            let status: NSInteger = httpResponse.statusCode
            
            httpLogger.didReceive(httpResponse, responseData: data, target: request.url!)
            
            if status != HTTPStatus.ok.rawValue && status != HTTPStatus.noContent.rawValue {
                
                if status == HTTPStatus.notAuthorized.rawValue {
                    DispatchQueue.main.async {
                        if completion != nil {
                            completion!(apiResponse, data, taskError)
                        }
                    }
                    return
                }
            }
        }
        
        if taskError != nil && completion != nil {
            self.httpLogger.reportError(taskError!.localizedDescription)
            DispatchQueue.main.async {
                completion!(apiResponse, data, taskError)
            }
            
        } else if completion != nil {
            DispatchQueue.main.async {
                completion!(apiResponse, data, nil)
            }
        }
    }
}


