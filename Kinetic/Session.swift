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

import BrightFutures

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
    
    private var writerQueue :  dispatch_queue_t
    private var pending: [Int64: (RawResponse) -> ()]
    
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
        self.writerQueue = dispatch_get_main_queue()
        self.pending = [:]
        
        // Reader
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            print("Background reader for \(self.connectionId!) is active.")
            while self.connected {
                do {
                    print("waiting...")
                    let raw = try self.channel.receive()
                    print("Background loops seems to work... Ack:\(raw.command.header.ackSequence)")
                    if let x = self.pending[raw.command.header.ackSequence] {
                        Queue.global.async { x(raw) }
                    } else {
                        print("Oops: Unsolicited or unexpected ACK :/")
                    }
                } catch {
                    // TODO: fault the session, close the channel
                    print("Oops: please code me...")
                }
            }
            print("Session closed, reader going away...")
        }
        
        // We only need the writer queue if connection was ok
        if self.device != nil {
            self.writerQueue = dispatch_queue_create(
                "KineticSession (wwn: \(self.device!.wwn), connection:\(self.connectionId!))"
                , DISPATCH_QUEUE_SERIAL)
        }
    }
    
    internal convenience init(withCredentials channel: KineticChannel, device: KineticDevice?,
        credentials: AuthenticationCredential){
            self.init(channel: channel, device: device)
            self.credentials = credentials
    }
    
    public func promise<C: ChannelCommand>(cmd: C) -> Future<C.ResponseType, PromiseErrors> {
        // Prepare command contents
        let builder = cmd.build(Builder())
        
        // Prepare header
        let h = builder.header
        h.clusterVersion = self.device!.clusterVersion
        h.connectionId = self.connectionId!
        h.sequence = ++self.sequence
        
        let m = builder.message
        
        // Prepare promise
        let promise = Promise<C.ResponseType, PromiseErrors>()
        
        do {
            // Build command proto
            let cmdProto = try builder.command.build()
            m.commandBytes = cmdProto.data()
            
            self.credentials.authenticate(builder)
            
            
            self.pending[builder.command.header.sequence] = { r in
                do {
                    try promise.success(C.ResponseType.parse(r))
                } catch {
                    print("Mmm... when does this happen?")
                }
                self.pending[builder.command.header.sequence] = nil
            }
            
            // Queue the command to be sent to the target device
            dispatch_async(self.writerQueue) {
                do {
                    print("Sending seq:\(builder.command.header.sequence)")
                    try self.channel.send(builder)
                } catch {
                    // TODO: write me!
                    print("Sending failed :/ what a bummer")
                }
            }
        } catch {
            print("More oops! FIX ME")
        }
        
        return promise.future
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
    public func send<C: ChannelCommand>(cmd: C) -> C.ResponseType {
        let future = self.promise(cmd)
        return future.forced()!.value!
    }
    
    public func send<C: ChannelCommand>(cmd: C, timeout:NSTimeInterval) -> C.ResponseType {
        let future = self.promise(cmd)
        return future.forced(timeout)!.value!
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