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

public let connect = NetworkChannel.connect

protocol StreamChannel {
    var inp: NSInputStream? { get set }
    var out: NSOutputStream? { get set }
}

extension StreamChannel {
    
    func rawSend(proto: NSData, value: Bytes?) throws {
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
    
    func rawReceive() throws -> (Message, Bytes) {
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
}

public class NetworkChannel: CustomStringConvertible, KineticChannel, StreamChannel {
    
    public let host: String
    public let port: Int
    
    // StreamChannel
    var inp: NSInputStream?
    var out: NSOutputStream?
    
    // CustomStringConvertible (a.k.a toString)
    public var description: String { return "Channel \(self.host):\(self.port)" }
    
    // KineticChannel
    weak public private(set) var session: KineticSession? = nil
    public private(set) var error: ErrorType? = nil
    public var connected: Bool {
        return self.inp != nil && self.out != nil
    }
    
    internal init(host:String, port:Int) {
        self.host = host
        self.port = port
    }
    
    public static func connect(host: String, port: Int) -> KineticSession {
        let c = NetworkChannel(host: host, port: port)
        NSStream.getStreamsToHostWithName(host, port: port, inputStream: &c.inp, outputStream: &c.out)
        
        c.inp!.open()
        c.out!.open()
        
        var device:KineticDevice? = nil
        do {
            let (msg, _) = try c.rawReceive()
            device = KineticDevice(handshake: try Command.parseFromData(msg.commandBytes))
        } catch let err {
            c.error = err
        }
        
        let s = KineticSession(channel: c, device: device)
        c.session = s
        
        return s
    }
    
    public func clone() -> KineticSession {
        return NetworkChannel.connect(self.host, port: self.port)
    }
    
    public func close() {
        self.inp?.close()
        self.out?.close()
        self.inp = nil
        self.out = nil
    }
    
    public func send(builder: Builder) throws {
        let msgProto = try builder.message.build()
        try self.rawSend(msgProto.data(), value: builder.value)
    }
    
    public func receive() throws -> RawResponse {
        let (msg, value) = try self.rawReceive()
        let cmd = try Command.parseFromData(msg.commandBytes)
        
        return RawResponse(message: msg, command: cmd, value: value)
    }
}

extension NetworkChannel: CustomReflectable {
    public func customMirror() -> Mirror {
        if self.error != nil {
            return Mirror(self, children: [
                "host" : self.host,
                "port" : self.port,
                "connected" : self.connected,
                "error": self.error!,
                ])
        } else {
            return Mirror(self, children: [
                "host" : self.host,
                "port" : self.port,
                "connected" : self.connected,
                ])
        }
    }
}