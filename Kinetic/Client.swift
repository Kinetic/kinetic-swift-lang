//
//  Client.swift
//  Kinetic
//
//  Created by Ignacio Corderi on 7/27/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import Foundation
import CryptoSwift

typealias Message = Com.Seagate.Kinetic.Proto.Message_
typealias Command = Com.Seagate.Kinetic.Proto.Command
public typealias Bytes = [UInt8]

public enum KineticConnectionErrors: ErrorType {
    case InvalidMagicNumber
}

func bytesToUInt32(bytes:Array<UInt8>, offset:Int) -> UInt32 {
    let upper = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset+1]) << 16
    let lower = UInt32(bytes[offset+2]) << 8 | UInt32(bytes[offset+3])
    return upper | lower
}

func copyFromUInt32(inout bytes:Array<UInt8>, offset:Int, value:UInt32) {
    bytes[offset+0] = UInt8((value & 0xFF000000) >> 24)
    bytes[offset+1] = UInt8((value & 0x00FF0000) >> 16)
    bytes[offset+2] = UInt8((value & 0x0000FF00) >> 8)
    bytes[offset+3] = UInt8((value & 0x000000FF))
}

public extension String {
    func toUtf8() -> Bytes {
        var decodedBytes = Bytes()
        for b in self.utf8 {
            decodedBytes.append(b)
        }
        return decodedBytes
    }    
}

public extension NSData {
    func hmacSha1(key: String) -> NSData {
        // create array of appropriate length:
        var array = Bytes(count: self.length + 4, repeatedValue: 0)
        copyFromUInt32(&array, offset: 0, value: UInt32(self.length))
        
        // copy bytes into array
        self.getBytes(&array + 4, length: self.length) // gives me goosebumps
        
        //mac.update(struct.pack(">I", len(entity)))
        //mac.update(entity)
       
        let hmac = Authenticator.HMAC(key: key.toUtf8(), variant: .sha1).authenticate(array)!
        return NSData(bytes: hmac, length: hmac.count)
    }
}

public func connect(host:String, port:Int) throws -> Client {
    let c = Client(host: host, port: port)
    try c.connect()
    return c
}

public class Client : CustomStringConvertible {
    
    public let host: String
    public let port: Int
    
    public let identity: Int64 = 1
    public let key = "asdfasdf"
    
    var inp: NSInputStream?
    var out: NSOutputStream?
    
    var handshake: Command?
    
    // Session information
    var sequenceId: Int64 = 0
    
    public var connectionId: Int64 {
        return handshake!.header.connectionId
    }
    
    var clusterVersion: Int64 {
        return handshake!.header.clusterVersion
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
        
        self.inp!.open()
        self.out!.open()
        
        let (msg, _) = try self.receive()
        
        self.handshake = try Command.parseFromData(msg.commandBytes)
    }
    
    func send(msgBldr: Message.Builder, cmdBldr: Command.Builder, value: Bytes?) throws {
        let headerBldr = cmdBldr.getHeaderBuilder()
        headerBldr.clusterVersion = self.clusterVersion
        headerBldr.connectionId = self.connectionId
        headerBldr.sequence = ++self.sequenceId
        
        let cmd = try cmdBldr.build()
        print(cmd)
        msgBldr.commandBytes = cmd.data()
        let hmacBldr = msgBldr.getHmacAuthBuilder()
        hmacBldr.identity = self.identity
        hmacBldr.hmac = msgBldr.commandBytes.hmacSha1(self.key)
        msgBldr.authType = Message.AuthType.Hmacauth
        print("HMAC: \(hmacBldr.hmac)")
        
        let msg = try msgBldr.build()
        let bytes = msg.data()
        
        // Line header
        var headerBuffer = Bytes(count: 9, repeatedValue: 0)
        headerBuffer[0] = 70 // Magic  
        copyFromUInt32(&headerBuffer, offset: 1, value: UInt32(bytes.length))
        if value != nil {
            copyFromUInt32(&headerBuffer, offset: 5, value: UInt32(value!.count))
        }
        
        let outputStream = self.out!
        outputStream.write(headerBuffer, maxLength: headerBuffer.count)
        var array = Bytes(count: bytes.length, repeatedValue: 0)
        bytes.getBytes(&array, length: bytes.length)
        outputStream.write(array, maxLength: array.count)
        if value != nil {
            outputStream.write(value!, maxLength: value!.count)
        }
    }
    
    func receive() throws -> (Message, Bytes) {
        let inputStream = self.inp!
        
        var headerBuffer = Bytes(count:9, repeatedValue: 0)
        
        // TODO: what are the semantics of read in swift? does it read all?
        let _ = inputStream.read(&headerBuffer, maxLength: headerBuffer.count)
        
        if headerBuffer[0] != 70 {
            throw KineticConnectionErrors.InvalidMagicNumber
        }
        
        let protoLength = Int(bytesToUInt32(headerBuffer, offset: 1))
        let valueLength = Int(bytesToUInt32(headerBuffer, offset: 5))
        
        var protoBuffer = Array<UInt8>(count:protoLength, repeatedValue: 0)
        // TODO: what are the semantics of read in swift? does it read all?
        let _ = inputStream.read(&protoBuffer, maxLength: protoBuffer.count)
        
        let proto = NSData(bytes: &protoBuffer, length: protoLength)
        let msg = try Message.parseFromData(proto)
        // TODO: verify HMAC 
        
        if valueLength > 0 {
            var value = Bytes(count:valueLength, repeatedValue: 0)
            // TODO: what are the semantics of read in swift? does it read all?
            let _ = inputStream.read(&value, maxLength: value.count)
            
            return (msg, value)
        } else {
            return (msg, [])
        }
    }
    
    public func put(key: Bytes, value: Bytes) throws {
        let msgBldr = Message.Builder()
        let cmdBldr = Command.Builder()
        let headerBldr = cmdBldr.getHeaderBuilder()
        headerBldr.messageType = .Put
        let kvBldr = cmdBldr.getBodyBuilder().getKeyValueBuilder()
        kvBldr.key = NSData(bytes: key, length: key.count)
        try self.send(msgBldr, cmdBldr: cmdBldr, value: value)
        let (respMsg, _) = try self.receive()
        let respCmd = try Command.parseFromData(respMsg.commandBytes)
        print(respCmd.status!.code)
    }
    
    public func get(key: Bytes) throws -> Bytes {
        let msgBldr = Message.Builder()
        let cmdBldr = Command.Builder()
        let headerBldr = cmdBldr.getHeaderBuilder()
        headerBldr.messageType = .Get
        let kvBldr = cmdBldr.getBodyBuilder().getKeyValueBuilder()
        kvBldr.key = NSData(bytes: key, length: key.count)
        try self.send(msgBldr, cmdBldr: cmdBldr, value: nil)
        let (respMsg, value) = try self.receive()
        let respCmd = try Command.parseFromData(respMsg.commandBytes)
        print(respCmd.status!.code)
        return value
    }

}