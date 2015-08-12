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

public func connect(host:String, port:Int) -> KineticSession {
    let c = NetworkChannel(host: host, port: port)
    return c.connect()
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
    public var error: ErrorType? = nil
    public var connected: Bool {
        return self.inp != nil && self.out != nil
    }
    
    init(host:String, port:Int) {
        self.host = host
        self.port = port
    }
    
    public func connect() -> KineticSession {
        NSStream.getStreamsToHostWithName(self.host, port: self.port, inputStream: &self.inp, outputStream: &self.out)
        
        self.inp!.open()
        self.out!.open()
        
        do {
            let (msg, _) = try self.rawReceive()
            
            let device = KineticDevice(handshake: try Command.parseFromData(msg.commandBytes))
            return KineticSession(channel: self, device: device)
        } catch let err {
            self.error = err
        }
        
        return KineticSession(channel: self, device: nil)
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