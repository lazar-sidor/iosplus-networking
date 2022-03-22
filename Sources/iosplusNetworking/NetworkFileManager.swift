//
//  NetworkFileManager.swift
//  
//
//  Created by Lazar Sidor on 22.03.2022.
//

import UIKit

public class NetworkFileManager: NSObject {
    public static let shared = NetworkFileManager()
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

    public func downloadFile(from url: URL, toUrl: URL?, httpAdditionalHeaders: [String: String]? = nil, completion: @escaping (_ status: Bool, _ error: Error?) -> Void) {
        downloadFileAsync(from: url, toUrl: toUrl) { (loadStatus: Bool, loadError: Error?) in
            DispatchQueue.main.async {
                completion(loadStatus, loadError)
            }
        }
    }

    public func uploadPNGImage(at url: URL, image: UIImage, httpAdditionalHeaders: [String: String]? = nil, completion: @escaping ((_ error: Error?) -> Void)) {
        let data = image.pngData()
        let fileName = UUID().uuidString.lowercased() + ".png"
        let mimeType = "image/png"
        uploadFile(at: url, data: data, fileName: fileName, mimeType: mimeType, completion: completion)
    }

    public func cancelCurrentOperation() {
        if let session = networkSession {
            session.invalidateAndCancel()
        }
    }
}

// MARK: - File Downloading
private extension NetworkFileManager {
    private func downloadFileAsync(from url: URL, toUrl: URL?, httpAdditionalHeaders: [String: String]? = nil, completion: @escaping (_ status: Bool, _ loadError: Error?) -> Void) {
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

    private func downloadFile(from url: URL, destinationUrl: URL? = nil, httpAdditionalHeaders: [String: String]? = nil, completion: @escaping (_ status: Bool, _ saveError: Error?) -> Void) {
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
private extension NetworkFileManager {
    func uploadFile(at url: URL, data: Data?, fileName: String, mimeType: String, httpAdditionalHeaders: [String: String]? = nil, completion: @escaping ((_ error: Error?) -> Void)) {
        updateOperationStatus(progress: 0.0, error: nil, finished: false)
        var request = URLRequest(url: url)
        // generate boundary string using a unique per-app string
        let boundary = UUID().uuidString.lowercased()

        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let headers =  httpAdditionalHeaders {
            for key in headers.keys {
                request.setValue(headers[key], forHTTPHeaderField: key)
            }
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: String.Encoding.utf8)!)
        if let data = data {
            body.append(data)
        }

        var postData = String()
        postData += "\r\n"
        postData += "\r\n--\(boundary)--\r\n"
        body.append(postData.data(using: String.Encoding.utf8)!)
        request.httpBody = body

        let config = URLSessionConfiguration.default
        if let httpAdditionalHeaders = httpAdditionalHeaders {
            config.httpAdditionalHeaders = httpAdditionalHeaders
        }

        networkSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        let task = networkSession!.dataTask(with: request) { [self] (data, response, errorReceived) in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                errorReceived == nil
            else {
                updateOperationStatus(progress: 0.0, error: errorReceived, finished: true)
                completion(errorReceived)
                return
            }

            completion(errorReceived)
        }

        kvo = task.progress.observe(\.fractionCompleted) { [self] progress, _ in
            self.updateOperationStatus(progress: Float(progress.fractionCompleted), error: nil, finished: false)
        }

        task.resume()
    }

}
