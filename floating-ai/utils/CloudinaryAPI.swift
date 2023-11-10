//
//  CloudinaryAPI.swift
//  Floating AI
//
//  Created by Federico Vitale on 10/11/23.
//

import Foundation
import Alamofire

public class CloudinaryErrorMessage: Error {
    let message: String
    
    init(message: String) {
        self.message = message
    }
}

public struct CloudinaryUploadedFile: Codable {
    let asset_id: String
    let url: String
    let format: String
    let original_filename: String
}

public struct CloudinaryError: Codable {
    let error: [String:String]
    
    var message: String {
        self.error["message"]!
    }
    
    enum CodingKeys: String, CodingKey {
        case error
    }
}

public final class CloudinaryAPI {
    let apiKey: String
    let apiSecret: String?
    let cloud_id: String
    
    public var url: String {
        return "https://api.cloudinary.com/v1_1/\(self.cloud_id)/image/upload"
    }
    
    public init(cloud_id: String, apiKey: String, apiSecret: String?) {
        self.cloud_id = cloud_id
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }
    
    public func upload(data: Data) async throws -> CloudinaryUploadedFile {
        return try await withCheckedThrowingContinuation { continuation in
            self.coreUpload(data: data)
                .responseData(completionHandler: { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let errorResponse = try JSONDecoder().decode(CloudinaryError.self, from: data)
                            continuation.resume(throwing: CloudinaryErrorMessage(message: errorResponse.message))
                            return
                        } catch {
                            do {
                                let content = try JSONDecoder().decode(CloudinaryUploadedFile.self, from: data)
                                continuation.resume(returning: content)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                        
                        break
                    case .failure(let error):
                        print(error.localizedDescription)
                        continuation.resume(throwing: error)
                        break
                    }
                })
        }
    }
    
    public func coreUpload(data: Data) -> UploadRequest {
        return AF.upload(multipartFormData: { form in
            form.append(data, withName: "file")
            form.append(self.apiKey.data(using: .utf8)!, withName: "apiKey")
            form.append("unsigned_preset".data(using: .utf8)!, withName: "upload_preset")
        }, to: self.url, method: .post, requestModifier: .none)
    }
}

