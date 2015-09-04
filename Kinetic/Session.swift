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
    
    internal var config: Command.GetLog.Configuration {
        return self.handshake.body.getLog.configuration
    }
    
    internal var limits: Command.GetLog.Limits {
        return self.handshake.body.getLog.limits
    }

    
    public var clusterVersion: Int64 { return self.handshake.header.clusterVersion }
    public var wwn: String {
        return NSString(data: self.config.worldWideName, encoding:NSUTF8StringEncoding)!.description
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
    
    public private(set) var error: ErrorType?
    public private(set) var device: KineticDevice?
    public private(set) var credentials: AuthenticationCredential
    
    public var connectionId: Int64? { return self.device?.handshake.header.connectionId }
    
    public var connected: Bool { return self.channel.connected }
    
    public func close() {
        self.channel.close()
    }
  
    public func clone() throws -> KineticSession {
        return try self.channel.clone()
    }
    
    public init(channel: KineticChannel){
        self.credentials = HmacCredential.defaultCredentials()
        self.sequence = 0
        self.channel = channel
        self.writerQueue = dispatch_get_main_queue()
        self.pending = [:]
        
        // Shake hands
        do {
            let r = try self.channel.receive()
            self.device = KineticDevice(handshake: r.command)
        } catch let err {
            self.error = err
            self.channel.close()
        }
        
        // Reader
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            while self.connected {
                do {
                    debugPrint("waiting for \(self.connectionId!) ...")
                    let raw = try self.channel.receive()
                    debugPrint("Background loops seems to work... Ack:\(raw.command.header.ackSequence)")
                    if let x = self.pending[raw.command.header.ackSequence] {
                        Queue.global.async { x(raw) }
                    } else {
                        // TODO: add support for unsolicited
                        debugPrint("Oops: Unsolicited or unexpected ACK :/")
                        debugPrint(raw.command)
                    }
                } catch KineticEncoding.Error.Closed {
                    break
                } catch let err {
                    self.error = err
                    self.close()
                }
            }
            debugPrint("Session closed, reader going away...")
        }
        
        // We only need the writer queue if connection was ok
        if self.device != nil {
            self.writerQueue = dispatch_queue_create(
                "KineticSession (wwn: \(self.device!.wwn), connection:\(self.connectionId!))"
                , DISPATCH_QUEUE_SERIAL)
        }
    }
    
    internal convenience init(withCredentials channel: KineticChannel, credentials: AuthenticationCredential){
            self.init(channel: channel)
            self.credentials = credentials
    }
    
    public func promise<C: ChannelCommand>(cmd: C) -> Future<C.ResponseType, WrappedError> {
        // Prepare promise
        let promise = Promise<C.ResponseType, WrappedError>()
        
        guard self.connected else {
            promise.tryFailure(.Error(KineticSessionErrors.NotConnected))
            return promise.future
        }
        
        // Prepare command contents
        let builder = Builder()
        let context = cmd.build(builder, device: self.device!)
        
        // Prepare header
        let h = builder.header
        h.clusterVersion = self.device!.clusterVersion
        h.connectionId = self.connectionId!
        h.sequence = ++self.sequence
        
        let m = builder.message
        
        do {
            // Build command proto
            let cmdProto = try builder.command.build()
            m.commandBytes = cmdProto.data()
            
            self.credentials.authenticate(builder)
            
            if C.ResponseType.self == NoResponse.self {
                // Some operations don't have a reply at all
                
                // Queue the command to be sent to the target device
                dispatch_async(self.writerQueue) {
                    do {
                        debugPrint("Sending seq:\(builder.command.header.sequence)")
                        debugPrint(builder.command)
                        try self.channel.send(builder)
                        
                        // As soon as we are done sending, we can consider the operation a success
                        try promise.success(NoResponse() as! C.ResponseType)
                    } catch let err {
                        do {
                            try promise.failure(.Error(KineticSessionErrors.SendFailure(err)))
                        } catch {
                            // Well... this is messed up
                            // TODO: what makes this nonesense happen?
                        }
                    }
                }
            } else {
                self.pending[builder.command.header.sequence] = { r in
                    let r = C.ResponseType.parse(r, context: context)
                    if r.failed {
                        do {
                            try promise.failure(.Error(r.error!))
                        } catch {
                            // Well... this is messed up
                            // TODO: what makes this nonesense happen?
                        }
                    } else {
                        do {
                            try promise.success(r)
                        } catch let err {
                            do {
                                try promise.failure(.Error(FutureErrors.FailedToCallSuccess(err)))
                            } catch {
                                // Well... this is messed up
                                // TODO: what makes this nonesense happen?
                            }
                        }
                    }
                    self.pending[builder.command.header.sequence] = nil
                }
                
                // Queue the command to be sent to the target device
                dispatch_async(self.writerQueue) {
                    do {
                        debugPrint("Sending seq:\(builder.command.header.sequence)")
                        try self.channel.send(builder)
                    } catch let err {
                        do {
                            try promise.failure(.Error(KineticSessionErrors.SendFailure(err)))
                        } catch {
                            // Well... this is messed up
                            // TODO: what makes this nonesense happen?
                        }
                    }
                }
                
            }
        } catch let err {
            do {
                try promise.failure(.Error(KineticSessionErrors.SendFailure(err)))
            } catch {
                // Well... this is messed up
                // TODO: what makes this nonesense happen?
            }
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
    public func send<C: ChannelCommand>(cmd: C) throws -> C.ResponseType {
        return try self.send(cmd, timeout: TimeInterval.Forever)
    }
    
    public func send<C: ChannelCommand>(cmd: C, timeout:TimeInterval) throws -> C.ResponseType {
        let future = self.promise(cmd)
        guard let v = future.forced(timeout) else {
            throw KineticSessionErrors.Timeout
        }
        guard let r = v.value else {
            throw v.error!.unwrap()
        }
        if r.failed {
            // Shouln't happen, the reader thread is already calling failure() 
            // but just in case...
            throw r.error!
        }
        return r
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