//
//  HttpNetworkFileManager.swift
//  
//
//  Created by Lazar Sidor on 22.03.2022.
//

import UIKit

public typealias ProcessFileCompletion = (_ status: Bool, _ error: Error?) -> Void

struct EncodingCharacters {
    static let crlf = "\r\n"
}

struct BoundaryGenerator {
    enum BoundaryType {
        case initial, encapsulated, final
    }

    static func randomBoundary() -> String {
        return String(format: "iosplusnetworking.boundary.%08x%08x", arc4random(), arc4random())
    }

    static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
        let boundaryText: String

        switch boundaryType {
        case .initial:
            boundaryText = "--\(boundary)\(EncodingCharacters.crlf)"
        case .encapsulated:
            boundaryText = "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
        case .final:
            boundaryText = "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
        }

        return boundaryText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
    }
}

public class HttpNetworkFileManager: NSObject {
    public static let shared = HttpNetworkFileManager()
    private var kvo: NSKeyValueObservation?
    private var networkSession: URLSession?
    private var operationProgress: Float = 0.0

    public var getProgress: Float {
        operationProgress
    }

    public override init() {
        super.init()
    }

    deinit {
        kvo?.invalidate()
    }

    public func downloadFile(from url: URL, toUrl: URL?, httpAdditionalHeaders: HTTPHeaders? = nil, completion: @escaping ProcessFileCompletion) {
        downloadFileAsync(from: url, toUrl: toUrl) { (loadStatus: Bool, loadError: Error?) in
            DispatchQueue.main.async {
                completion(loadStatus, loadError)
            }
        }
    }

    public func uploadFile(multipartData: HttpMultipartBody, httpMethod: HTTPMethod = .post, headers: HTTPHeaders? = nil, to: URL, completion: @escaping ProcessFileCompletion) {
        uploadMultipartData(multipartData, httpMethod: httpMethod, headers: headers, to: to, completion: completion)
    }

    public func cancelCurrentOperation() {
        if let session = networkSession {
            session.invalidateAndCancel()
        }
    }
}

// MARK: - File Downloading
private extension HttpNetworkFileManager {
    private func downloadFileAsync(from url: URL, toUrl: URL?, httpAdditionalHeaders: HTTPHeaders? = nil, completion: @escaping ProcessFileCompletion) {
        guard let destination = toUrl else {
            downloadFile(from: url, completion: completion)
            return
        }

        if FileManager().fileExists(atPath: destination.path) && FileManager().isDeletableFile(atPath: destination.path) {
            do {
                try FileManager().removeItem(at: destination)
                downloadFile(from: url, destinationUrl: destination, completion: completion)
            } catch {
                completion(false, error)
            }
        } else {
            downloadFile(from: url, destinationUrl: destination, completion: completion)
        }
    }

    private func downloadFile(from url: URL, destinationUrl: URL? = nil, httpAdditionalHeaders: [String: String]? = nil, completion: @escaping ProcessFileCompletion) {
        updateOperationStatus(progress: 0.0, error: nil, finished: false)

        let config = URLSessionConfiguration.default
        if let httpAdditionalHeaders = httpAdditionalHeaders {
            config.httpAdditionalHeaders = httpAdditionalHeaders
        }

        networkSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        let task = networkSession!.downloadTask(with: url, completionHandler: { [self] location, response, error in
            // After downloading your data we need to save it to specified destination url
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let location = location, error == nil
            else {
                updateOperationStatus(progress: 0.0, error: error, finished: true)
                completion(false, error)
                return
            }

            if let fileDestination = destinationUrl {
                do {
                    try FileManager.default.moveItem(at: location, to: fileDestination)
                    completion(true, nil)
                } catch {
                    updateOperationStatus(progress: 0.0, error: error, finished: true)
                    completion(false, nil)
                }
            } else {
                completion(true, nil)
            }
        })

        kvo = task.progress.observe(\.fractionCompleted) { [self] progress, _ in
            self.updateOperationStatus(progress: Float(progress.fractionCompleted), error: nil, finished: false)
        }

        task.resume()
    }

    func updateOperationStatus(progress: Float, error: Error?, finished: Bool) {
        if finished {
            self.operationProgress = 1.0
        } else {
            operationProgress = progress
        }
    }
}

// MARK: - File Uploading
private extension HttpNetworkFileManager {
    func uploadMultipartData(_ multipartData: HttpMultipartBody, httpMethod: HTTPMethod, headers: HTTPHeaders?, to url: URL, completion: @escaping ProcessFileCompletion) {
        updateOperationStatus(progress: 0.0, error: nil, finished: false)
        var request = URLRequest(url: url)
        let boundary = BoundaryGenerator.randomBoundary()
        let fileName = multipartData.fileName ?? UUID().uuidString.lowercased()
        let config = URLSessionConfiguration.default
        let mimeType = multipartData.mimeType ?? "application/octet-stream"

        request.httpMethod = httpMethod.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let headers = headers {
            config.httpAdditionalHeaders = headers
            for key in headers.keys {
                request.setValue(headers[key], forHTTPHeaderField: key)
            }
        }

        var params = ""
        if let paramHeaders = multipartData.params {
            for (key, value) in paramHeaders {
                params += "\(key): \(value)\(EncodingCharacters.crlf)"
            }
        }

        var body = Data()
        if params.isEmpty == false {
            body.append(BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary))
            body.append(params.data(using: String.Encoding.utf8)!)
            body.append("\(EncodingCharacters.crlf)".data(using: String.Encoding.utf8)!)
            body.append(BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary))
        } else {
            body.append(BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary))
        }

        body.append("Content-Disposition: form-data; name=\"\(multipartData.bodyName)\"; filename=\"\(fileName)\"\(EncodingCharacters.crlf)".data(using: String.Encoding.utf8)!)
        body.append("Content-Type: \(mimeType)\(EncodingCharacters.crlf)\(EncodingCharacters.crlf)".data(using: String.Encoding.utf8)!)
        if let data = multipartData.data { body.append(data) }
        body.append("\(EncodingCharacters.crlf)".data(using: String.Encoding.utf8)!)
        body.append(BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary))

        request.httpBody = body

        networkSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let task = networkSession!.dataTask(with: request) { [self] (data, response, errorReceived) in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                errorReceived == nil
            else {
                updateOperationStatus(progress: 0.0, error: errorReceived, finished: true)
                completion(false, errorReceived)
                return
            }

            completion(true, errorReceived)
        }

        kvo = task.progress.observe(\.fractionCompleted) { [self] progress, _ in
            self.updateOperationStatus(progress: Float(progress.fractionCompleted), error: nil, finished: false)
        }

        task.resume()
    }
}
