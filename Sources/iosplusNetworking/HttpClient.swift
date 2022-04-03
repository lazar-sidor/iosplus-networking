//
//  HttpClient.swift
//  
//
//  Created by Lazar Sidor on 04.01.2022.
//

import Foundation

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

    static func isValid(from response: HTTPURLResponse) -> Bool {
        return (200...299).contains(response.statusCode)
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A dictionary of headers to apply to a `URLRequest`.
public typealias HTTPHeaders = [String: String]

public enum HTTPContentType: String {
    case applicationJson = "application/json"
}

public enum HTTPResponseType: Int {
    case empty
    case singleItem
    case collection
}

public class HttpMultipartBody: NSObject {
    public var params: HTTPHeaders?
    public var data: Data?
    public var bodyName: String = "file"
    public var fileName: String?
    public var mimeType: String?

    public override init() {
        super.init()
    }
}

public enum ApiErrorCode: LocalizedError {
    case custom(code: Int, message: String?)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .custom(let code, let message):
            if let message = message {
                return message
            } else {
                return "Internal error with code: \(code)"
            }
        case .unknown: return "Unhandled error code"
        }
    }
}

public struct ApiEndpoint {
    public var route: ApiRoute
    public var httpMethod: HTTPMethod = .get
    public var httpResponseType: HTTPResponseType = .empty
    
    public init(route: ApiRoute,
                httpMethod: HTTPMethod = .get,
                httpResponseType: HTTPResponseType = .empty) {
        self.route = route
        self.httpMethod = httpMethod
        self.httpResponseType = httpResponseType
    }
}

public struct ApiRequest {
    public var endpoint: ApiEndpoint
    public var contentType: HTTPContentType = .applicationJson
    public var headerParams: HTTPHeaders = [:]
    public var inputJSONParams: Any? = nil

    public init(endpoint: ApiEndpoint,
                contentType: HTTPContentType = .applicationJson,
                headerParams: HTTPHeaders = [:],
                inputJSONParams: Any? = nil) {
        self.endpoint = endpoint
        self.contentType = contentType
        self.headerParams = headerParams
        self.inputJSONParams = inputJSONParams
    }
}

public struct ApiRoute {
    private var baseUrl: URL!
    private var path: String!
    
    public init(baseUrlPath: String, path: String) {
        self.baseUrl = URL.init(string: baseUrlPath)
        self.path = path
    }
    
    public func url() -> URL {
        return baseUrl.appendingPathComponent(path)
    }
}

public enum ApiResult<T> {
    case fulfilledEmpty
    case fulfilledSingle(T)
    case fulfilledCollection([T])
    case rejected(Error?)
    
    public var isFulfilled: Bool {
        switch self {
        case .fulfilledSingle, .fulfilledCollection, .fulfilledEmpty:
            return true
        case .rejected:
            return false
        }
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
    
    public func executeDataRequest<T: Codable>(
        url: URL,
        httpMethod: HTTPMethod = .get,
        contentType: HTTPContentType = .applicationJson,
        headerParams: HTTPHeaders = [:],
        inputJSON: Any? = nil,
        inputObject: T? = nil,
        responseType: HTTPResponseType = .empty,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        let executionBlock = { (request: NSMutableURLRequest) in
            if httpMethod == .delete {
                self.invokeDeleteDataTask(request as URLRequest) { response, responseData, responseError in
                    DispatchQueue.main.async {
                        if let responseError = responseError {
                            completion(ApiResult.rejected(responseError))
                        } else {
                            completion(ApiResult.fulfilledEmpty)
                        }
                    }
                }
                return
            }

            self.invokeDataTask(request as URLRequest,
                                successCompletion: { taskResponse, data in
                if data == nil {
                    DispatchQueue.main.async {
                        completion(ApiResult.fulfilledEmpty)
                    }

                } else {
                    var outputData: Data = data!
                    var customOutputError: NSError? = nil
                    do {
                        if let processedData = self.configuration.processResponseData(data!, request as URLRequest, taskResponse) {
                            outputData = try JSONSerialization.data(withJSONObject: processedData, options: .prettyPrinted)
                        }

                        if let processedErrors = self.configuration.processResponseErrors(data!, request as URLRequest) {
                            customOutputError = processedErrors.first
                        }
                    } catch {
                        self.httpLogger.reportError(error.localizedDescription)
                        DispatchQueue.main.async {
                            completion(ApiResult.rejected(error))
                        }
                    }

                    if responseType == .empty {
                        DispatchQueue.main.async {
                            completion(ApiResult.fulfilledEmpty)
                        }
                    }
                    else if responseType == .collection {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.iso8601
                            let apiObjects = try decoder.decode([T].self, from: outputData)

                            DispatchQueue.main.async {
                                completion(ApiResult.fulfilledCollection(apiObjects))
                            }

                        } catch {
                            self.httpLogger.reportError(error.localizedDescription)
                            DispatchQueue.main.async {
                                completion(ApiResult.rejected(error))
                            }
                        }
                    } else if responseType == .singleItem {

                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.iso8601
                            let apiObject: T = try decoder.decode(T.self, from: outputData)
                            DispatchQueue.main.async {
                                completion(ApiResult.fulfilledSingle(apiObject))
                            }
                        } catch {
                            self.httpLogger.reportError(error.localizedDescription)
                            DispatchQueue.main.async {
                                completion(ApiResult.rejected(error))
                            }
                        }

                    } else {
                        DispatchQueue.main.async {
                            if let responseError = customOutputError {
                                completion(ApiResult.rejected(responseError))
                            } else {
                                completion(ApiResult.fulfilledEmpty)
                            }
                        }
                    }
                }
            }, failureCompletion: { apiError in
                DispatchQueue.main.async {
                    completion(ApiResult.rejected(apiError))
                }
            })
        }

        prepareRequest(url: url, httpMethod: httpMethod, contentType: contentType, headerParams: headerParams, inputJSON: inputJSON, inputObject: inputObject, responseType: responseType) { mutableRequest in
            executionBlock(mutableRequest)
        }
    }
}

// MARK: - Private
private extension HttpClient {
    private func prepareRequest<T: Codable>(
        url: URL,
        httpMethod: HTTPMethod,
        contentType: HTTPContentType,
        headerParams: HTTPHeaders,
        inputJSON: Any?,
        inputObject: T?,
        responseType: HTTPResponseType, completion: ((_ mutableRequest: NSMutableURLRequest) -> Void)) {
            let request = NSMutableURLRequest(url: url)
            request.httpMethod = httpMethod.rawValue
            request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")

            let prepareRequestBlock = { [self] (headers: [String: String]) in
                // Add default header params
                for key in headers.keys {
                    if let value = headers[key] {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                }

                // Add custom header params
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
            }

            configuration.prepareHTTPHeaders(for: request as URLRequest) { (headers: [String: String]) in
                prepareRequestBlock(headers)
                completion(request)
            }
        }

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
            httpLogger.didReceive(httpResponse, responseData: data, target: request.url!)
            configuration.handleHTTPStatusCode(httpResponse.statusCode)

            if HTTPStatus.isValid(from: httpResponse) == false {
                if completion != nil {
                    completion!(apiResponse, data, taskError)
                }
                return
            }
        }
        
        if taskError != nil && completion != nil {
            self.httpLogger.reportError(taskError!.localizedDescription)
            completion!(apiResponse, data, taskError)
            
        } else if completion != nil {
            completion!(apiResponse, data, nil)
        }
    }
    
    private func handleDeleteTaskExecution(request: URLRequest,
                                           data: Data?,
                                           apiResponse: URLResponse?,
                                           taskError: Error?,
                                           completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?) -> Void)?) {
        if apiResponse != nil && taskError == nil && data != nil {
            let httpResponse = apiResponse as! HTTPURLResponse
            httpLogger.didReceive(httpResponse, responseData: data, target: request.url!)
            configuration.handleHTTPStatusCode(httpResponse.statusCode)

            if HTTPStatus.isValid(from: httpResponse) == false {
                if completion != nil {
                    completion!(apiResponse, data, taskError)
                }
                return
            }
        }
        
        if taskError != nil && completion != nil {
            self.httpLogger.reportError(taskError!.localizedDescription)
            completion!(apiResponse, data, taskError)
            
        } else if completion != nil {
            completion!(apiResponse, data, nil)
        }
    }
}


