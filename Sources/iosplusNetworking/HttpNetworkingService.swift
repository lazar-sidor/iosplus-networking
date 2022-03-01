//
//  HttpRequestManager.swift
//  
//
//  Created by Lazar Sidor on 07.01.2022.
//

import UIKit

public class HttpNetworkingService: NSObject {
    private var httpClient: HttpClient!
    
    public convenience init(httpClientConfiguration: HttpClientConfiguration) {
        self.init()
        self.httpClient = HttpClient(configuration: httpClientConfiguration)
    }
    
    public convenience init(httpClient: HttpClient) {
        self.init()
        self.httpClient = httpClient
    }
    
    public override init() {
        super.init()
        self.httpClient = HttpClient(configuration: HttpClientConfiguration())
    }

    public func executeDataRequest<T: Codable>(_ request: ApiRequest, inputObject: T? = nil, completion: @escaping (ApiResult<T>) -> Void) {
        httpClient.executeDataRequest(
            url: request.endpoint.route.url(),
            httpMethod: request.endpoint.httpMethod,
            contentType: request.contentType,
            headerParams: request.headerParams,
            inputJSON: request.inputJSONParams,
            inputObject: inputObject,
            responseType: request.endpoint.httpResponseType,
            completion: completion
        )
    }

    public func executeDeleteRequest<T: Codable>(_ request: ApiRequest, inputObject: T? = nil, outputObjectType: AnyClass?, completion: @escaping (ApiResult<T>) -> Void) {
        httpClient.executeDataRequest(url: request.endpoint.route.url(),
                                      httpMethod: .delete,
                                      inputObject: inputObject,
                                      completion: completion)
    }
}

/*
// Sample of usage
 
class User: NSObject, Codable {
   // some properties
}

class TestApiService {
    class func sampleEndpointCall(with completion: @escaping (ApiResult<User>) -> Void) {
        let service: HttpNetworkingService = HttpNetworkingService(httpClientConfiguration: HttpClientConfiguration())
        let endpoint: ApiEndpoint = ApiEndpoint(route: ApiRoute(baseUrlPath: "someBaseUrl", path: "somePath"))
        let apiRequest = ApiRequest(endpoint: endpoint)
        service.executeDataRequest(apiRequest, inputObject: nil) { (response: ApiResult<User>) in
            switch response {
            case .fulfilledEmpty:
                // code
                break
            case .fulfilledSingle(let t):
                // code
                break
            case .fulfilledCollection(let array):
                // code
                break
            case .rejected(let optional):
                // code
                break
            }
            
        }
    }
}

*/
