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
    
    var c: KineticSession? = nil
    
    override func setUp() {
        super.setUp()
        do {
            c = try Kinetic.connect("127.0.0.1")
            print("Open Successful, \(c!.connectionId!)")
        } catch let x {
            fatalError(String(x)) // don't continue on failure. None of the tests will work.
        }
    }
    
    func delay(x: Double) {
        NSThread.sleepForTimeInterval(x)
    }
    
    override func tearDown() {
        c!.close()
        XCTAssertFalse(c!.connected)
        super.tearDown()
    }
    
    func testExample() {
        do {
        
            //: Write a key/value pair
            try c!.put("hello", value: "world")
            
            //: Read the value back
            let x = try c!.get("hello")
            
            //: The Strings on the methods are just for convenience
            //: the actual values are byte arrays `[UInt8]`
            print("Received: \(x.value!.toUtf8String())")

        }catch let x {
            XCTFail(String(x))
        }
    }
}
