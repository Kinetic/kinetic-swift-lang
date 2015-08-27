//
//  Socket.swift
//  Socket
//
//  Created by James Hughes on 8/24/15.
//  Copyright © 2015 James Hughes. All rights reserved.
//

import Foundation

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
        let sin = sockaddr_in(fromSockaddr: sa)
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

    func sockClose() {
        // close the file descriptor
        if close(s) != 0 {
            print(PosixError(comment: "close(...) failed").description)
        }
    }
    
}