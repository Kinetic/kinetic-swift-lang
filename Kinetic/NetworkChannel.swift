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

extension NSInputStream {
    
    func read(fully length: Int) -> Bytes {
        var buffer = Bytes(count:length, repeatedValue: 0)
        // TODO: loop until you read it all
        let _ = self.read(&buffer, maxLength: length)
        return buffer
    }
    
}

extension NSOutputStream {
    
    func write(bytes: Bytes) -> Int {
        return self.write(bytes, maxLength: bytes.count)
    }
    
}

public class NetworkChannel: CustomStringConvertible, KineticChannel {
    
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
            let r = try c.receive()
            device = KineticDevice(handshake: r.command)
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
        let outputStream = self.out!
        
        let encoded = try builder.encode()
        
        outputStream.write(encoded.header.bytes)
        outputStream.write(encoded.proto!)
        if encoded.value != nil {
            outputStream.write(encoded.value!)
        }
    }
    
    public func receive() throws -> RawResponse {
        let inputStream = self.inp!
        
        let header = KineticEncoding.Header(bytes: inputStream.read(fully: 9))
        let proto = inputStream.read(fully: header.protoLength)
        var value: Bytes? = nil
        if header.valueLength > 0 {
            value = inputStream.read(fully: header.valueLength)
        }
        
        let encoding = KineticEncoding(header, proto, value)
        
        return try encoding.decode()
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