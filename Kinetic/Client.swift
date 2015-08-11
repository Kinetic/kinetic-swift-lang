// Copyright (c) 2015 Seagate Technology

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// @author: Ignacio Corderi

import Foundation
import CryptoSwift

public func connect(host:String, port:Int) throws -> Client {
    let c = Client(host: host, port: port)
    try c.connect()
    return c
}

public class Client : CustomStringConvertible, SynchornousChannel {
    
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
        
        let (msg, _) = try self.rawReceive()
        
        self.handshake = try Command.parseFromData(msg.commandBytes)
    }
    
    private func rawSend(proto: NSData, value: Bytes?) throws {
        // Prepare 9 bytes header
        // 1 byte - magic number | 4 bytes - proto length | 4 bytes - value length
        var headerBuffer = Bytes(count: 9, repeatedValue: 0)
        headerBuffer[0] = 70 // Magic
        copyFromUInt32(&headerBuffer, offset: 1, value: UInt32(proto.length))
        if value != nil {
            copyFromUInt32(&headerBuffer, offset: 5, value: UInt32(value!.count))
        }
        
        // Send header, proto and value
        let outputStream = self.out!
        outputStream.write(headerBuffer, maxLength: headerBuffer.count)
        var array = Bytes(count: proto.length, repeatedValue: 0)
        // TODO: make sure this is a non-memcopy operation
        proto.getBytes(&array, length: proto.length)
        outputStream.write(array, maxLength: array.count)
        if value != nil {
            outputStream.write(value!, maxLength: value!.count)
        }
    }
    
    private func rawReceive() throws -> (Message, Bytes) {
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
    
    public func send<C: ChannelCommand>(cmd: C) throws -> C.ResponseType {
        // Prepare command contents
        let builder = cmd.build(Builder())
        
        // Prepare header
        let h = builder.header
        h.clusterVersion = self.clusterVersion
        h.connectionId = self.clusterVersion
        h.sequence = self.clusterVersion
        
        let m = builder.message
        
        // Build command proto
        let cmdProto = try builder.command.build()
        print(cmdProto) // TODO: Remove this line
        m.commandBytes = cmdProto.data()
        
        // Prepare authentication
        let a = m.getHmacAuthBuilder()
        a.identity = self.identity
        a.hmac = m.commandBytes.hmacSha1(self.key)
        m.authType = .Hmacauth
        
        // Build message proto
        let msgProto = try m.build()
        
        // Send & Receive
        try self.rawSend(msgProto.data(), value: builder.value)
        let (respMsg, respValue) = try self.rawReceive()
        
        // Unwrap command
        let respCmd = try Command.parseFromData(respMsg.commandBytes)
        
        let r = RawResponse(message: respMsg, command: respCmd, value: respValue)
        return C.ResponseType.parse(r)
    }
    
}