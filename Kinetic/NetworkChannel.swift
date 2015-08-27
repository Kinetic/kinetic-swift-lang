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

//import BrightFutures

public let connect = NetworkChannel.connect
public func connect(host: String, port: Int = NetworkChannel.DEFAULT_PORT, timeout: Double = 1.0) throws ->  KineticSession {
    print (1)
    return try NetworkChannel.connect(host, port: port, timeout: timeout)
}

//extension NSInputStream {
//    
//    func read(fully length: Int) -> Bytes {
//        var buffer = Bytes(count:length, repeatedValue: 0)
//        // TODO: loop until you read it all
//        let _ = self.read(&buffer, maxLength: length)
//        return buffer
//    }
//    
//}
//
//extension NSOutputStream {
//    
//    func write(bytes: Bytes) -> Int {
//        return self.write(bytes, maxLength: bytes.count)
//    }
//    
//}
//
//extension NSStream {
//    public var isOpen : Bool {
//        return self.streamStatus == .Open ||
//            self.streamStatus == .Writing ||
//            self.streamStatus == .Reading
//    }
//}

import Socket


public class NetworkChannel: CustomStringConvertible, KineticChannel {

    public static let DEFAULT_CONNECT_TIMEOUT = 1.0
    public static let DEFAULT_PORT = 8123
    
    public let host: String
    public let port: Int
    
    var stream:Stream? = nil
    
    // CustomStringConvertible (a.k.a toString)
    public var description: String {
        return "Channel \(self.host):\(self.port)"
    }
    
    // KineticChannel
    weak public private(set) var session: KineticSession? = nil
    public var connected: Bool {
        return !stream!.eof
    }
    
    internal init(host:String, port:Int, timeout: Double = NetworkChannel.DEFAULT_CONNECT_TIMEOUT) throws {
        self.port = port
        self.host = host
        print(3)
        stream = try Stream(connectTo: host, port: in_port_t(port), timeout: timeout)
    }
    
    public static func connect(host: String, port: Int, timeout: Double = NetworkChannel.DEFAULT_CONNECT_TIMEOUT) throws -> KineticSession {
        print(2)
        let c = try NetworkChannel(host: host, port: port, timeout: timeout)

        let s = KineticSession(channel: c)
        c.session = s
            
        return s
    }
    
    public func clone() throws -> KineticSession {
        return try NetworkChannel.connect(host, port: port)
    }
    
    public func close() {
        stream!.releaseSock()
    }
    
    public func send(builder: Builder) throws {
        let encoded = try builder.encode()
        try stream!.writeBytes(encoded.header.bytes, cork: true)
        try stream!.writeBytes(encoded.proto)
        if encoded.value.count > 0 {
            try stream!.writeBytes(encoded.value)
        }
    }
    
    public func receive() throws -> RawResponse {
        
        let header = try KineticEncoding.Header(bytes: stream!.readBytes(9))
        let proto = try stream!.readBytes(header.protoLength)
        var value: Bytes = []
        if header.valueLength > 0 {
            value = try stream!.readBytes(header.valueLength)
        }
        
        let encoding = KineticEncoding(header, proto, value)
        
        return try encoding.decode()
    }
}

//extension NetworkChannel: CustomReflectable {
//    public func customMirror() -> Mirror {
//        return Mirror(self, children: [
//            "host" : self.host,
//            "port" : self.port,
//            "connected" : self.connected,
//            ])
//    }
//}