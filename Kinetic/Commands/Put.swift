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

public class PutCommand : ChannelCommand {
    
    public typealias ResponseType = EmptyResponse
    
    public let key: NSData
    public let value: Bytes
    
    public init(key: NSData, value: Bytes) {
        self.key = key
        self.value = value
    }
    
    public convenience init(key: String, value: String) {
        self.init(key: key.toNSData(),
                  value: value.toUtf8())
    }
    
    public func build(builder: Builder) -> Builder {
        builder.header.messageType = .Put
        builder.keyValue.key = self.key
        builder.keyValue.synchronization = .Writeback
        builder.keyValue.tag = "1337".toNSData()
        builder.keyValue.algorithm = .Sha1
        builder.value = value
        return builder
    }
    
}

extension PutCommand: CustomStringConvertible {
    public var description: String {
        get {
            return "Put (key: \(self.key.toUtf8()), length: \(self.value.count))"
        }
    }
}

public extension KineticSession {
    func put(key: String, value: String) throws -> PutCommand.ResponseType {
        let cmd = PutCommand(key: key, value: value)
        return try cmd.sendTo(self)
    }
}