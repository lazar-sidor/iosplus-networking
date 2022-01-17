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
    
    public func executeDataRequest<I: Encodable, O: Decodable>(with endpoint: ApiEndpoint,
                                                        inputObject: I,
                                                        outputObject: O,
                                                        completion: @escaping ((_ response: Any?, _ responseError: Error?) -> Void)) {
        httpClient.executeDataRequest(url: endpoint.route.url(),
                                      httpMethod: endpoint.httpMethod,
                                      contentType: endpoint.contentType,
                                      headerParams: endpoint.headerParams,
                                      inputJSON: endpoint.inputJSONParams,
                                      inputObject: inputObject,
                                      outputObject: outputObject,
                                      responseType: endpoint.httpResponseType,
                                      completion: completion)
    }
    
    public func executeDeleteRequest<I: Encodable, O: Decodable>(with endpoint: ApiEndpoint,
                                                          inputObject: I,
                                                          outputObject: O?,
               completion: @escaping ((_ response: Any?, _ responseError: Error?) -> Void)) {
        httpClient.executeDataRequest(url: endpoint.route.url(),
                                      httpMethod: .delete,
                                      inputObject: inputObject,
                                      outputObject: outputObject,
                                      completion: completion)
    }
}
