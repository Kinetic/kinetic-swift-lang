//
//  KineticTests.swift
//  KineticTests
//
//  Created by Ignacio Corderi on 7/27/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import XCTest
@testable import Kinetic

class KineticTests: XCTestCase {
    
    var c: KineticSession? = nil
    
    override func setUp() {
        super.setUp()
        do {
            c = try Kinetic.connect("127.0.0.1")
        } catch let x {
            XCTFail(String(x))
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
