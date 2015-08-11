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

public struct EmptyResponse : ChannelResponse {
    public let success: Bool
    public let error: KineticRemoteError?
    
    public static func parse(raw: RawResponse) -> EmptyResponse {
        return EmptyResponse(success: raw.command.status.code == .Success,
            error: KineticRemoteError.fromStatus(raw.command.status))
    }
}

public struct ValueResponse : ChannelResponse {
    public let success: Bool
    public let error: KineticRemoteError?
    public let value: Bytes?
    
    public var hasValue: Bool { return value != nil }
    
    public static func parse(raw: RawResponse) -> ValueResponse {
        switch raw.command.status.code {
        case .Success, .NotFound:
            return ValueResponse(success: true, error: nil, value: raw.value)
        default:
            return ValueResponse( success: false,
            error: KineticRemoteError.fromStatus(raw.command.status),
            value: raw.value)
        }
    }
    
    public var description: String {
        get {
            if self.success {
                if self.hasValue {
                    return "Success (length: \(self.value!.count))"
                } else {
                    return "Success (Empty)"
                }
            } else {
                return "\(self.error?.code): \(self.error?.message)"
            }
        }
    }

}