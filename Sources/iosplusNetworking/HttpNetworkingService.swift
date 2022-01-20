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
    
    public func executeDataRequest<T: Codable>(with endpoint: ApiEndpoint,
                                                               inputObject: T?,
                                                               completion: @escaping (ApiResult<T?>) -> Void) {
        httpClient.executeDataRequest(url: endpoint.route.url(),
                                      httpMethod: endpoint.httpMethod,
                                      contentType: endpoint.contentType,
                                      headerParams: endpoint.headerParams,
                                      inputJSON: endpoint.inputJSONParams,
                                      inputObject: inputObject,
                                      responseType: endpoint.httpResponseType,
                                      completion: completion)
    }
    
    public func executeDeleteRequest<T: Codable>(with endpoint: ApiEndpoint,
                                                                 inputObject: T?,
                                                                 outputObjectType: AnyClass?,
                                                                 completion: @escaping (ApiResult<T?>) -> Void) {
        httpClient.executeDataRequest(url: endpoint.route.url(),
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
    class func sampleEndpointCall(with completion: @escaping (ApiResult<User?>) -> Void) {
        let service: HttpNetworkingService = HttpNetworkingService(httpClientConfiguration: HttpClientConfiguration())
        let endpoint: ApiEndpoint = ApiEndpoint(route: ApiRoute(baseUrlPath: "someBaseUrl", path: "somePath"))
        service.executeDataRequest(with: endpoint, inputObject: nil, completion: completion)
    }
}
*/
