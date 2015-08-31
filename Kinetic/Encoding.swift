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

public struct KineticEncoding {
    
    public enum Error: ErrorType {

        // normal case when the connection is closed. (eof on the identifier)
        case Closed
        // An EoF happened while reading the remainder of the header.
        case InvalidStream
        // there was 9 bytes, but the identifier was not correct. Stream out of sync.
        case InvalidIdentifier
    }
    
    public struct Header {
        public let bytes: Bytes
        
        public var isValid: Bool { return self.bytes[0] == 70 }
        
        public var protoLength: Int {
            return Int(bytesToUInt32(self.bytes, offset: 1))
        }
        
        public var valueLength: Int {
            return Int(bytesToUInt32(self.bytes, offset: 5))
        }
        
        public init(bytes: Bytes) throws {
            switch bytes.count {
            case 9:
                break
            case 0:
                throw Error.Closed
            default:
                throw Error.InvalidStream
            }
            self.bytes = bytes
            guard isValid else {
                throw Error.InvalidIdentifier
            }
        }
        
        public init(protoLength: Int, valueLength: Int) {
            var buffer = Bytes(count: 9, repeatedValue: 0)
            buffer[0] = 70 // Magic
            copyFromUInt32(&buffer, offset: 1, value: UInt32(protoLength))
            copyFromUInt32(&buffer, offset: 5, value: UInt32(valueLength))
            self.bytes = buffer
        }
    }
    
    public let header: Header
    public private(set) var proto: Bytes
    public private(set) var value: Bytes
    
    public init(_ header: Header, _ proto: Bytes, _ value: Bytes) {
        self.header = header
        self.proto = proto
        self.value = value
    }
    
    public static func encode(builder: Builder) throws -> KineticEncoding {
        let proto = try { try builder.message.build() } >
            { KineticEncodingErrors.EncodingFailure("Failed to build proto message.", $0) }
        
        let protoData = proto.data()
        let header = Header(protoLength: protoData.length, valueLength: builder.value.count)
        
        return KineticEncoding(header, protoData.toBytes(), builder.value)
    }
    
    public func decode() throws -> RawResponse {
        if !self.header.isValid {
            throw KineticEncodingErrors.InvalidMagicNumber
        }
        
        // TODO: make nocopy
        let protoData = NSData(bytes: self.proto, length: self.proto.count)
        let msg = try { try Message.parseFromData(protoData) } >
            { KineticEncodingErrors.DecodingFailure("Failed to parse message proto.", $0) }
        
        // TODO: verify HMAC
        
        let cmd = try { try Command.parseFromData(msg.commandBytes) } >
            { KineticEncodingErrors.DecodingFailure("Failed to parse command proto.", $0) }
        
        return RawResponse(message: msg, command: cmd, value: self.value)
    }
}

public extension Builder {
    public func encode() throws -> KineticEncoding {
        return try KineticEncoding.encode(self)
    }
}