//
//  KineticTestMulticast.swift
//  Kinetic
//
//  Created by James Hughes on 9/2/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import XCTest
import Socket

class KineticTestMulticast: XCTestCase {

    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testMulticast () {
        do {
            let mAddr = "239.1.2.3"
            let mPort = "8123"
            let s = try Datagram(multicast: mAddr, port: mPort)
            
            // recieve it on the multicast socket
            var (_, _, bytes) = try s.recv(65535, timeout:31)
            XCTAssertGreaterThan(bytes.count, 0) // this will fail if the simulator is not up
    
            let data = NSData(bytesNoCopy: &bytes, length: bytes.count, freeWhenDone:false)

            let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
            print (json)
            
            //            s.sockClose()
            s.sockClose()
        } catch let x {
            XCTFail(String(x))
        }
    }

}
