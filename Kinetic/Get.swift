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

public class GetCommand : ChannelCommand {
    
    public typealias ResponseType = ValueResponse
    
    public let key: NSData
    
    public init(key: NSData) {
        self.key = key
    }
    
    public convenience init(key: String) {
        self.init(key: key.toNSData())
    }
    
    public func build(builder: Builder) -> Builder {
        builder.header.messageType = .Get
        builder.keyValue.key = self.key
        return builder
    }
    
}

extension GetCommand: CustomStringConvertible {
    public var description: String {
        get {
            return "Get (key: \(self.key.toUtf8()))"
        }
    }
}


public extension SynchornousChannel {
    func get(key: String) throws -> GetCommand.ResponseType {
        let cmd = GetCommand(key: key)
        return try cmd.sendTo(self)
    }
}