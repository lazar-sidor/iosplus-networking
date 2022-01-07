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

public class HttpClient {
    
}
