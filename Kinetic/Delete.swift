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

public class DeleteCommand : ChannelCommand {
    
    public typealias ResponseType = EmptyResponse
    
    public let key: NSData
    
    public init(key: NSData) {
        self.key = key
    }
    
    public convenience init(key: String) {
        self.init(key: key.toNSData())
    }
    
    public func build(builder: Builder) -> Builder {
        builder.header.messageType = .Delete
        builder.keyValue.key = self.key
        return builder
    }
    
}

public struct EmptyResponse : ChannelResponse {
    public let success: Bool
    public let error: KineticRemoteError?
    public let exists: Bool
    
    public static func parse(raw: RawResponse) -> EmptyResponse {
        switch raw.command.status.code {
        case .Success:
            return EmptyResponse(success: true, error: nil, exists: true)
        case .NotFound:
            return EmptyResponse(success: true, error: nil, exists: false)
        default:
            return EmptyResponse(success: false,
                error: KineticRemoteError.fromStatus(raw.command.status),
                exists: false)
        }
    }
    
    public var description: String {
        get {
            if self.success {
                if self.exists {
                    return "Success"
                } else {
                    return "Success (NotFound)"
                }
            } else if self.error!.message.isEmpty {
                    return "\(self.error!.code)"
                } else {
                    return "\(self.error!.code): \(self.error!.message)"
            }
        }
    }
}

extension DeleteCommand: CustomStringConvertible {
    public var description: String {
        get {
            return "Delete (key: \(self.key.toUtf8()))"
        }
    }
}

public extension SynchornousChannel {
    func delete(key: String) throws -> DeleteCommand.ResponseType {
        let cmd = DeleteCommand(key: key)
        return try cmd.sendTo(self)
    }
}