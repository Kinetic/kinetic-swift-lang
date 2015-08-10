//
//  Client.swift
//  Kinetic
//
//  Created by Ignacio Corderi on 7/27/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import Foundation

typealias Message = Com.Seagate.Kinetic.Proto.Message_
typealias Command = Com.Seagate.Kinetic.Proto.Command

public enum KineticConnectionErrors: ErrorType {
    case InvalidMagicNumber
}

func bytesToUInt32(bytes:Array<UInt8>, offset:Int) -> UInt32 {
    let upper = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset+1]) << 16
    let lower = UInt32(bytes[offset+2]) << 8 | UInt32(bytes[offset+3])
    return upper | lower
}

public func connect(host:String, port:Int) throws -> Client {
    let c = Client(host: host, port: port)
    try c.connect()
    return c
}

public class Client : CustomStringConvertible {
    
    public let host: String
    public let port: Int
    
    var inp: NSInputStream?
    var out: NSOutputStream?
    
    var handshake: Command?
    
    // Session information
    public var connectionId: Int64 {
        return handshake!.header.connectionId
    }
    
    // Device information
    public var wwn: String {
        let config = handshake!.body.getLog.configuration
        return NSString(data: config.worldWideName, encoding:NSUTF8StringEncoding)!.description
    }
    
    // CustomStringConvertible (a.k.a toString)
    public var description: String {
        get {
            return "Connected to \(wwn)"
        }
    }
    
    init(host:String, port:Int) {
        self.host = host
        self.port = port
    }
    
    func connect() throws {
        NSStream.getStreamsToHostWithName(self.host, port: self.port, inputStream: &self.inp, outputStream: &self.out)
        
        let inputStream = inp!
        let outputStream = out!
        inputStream.open()
        outputStream.open()
        
        var headerBuffer = Array<UInt8>(count:9, repeatedValue: 0)
        
        // TODO: what are the semantics of read in swift? does it read all?
        var bytesRead = inputStream.read(&headerBuffer, maxLength: headerBuffer.count)
        
        if headerBuffer[0] != 70 {
            throw KineticConnectionErrors.InvalidMagicNumber
        }
        
        let protoLength = Int(bytesToUInt32(headerBuffer, offset: 1))
        // TODO: value ln should be zero on handshake...
        let valueLength = bytesToUInt32(headerBuffer, offset: 5)                
        
        var protoBuffer = Array<UInt8>(count:protoLength, repeatedValue: 0)
        bytesRead = inputStream.read(&protoBuffer, maxLength: protoBuffer.count)
        
        let proto = NSData(bytes: &protoBuffer, length: protoLength)
        
        let msg = try Message.parseFromData(proto)
        
        self.handshake = try Command.parseFromData(msg.commandBytes)
    }

}