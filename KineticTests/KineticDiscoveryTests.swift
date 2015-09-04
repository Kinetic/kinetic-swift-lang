//
//  KineticDiscovery.swift
//  Kinetic
//
//  Created by James Hughes on 9/4/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import XCTest
import Socket

class KineticDiscoveryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func delay(x: Double) {
        NSThread.sleepForTimeInterval(x)
    }

    func testMulticastTimeout() {
        do {
            let session = try KineticDiscovery(port: "8125", timeout:0.1) { _ in
                XCTFail("Should not happen")
            }
            delay(0.5)
            XCTAssertFalse(session.discoverRunning)
            XCTAssertTrue(session.error  != nil)
            XCTAssertTrue(session.error! as? Datagram.Error == Datagram.Error.timeout)
        } catch let x {
            XCTFail(String(x))
        }
    }
    
    func testPrintAllWWN() {
        let wwn:String = KineticDiscovery.jroot.world_wide_name.rawValue
        var WWNs = Set<String>()
        do {
            let s = try KineticDiscovery() { j in
                WWNs.insert(j[wwn]!! as! String)
            }
            delay(6)
            s.stop()
            print(WWNs)
            XCTAssertGreaterThan(WWNs.count, 0)
        } catch let x {
            XCTFail(String(x))
        }
    }
    
}
