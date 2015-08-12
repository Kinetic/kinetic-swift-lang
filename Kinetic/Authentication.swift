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

public protocol AuthenticationCredential {
    
    func authenticate(builder: Builder)
    
}

public struct HmacCredential: AuthenticationCredential  {
    public let identity: Int64
    public let key: String

    public static func defaultCredentials() -> HmacCredential {
        return HmacCredential(identity: 1, key: "asdfasdf")
    }
    
    public func authenticate(builder: Builder) {
        let m = builder.message
        m.authType = .Hmacauth
        
        let a = m.getHmacAuthBuilder()
        a.identity = self.identity
        a.hmac = m.commandBytes.hmacSha1(self.key)
    }
}