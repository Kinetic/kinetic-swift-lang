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

public struct KineticDevice {
    internal let handshake: Command
    
    public var clusterVersion: Int64 { return self.handshake.header.clusterVersion }
    public var wwn: String {
        let config = self.handshake.body.getLog.configuration
        return NSString(data: config.worldWideName, encoding:NSUTF8StringEncoding)!.description
    }
    
    internal init(handshake: Command) {
        self.handshake = handshake
    }
}

public class KineticSession {
    
    public var device: KineticDevice?
    public var connectionId: Int64? { return self.device?.handshake.header.connectionId }
    public var credentials: AuthenticationCredential
    
    var sequence: Int64
    var channel: KineticChannel
    
    // Surface convenient channel operations
    public var connected: Bool { return self.channel.connected }
    public func close() {
        self.channel.close()
    }
    
    init(channel: KineticChannel, device: KineticDevice?){
        self.channel = channel
        self.device = device        
        self.credentials = HmacCredential.defaultCredentials()
        self.sequence = 0
    }
    
    public func send<C: ChannelCommand>(cmd: C) throws -> C.ResponseType {
        // Prepare command contents
        let builder = cmd.build(Builder())
        
        // Prepare header
        let h = builder.header
        h.clusterVersion = self.device!.clusterVersion
        h.connectionId = self.connectionId!
        h.sequence = ++self.sequence
        
        let m = builder.message
        
        // Build command proto
        let cmdProto = try builder.command.build()
        m.commandBytes = cmdProto.data()
        
        self.credentials.authenticate(builder)
        
        // Send & receive
        try self.channel.send(builder)
        let r = try self.channel.receive()
        
        return C.ResponseType.parse(r)
    }

}

extension KineticDevice: CustomStringConvertible {
    public var description: String { return "Device \(self.wwn)" }
}

extension KineticSession: CustomStringConvertible {
    public var description: String {
        if self.connected {
            return "Session with \(self.device!)"            
        } else {
            return "Session not connected"
        }
    }
}