//
//  File.swift
//  Socket
//
//  Created by James Hughes on 8/23/15.
//  Copyright © 2015 James Hughes. All rights reserved.
//

import Foundation

protocol DatagramProtocol {
    
    init(port: Int) throws
    var port:Int { get }
    func send (host:in_addr_t, port:in_port_t, message:Bytes) throws
    func send (host:String, port:in_port_t, message:Bytes) throws
    func recv (length: Int) throws -> (host:in_addr_t, port:in_port_t, message:Bytes)
    func join (host:String)
}

