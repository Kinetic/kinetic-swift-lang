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

typealias Message = Com.Seagate.Kinetic.Proto.Message_
typealias Command = Com.Seagate.Kinetic.Proto.Command

public protocol KeyType {
    func toData() -> NSData
}
public protocol ValueType {
    var length: Int { get }
    func toBytes() -> Bytes
    func toUtf8String() -> String
}

extension NSData: KeyType, ValueType {
    
    public func toData() -> NSData { return self }
    
    public func toBytes() -> Bytes {
        // TODO: figure out how to do this without copying!
        var buffer = Bytes(count: self.length, repeatedValue: 0)
        self.getBytes(&buffer, length: self.length)
        return buffer
    }
    
    public func toUtf8String() -> String {
        return NSString(data: self, encoding:NSUTF8StringEncoding)!.description
    }
    
}

extension String: KeyType, ValueType {
    
    public var length: Int { return self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) }
    
    public func toData() -> NSData {
        return NSData(data: self.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    
    public func toBytes() -> Bytes { return self.toUtf8() }
    
    public func toUtf8String() -> String { return self }
}

extension UInt32: ValueType {
    
    public var length: Int { return 4 }
    
    public func toBytes() -> Bytes {
        var buffer = Bytes(count: 4, repeatedValue: 0)
        copyFromUInt32(&buffer, offset: 0, value: self)
        return buffer
    }
    
    public func toUtf8String() -> String {
        return self.description
    }
}

public class Builder {
    internal var message: Message.Builder
    internal var command: Command.Builder
    internal var value: Bytes
    
    internal init() {
        self.message = Message.Builder()
        self.command = Command.Builder()
        self.value = []
    }
}

// Basic
extension Builder {
    var header:Command.Header.Builder { return self.command.getHeaderBuilder() }
    var body:Command.Body.Builder { return self.command.getBodyBuilder() }
}

// Expanded body
extension Builder {
    var keyValue:Command.KeyValue.Builder { return self.body.getKeyValueBuilder() }
    var range:Command.Range.Builder { return self.body.getRangeBuilder() }
    var setup:Command.Setup.Builder { return self.body.getSetupBuilder() }
    var p2pOperation:Command.P2Poperation.Builder { return self.body.getP2POperationBuilder() }
    var getLog:Command.GetLog.Builder { return self.body.getGetLogBuilder() }
    var security:Command.Security.Builder { return self.body.getSecurityBuilder() }
    var pinOperation:Command.PinOperation.Builder { return self.body.getPinOpBuilder() }
    var batch:Command.Batch.Builder { return self.body.getBatchBuilder() }
}

public struct RawResponse {
    internal var message: Message
    internal var command: Command
    internal var value: Bytes
}

public protocol ChannelCommand {
    typealias ResponseType: ChannelResponse
    func build(builder: Builder, device: KineticDevice) -> ResponseType.ContextType
}

public extension ChannelCommand {
    func sendTo(session: KineticSession) throws -> Self.ResponseType {
        return try session.send(self)
    }
}

public protocol ChannelResponse : CustomStringConvertible {
    typealias ContextType
    var success: Bool { get }
    var error: KineticRemoteError? { get }
    static func parse(raw: RawResponse, context: Self.ContextType) -> Self
}

public extension ChannelResponse {
    var failed: Bool { return !self.success }
    var description: String {
        get {
            if self.success {
                return "Success"
            } else if self.error!.message.isEmpty {
                return "\(self.error!.code)"
            } else {
                return "\(self.error!.code): \(self.error!.message)"
            }
        }
    }
}
