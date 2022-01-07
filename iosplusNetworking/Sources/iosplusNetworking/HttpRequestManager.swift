//
//  HttpRequestManager.swift
//  
//
//  Created by Lazar Sidor on 07.01.2022.
//

import UIKit

public class HttpRequestManager: NSObject {
    private var httpClient: HttpClient!
    
    convenience init(httpClient: HttpClient) {
        self.init()
        self.httpClient = httpClient
    }
    
    func executeDataRequest<I: Encodable, O: Decodable>(with endpoint: Endpoint,
                                                        inputObject: I,
                                                        outputObject: O,
                                                        completion: @escaping ((_ response: Any?, _ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)) {
        httpClient.executeDataRequest(url: endpoint.route.url(),
                                      httpMethod: endpoint.httpMethod,
                                      contentType: endpoint.contentType,
                                      headerParams: endpoint.headerParams,
                                      inputJSON: endpoint.inputJSONParams,
                                      inputObject: inputObject,
                                      outputObject: outputObject,
                                      responseType: endpoint.httpResponseType) { response, responseError, errorCode in
        }
    }
    
    func executeDeleteRequest<I: Encodable, O: Decodable>(with endpoint: Endpoint,
                                                          inputObject: I,
                                                          outputObject: O?,
               completion: @escaping ((_ response: Any?, _ responseError: Error?, _ errorCode: HTTPCustomErrorCode?) -> Void)) {
        httpClient.executeDataRequest(url: endpoint.route.url(), httpMethod: .delete, inputObject: inputObject, outputObject: outputObject) { response, responseError, errorCode in
        }
    }
}
