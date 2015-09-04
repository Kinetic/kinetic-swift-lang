//
//  File.swift
//  Socket
//
//  Created by James Hughes on 8/23/15.
//  Copyright © 2015 James Hughes. All rights reserved.
//

import Foundation

//protocol DatagramProtocol {
//    
//    // opens datagram socket to a given port. To get an ephemeral port, 
//    // leave the port off or specify port 0
//    init(port p:String) throws
//    
//    // opens a datagram socket to a specific multicast address and port.
////    init(multicast:String, port p:String) throws
//    
//    // get the port (useful for ephemeral port)
//    var port:in_port_t { get }
//    
//    // sends a message
//    func send (sa:sockaddr, message:Bytes) throws
//    
//    // receives a message. host and port are the source of the message
//    func recv (length: Int, timeout:Double) throws -> (host:String, port:in_port_t, message:Bytes)
//}


public class Datagram: Socket {
    
    public enum Error:ErrorType {
        case timeout
        case closed
    }
    
    public init(port p:String = "0") throws {
        try super.init(sock: socket(AF_INET,SOCK_DGRAM,0))

        var yes:Int32 = 1
        guard setsockopt(s,SOL_SOCKET,SO_REUSEADDR,&yes,socklen_t(strideof(Int32))) == 0 else {
            throw PosixError(comment: "Datagram setsockopt(SO_REUSEADDR...)")
        }
        
        var bindPort = try getSockAddr(port: p, sockType: SOCK_DGRAM)
        guard bind(s, &bindPort, socklen_t(strideof(sockaddr))) == 0 else {
            throw PosixError(comment: "Datagram bind(...)")
        }

        try setPort()
    }

    public convenience init(multicast:String, port p:String = "0") throws {
        try self.init(port:p)

        let group = in_addr(s_addr: inet_addr(multicast))
        let interface = in_addr(s_addr: inet_addr("0.0.0.0"))
        var mcq = ip_mreq(imr_multiaddr: group, imr_interface: interface)
        guard setsockopt(s, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mcq,(socklen_t(strideof(ip_mreq)))) == 0 else {
            throw PosixError(comment: "Datagram setsockopt(IP_ADD_MEMBERSHIP...)")
        }
    }
    
    public func send (var sa: sockaddr, var message:Bytes) throws {
        switch sendto(s, &message, message.count, 0, &sa, socklen_t(strideof(sockaddr))) {
        case let x where x < 0:
            throw PosixError(comment: "write(...) failed.")
        case message.count:
            return // happy
        case let x:     // x > 0 then
            fatalError("partial write len \(x) should have been \(message.count)")
        }
    }
    
    public func recv (length: Int, timeout:Double = 0) throws -> (host:String, port:in_port_t, message:Bytes) {
        try setRdTimeout(timeout)
        var message = Bytes(count: 65535, repeatedValue: 0)
        var sa = sockaddr()
        var salen = socklen_t(strideof(sockaddr))
        switch recvfrom(s, &message, message.count, 0, &sa, &salen) {
        case let x where x < 0 && errno == 35:
            throw Error.timeout
        case let x where x < 0 && closing:
            throw Error.closed
        case let x where x < 0:
            throw PosixError(comment: "Datagram read(...)")
        case let x:
            message.removeRange( x ..< message.count)
        }
        let sin = sa.toSockaddr_in
        
        let host = String(CString: inet_ntoa(sin.sin_addr), encoding: NSUTF8StringEncoding)
        return (host!, sin.sin_port.byteSwapped, message)
    }
}