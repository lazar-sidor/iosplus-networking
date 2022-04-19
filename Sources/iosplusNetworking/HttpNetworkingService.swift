//
//  HttpRequestManager.swift
//
//  Created by Lazar Sidor on 07.01.2022.
//

import Foundation

public class HttpNetworkingService: NSObject {
    private var httpClient: HttpClient
    private var networkReachability: HttpNetworkReachabilityService
    
    public var httpConfiguration: HttpClientConfiguration {
        httpClient.configuration
    }

    public convenience init(httpClientConfiguration: HttpClientConfiguration) {
        self.init()
        self.httpClient = HttpClient(configuration: httpClientConfiguration)
        self.networkReachability = HttpNetworkReachabilityService(observer: { status in
            httpClientConfiguration.handleNetworkReachabilityChange(status)
        })
    }
    
    public convenience init(httpClient: HttpClient) {
        self.init()
        self.httpClient = httpClient
    }
    
    public override init() {
        let configuration = HttpClientConfiguration()
        self.httpClient = HttpClient(configuration: configuration)
        self.networkReachability = HttpNetworkReachabilityService(observer: { status in
            configuration.handleNetworkReachabilityChange(status)
        })
        super.init()
    }

    public func executeDataRequest<T: Codable>(_ request: ApiRequest, inputObject: T? = nil, completion: @escaping (ApiResult<T>) -> Void) {
        let executeRequestBlock = { [self] in
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

        networkReachability.checkApiReachability { restricted in
            guard restricted == false else {
                let error = NSError(domain: String(describing: HttpNetworkingService.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Network connection not available"])
                completion(ApiResult.rejected(error))
                return
            }

            executeRequestBlock()
        }
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
