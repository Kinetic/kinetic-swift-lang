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

/// Contains information about a kinetic device
public struct KineticDevice : Equatable {
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

public func ==(lhs: KineticDevice, rhs: KineticDevice) -> Bool {
    return lhs.wwn == rhs.wwn
}

/// Represents a session against a kinetic device
public class KineticSession {
    
    var sequence: Int64
    var channel: KineticChannel
    
    public private(set) var device: KineticDevice?
    public private(set) var credentials: AuthenticationCredential
    
    public var connectionId: Int64? { return self.device?.handshake.header.connectionId }
    
    public var connected: Bool { return self.channel.connected }
    
    public func close() {
        self.channel.close()
    }
  
    public func clone() -> KineticSession {
        return self.channel.clone()
    }
    
    internal init(channel: KineticChannel, device: KineticDevice?){
        self.credentials = HmacCredential.defaultCredentials()
        self.sequence = 0
        self.channel = channel
        self.device = device
    }
    
    internal convenience init(withCredentials channel: KineticChannel, device: KineticDevice?,
        credentials: AuthenticationCredential){
            self.init(channel: channel, device: device)
            self.credentials = credentials
    }    
    
    /// Sends a command to the target device and waits for a response
    ///
    /// The type of the result is determined by the command being sent.
    ///
    /// Example:
    /// ```swift
    /// let response = try session.send(cmd)
    /// ```
    ///
    /// - Parameter cmd: The command that will be sent.
    /// - Returns: The response from the device.
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
            return "Session \(self.connectionId!) with \(self.device!)"
        } else {
            return "Session not connected"
        }
    }
}

extension KineticDevice: CustomReflectable {
    public func customMirror() -> Mirror {
        return Mirror(self.wwn, children: [
            "wwn" : self.wwn,
            "cluster version" : self.clusterVersion,
            ])
    }
}

extension KineticSession: CustomReflectable {
    public func customMirror() -> Mirror {
        if self.connectionId != nil {
            return Mirror(self, children: [
                "id" : self.connectionId!,
                "sequence" : self.sequence, 
                "device" : self.device!,
                "channel" : self.channel,
                ])
        } else {
            return Mirror(self, children: [
                "channel" : self.channel,
                ])
        }
    }
}