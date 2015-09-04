//
//  KineticTests.swift
//  KineticTests
//
//  Created by Ignacio Corderi on 7/27/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import XCTest
@testable import Kinetic
import BrightFutures


class KineticTests: XCTestCase {
    
    
    override func setUp() {
        super.setUp()
    }
    
    func delay(x: Double) {
        NSThread.sleepForTimeInterval(x)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExample() {
        do {
            let c = try Kinetic.connect("127.0.0.1")
            print("Open Successful, \(c.connectionId!)")

            //: Write a key/value pair
            try c.put("hello", value: "world")
            
            //: Read the value back
            let x = try c.get("hello")
            
            //: The Strings on the methods are just for convenience
            //: the actual values are byte arrays `[UInt8]`
            print("Received: \(x.value!.toUtf8String())")
            
            c.close()
        }catch let x {
            XCTFail(String(x))
        }
    }
}
