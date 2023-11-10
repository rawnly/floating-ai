//
//  Floating_AITests.swift
//  Floating AITests
//
//  Created by Federico Vitale on 10/11/23.
//

import XCTest
import Floating_AI
import ImageKitIO
import Cocoa


final class Floating_AITests: XCTestCase {
    let cloudinary = CloudinaryAPI(
        cloud_id: "dpcawz5hj",
        apiKey: "494171277924628",
        apiSecret: ""
    )
    
    let kit = ImageKit(
        publicKey: "public_THgAPJ9uC1PeUOx+xgFYeTd6u0M=",
        urlEndpoint: "https://ik.imagekit.io/pjz0rflol",
        authenticationEndpoint: "http://localhost:8080/auth"
    )

    override func setUpWithError() throws {
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() async throws {
        let image = NSImage(named: "profile")
        
        guard let tiff = image?.tiffRepresentation else {
            XCTFail("Image is NIL")
            return
        }
        
        let imageRep = NSBitmapImageRep(data: tiff)
        let png = imageRep?.representation(using: .png, properties: [:])
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
