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

public enum Range<K : KeyType> : CustomStringConvertible{
    case FromTo(K, K, Bool, Bool)
    case From(K, Bool)
    case To(K, Bool)
    case Prefix(K)

    internal func build(builder: Builder, device: KineticDevice) {
        switch self {
        case FromTo(let from, let to, let fromInclusive, let toInclusive):
            builder.range.startKey = from.toData()
            builder.range.startKeyInclusive = fromInclusive
            builder.range.endKey = to.toData()
            builder.range.endKeyInclusive = toInclusive
        case From(let key, let inclusive):
            builder.range.startKey = key.toData()
            builder.range.startKeyInclusive = inclusive
            let bs = Bytes(count: Int(device.limits.maxKeySize), repeatedValue: UInt8(0xFF))
            builder.range.endKey = NSData(bytes: bs, length: bs.count)
            builder.range.endKeyInclusive = true
        case To(let key, let inclusive):
            builder.range.startKey = NSData(bytes: [], length: 0)
            builder.range.startKeyInclusive = true
            builder.range.endKey = key.toData()
            builder.range.endKeyInclusive = inclusive
        case Prefix(let prefix):
            let p = prefix.toData()
            builder.range.startKey = p
            builder.range.startKeyInclusive = true
            if p.length > 0 {
                var bs = p.arrayOfBytes()
                bs[bs.count-1] += 1
                builder.range.endKey = NSData(bytes: bs, length: p.length)
                builder.range.endKeyInclusive = false
            }
        }
    }
    
    public var description: String {
        switch self {
        case FromTo(let from, let to, true, true):
            return "Range ['\(from)'..'\(to)']"
        case FromTo(let from, let to, true, false):
            return "Range ['\(from)'..'\(to)')"
        case FromTo(let from, let to, false, true):
            return "Range ('\(from)'..'\(to)']"
        case FromTo(let from, let to, false, false):
            return "Range ('\(from)'..'\(to)')"
        case From(let key, true): return "Range ['\(key)'..)"
        case From(let key, false): return "Range ('\(key)'..)"
        case To(let key, true):  return "Range [..'\(key)']"
        case To(let key, false): return "Range [..'\(key)')"
        case Prefix(let prefix): return "Prefix '\(prefix)'"
        }
    }
}


public class GetKeyRangeCommand<K : KeyType> : ChannelCommand {
    
    public typealias ResponseType = KeyRangeResponse
    
    public let range: Range<K>
    public let reverse: Bool
    public let maxReturned: Int?
    
    public init(_ range: Range<K>, reverse: Bool=false, maxReturned: Int?=nil) {
        self.range = range
        self.reverse = reverse
        self.maxReturned = maxReturned
    }
    
    public func build(builder: Builder, device: KineticDevice) -> Int {
        builder.header.messageType = .Getkeyrange
        self.range.build(builder, device: device)
        builder.range.reverse = self.reverse
        
        var max: Int32 = 0
        if (self.maxReturned != nil) {
            // TODO: verify that it's <= than the limit
            max = Int32(self.maxReturned!)
        } else {
            max = Int32(device.limits.maxKeyRangeCount)
        }
         builder.range.maxReturned = max
        
        return Int(max)
    }
    
}

public struct KeyRangeResponse: ChannelResponse {
    public typealias ContextType = Int
    
    public let success: Bool
    public let error: KineticRemoteError?
    public let keys: [NSData]
    public let hasMore: Bool
    
    public static func parse(raw: RawResponse, context: Int) -> KeyRangeResponse {
        switch raw.command.status.code {
        case .Success:
            var keys: [NSData] = []
            /* It might be possible that some implementation of the device
               is not returning anyhting at all when the resulting range
               is empty. It might be considered an implementation flaw. */
            if raw.command.hasBody && raw.command.body.hasRange {
                keys = raw.command.body.range.keys
            }
            return KeyRangeResponse(success: true, error: nil,
                                    keys: keys,
                                    hasMore: keys.count == context)
        default:
            return KeyRangeResponse(success: false,
                error: KineticRemoteError.fromStatus(raw.command.status),
                keys: [], hasMore: false)
        }
    }
}

extension KeyRangeResponse: CustomStringConvertible {
    public var description: String {
        if self.success {
            return "Success (length: \(self.keys.count))"
        } else if self.error!.message.isEmpty {
            return "\(self.error!.code)"
        } else {
            return "\(self.error!.code): \(self.error!.message)"
        }
    }
}

extension GetKeyRangeCommand: CustomStringConvertible {
    public var description: String {
        return "GetKeyRange \(self.range)"
    }
}

public extension KineticSession {
    func getKeyRange<K>(range: Range<K>, reverse: Bool = false) throws -> GetKeyRangeCommand<K>.ResponseType {
        let cmd = GetKeyRangeCommand(range, reverse: reverse, maxReturned: nil)
        return try cmd.sendTo(self)
    }
    func getKeyRange<K>(range: Range<K>, reverse: Bool, maxReturned: Int) throws -> GetKeyRangeCommand<K>.ResponseType {
        let cmd = GetKeyRangeCommand(range, reverse: reverse, maxReturned: maxReturned)
        return try cmd.sendTo(self)
    }
}