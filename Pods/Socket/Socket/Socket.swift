//
//  Socket.swift
//  Socket
//
//  Created by James Hughes on 8/24/15.
//  Copyright © 2015 James Hughes. All rights reserved.
//

import Foundation

func getSockAddr(host: String = "0.0.0.0", port: String = "0", sockType: Int32) throws -> sockaddr {
    var hint = addrinfo()
    hint.ai_socktype = sockType
    hint.ai_family = AF_INET
    
    var resPtr = UnsafeMutablePointer<addrinfo>.alloc(1)
    switch getaddrinfo(
        host.cStringUsingEncoding(NSUTF8StringEncoding)!,
        port.cStringUsingEncoding(NSUTF8StringEncoding)!,
        &hint, &resPtr) {
    case 0:
        break
    case let x:
        let ss:NSObject = "description"
        let tt:AnyObject = NSString(UTF8String: gai_strerror(x))!
        let y:[NSObject:AnyObject] = [ss:tt]
        throw NSError(domain: "GAI Error", code: Int(x), userInfo: y)
    }
    
    let res:addrinfo = resPtr.memory
    let sa:sockaddr = res.ai_addr.memory
    freeaddrinfo(resPtr)
    return sa
}




public class Socket {
    
    var s:Int32
    
    public private(set) var port:in_port_t  = 0;

    
    // Used only by the accept to create a new socket.
    init(sock: Int32) throws {
        s = sock
        guard (s > 0) else {
            throw PosixError(comment: "Datagram socket(...)")
        }
        
        // prevents crashes when blocking calls are pending and the app is paused ( via Home button )
        // or if the socket in unexpectedly closed.
        var no_sig_pipe: Int32 = 1;
        guard setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(sizeof(Int32))) >= 0 else {
            throw PosixError(comment: "setsockopt(NoSigPipe...) failed.")
        }
    }
    
    func setPort() throws {
        var sa = sockaddr()
        var salen = socklen_t(strideof(sockaddr))
        guard getsockname(s, &sa, &salen) == 0 else {
            throw PosixError(comment: "Datagram getsockname(...)")
        }
        let sin = sa.toSockaddr_in
        guard sin.sin_family == sa_family_t(AF_INET) else {
            throw PosixError(comment: "wrong networking family")
        }
        port = sin.sin_port.byteSwapped
    }
    
    func setRdTimeout(timeout: Double) throws {
        var tv = timeval(t: timeout)
        let tvSize = socklen_t(strideof(timeval))
        
        switch setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, tvSize) {
        case 0: break                    // success
        case -1 where errno == 22: break // bug. If the stream is at EoF, SO_RCVTIMEO will fail.
        default:
            throw PosixError(comment: "setsockopt(SO_RCVTIMEO...) failed.")
        }
    }

    public func sockClose() {
        // close the file descriptor
        if close(s) != 0 {
            print(PosixError(comment: "close(...) failed").description)
        }
    }
    
}