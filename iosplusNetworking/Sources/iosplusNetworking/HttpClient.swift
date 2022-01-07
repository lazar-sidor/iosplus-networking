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

public enum HTTPCustomErrorCode: Int {
    case failedToDecodeResponse = 1
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
    var route: ApiRoute!
    var httpMethod: HTTPMethod = .get
    var contentType: HTTPContentType = .applicationJson
    var headerParams: [String: String] = [:]
    var inputJSONParams: Any? = nil
    var httpResponseType: HTTPResponseType = .empty
}

public struct ApiRoute {
    var baseUrl: URL!
    var path: String!
    
    init(baseUrlPath: String, path:String) {
        self.baseUrl = URL.init(string: baseUrlPath)
        self.path = path
    }
    
    func url() -> URL {
        return baseUrl.appendingPathComponent(path)
    }
}

public class HttpClient {
    private var configuration: HttpClientConfiguration!
    
    convenience init(configuration: HttpClientConfiguration) {
        self.init()
        self.configuration = configuration
    }
    
    init() {
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
                                                               completion: @escaping ((_ response: Any?, _ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)) {
        
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
                    print("Error converting model class to JSON")
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
                print("Error converting model class to Dictionary")
            }
        }
        
        if httpMethod == .delete {
            invokeDeleteDataTask(request as URLRequest) { response, responseData, responseError, errorCode in
                completion(response, responseError, errorCode)
            }
            return
        }
        
        invokeDataTask(request as URLRequest,
                       successCompletion: { _, data in
            if data == nil {
                completion(nil, nil, nil)
                
            } else {
                if responseType == .collection {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.iso8601
                        let apiObjects: [O] = try decoder.decode([O].self, from: data!)
                        
                        DispatchQueue.main.async {
                            completion(apiObjects, nil, nil)
                        }
                        
                    } catch {
                        print(error)
                        
                        DispatchQueue.main.async {
                            completion(nil, error, nil)
                        }
                    }
                } else if responseType == .singleItem {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.iso8601
                        let apiObject: O = try decoder.decode(O.self, from: data!)
                        
                        DispatchQueue.main.async {
                            completion(apiObject, nil, nil)
                        }
                    } catch {
                        print(error)
                        DispatchQueue.main.async {
                            completion(nil, error, nil)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, nil, nil)
                    }
                }
            }
        }, failureCompletion: { apiError, errCode in
            DispatchQueue.main.async {
                completion(nil, apiError, errCode)
            }
        })
    }
    
}

extension HttpClient {
    private func invokeDataTask(_ request: URLRequest,
                                successCompletion: ((_ response: Any?, _ data: Data?) -> Void)?,
                                failureCompletion: ((_ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)?) {
        let sessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?, apiResponse: URLResponse?, taskError: Error?) -> Void in
            self.handleDataTaskExecution(data: data, apiResponse: apiResponse, taskError: taskError) { taskResponse, responseData, responseError, errorCode in
                if let error = responseError {
                    if failureCompletion != nil {
                        failureCompletion!(error, errorCode)
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
                                      completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)?) {
        let sessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?, apiResponse: URLResponse?, taskError: Error?) -> Void in
            self.handleDeleteTaskExecution(data: data, apiResponse: apiResponse, taskError: taskError, completion: completion)
        }
        
        sessionDataTask.resume()
    }
    
    private func invokeUploadTask(_ request: URLRequest,
                                  binaryData: Data,
                                  successCompletion: ((_ response: Any?, _ data: Data?) -> Void)?,
                                  failureCompletion: ((_ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)?) {
        let sessionDataTask = URLSession.shared.uploadTask(with: request, from: binaryData) { (data: Data?, apiResponse: URLResponse?, taskError: Error?) -> Void in
            self.handleDataTaskExecution(data: data, apiResponse: apiResponse, taskError: taskError) { taskResponse, responseData, responseError, errorCode in
                if let error = responseError {
                    if failureCompletion != nil {
                        failureCompletion!(error, errorCode)
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
    
    private func handleDataTaskExecution(data: Data?,
                                         apiResponse: URLResponse?,
                                         taskError: Error?,
                                         completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)?) {
        if apiResponse != nil && taskError == nil && data != nil {
            let httpResponse = apiResponse as! HTTPURLResponse
            let status: NSInteger = httpResponse.statusCode
            
            if status != HTTPStatus.ok.rawValue && status != HTTPStatus.noContent.rawValue {
                print(httpResponse)
                
                if status == HTTPStatus.notAuthorized.rawValue {
                    DispatchQueue.main.async {
                        if completion != nil {
                            completion!(apiResponse, data, taskError, nil)
                        }
                    }
                    return
                }
            }
        }
        
        if taskError != nil && completion != nil {
            DispatchQueue.main.async {
                completion!(apiResponse, data, taskError, .failedToDecodeResponse)
            }
            
        } else if completion != nil {
            DispatchQueue.main.async {
                completion!(apiResponse, data, nil, nil)
            }
        }
    }
    
    private func handleDeleteTaskExecution(data: Data?,
                                           apiResponse: URLResponse?,
                                           taskError: Error?,
                                           completion: ((_ response:Any?, _ responseData: Data?, _ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)?) {
        if apiResponse != nil && taskError == nil && data != nil {
            let httpResponse = apiResponse as! HTTPURLResponse
            let status: NSInteger = httpResponse.statusCode
            
            if status != HTTPStatus.ok.rawValue && status != HTTPStatus.noContent.rawValue {
                print(httpResponse)
                
                if status == HTTPStatus.notAuthorized.rawValue {
                    DispatchQueue.main.async {
                        if completion != nil {
                            completion!(apiResponse, data, taskError, nil)
                        }
                    }
                    return
                }
            }
        }
        
        if taskError != nil && completion != nil {
            DispatchQueue.main.async {
                completion!(apiResponse, data, taskError, .failedToDecodeResponse)
            }
            
        } else if completion != nil {
            DispatchQueue.main.async {
                completion!(apiResponse, data, nil, nil)
            }
        }
    }
}


