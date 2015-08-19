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

import CryptoSwift
import BrightFutures

public typealias Bytes = [UInt8]

func bytesToUInt32(bytes:Array<UInt8>, offset:Int) -> UInt32 {
    let upper = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset+1]) << 16
    let lower = UInt32(bytes[offset+2]) << 8 | UInt32(bytes[offset+3])
    return upper | lower
}

func copyFromUInt32(inout bytes:Array<UInt8>, offset:Int, value:UInt32) {
    bytes[offset+0] = UInt8((value & 0xFF000000) >> 24)
    bytes[offset+1] = UInt8((value & 0x00FF0000) >> 16)
    bytes[offset+2] = UInt8((value & 0x0000FF00) >> 8)
    bytes[offset+3] = UInt8((value & 0x000000FF))
}

public extension String {
    func toUtf8() -> Bytes {
        var decodedBytes = Bytes()
        for b in self.utf8 {
            decodedBytes.append(b)
        }
        return decodedBytes
    }
    
    static func fromUtf8(bytes: Bytes) -> String {
        return NSString(bytes: bytes, length: bytes.count, encoding:NSUTF8StringEncoding)!.description
    }
}

extension NSData {    
    
    public func toUtf8() -> String {
        return NSString(data: self, encoding:NSUTF8StringEncoding)!.description
    }
    
    func hmacSha1(key: String) -> NSData {
        // create array of appropriate length:
        var array = Bytes(count: self.length + 4, repeatedValue: 0)
        copyFromUInt32(&array, offset: 0, value: UInt32(self.length))
        
        // copy bytes into array
        self.getBytes(&array + 4, length: self.length) // gives me goosebumps
        
        //mac.update(struct.pack(">I", len(entity)))
        //mac.update(entity)
        
        let hmac = Authenticator.HMAC(key: key.toUtf8(), variant: .sha1).authenticate(array)!
        return NSData(bytes: hmac, length: hmac.count)
    }
}

public func > <T>(operation: () throws -> T, wrapper: ErrorType -> ErrorType) throws -> T {
    do {
        return try operation()
    } catch let err {
        throw wrapper(err)
    }
}

public extension TimeInterval {
    
    public func wait<T> (operation: () -> T) throws -> T {
        let p = Promise<T, NoError>()
        
        Queue.global.async {
            let t = operation()
            p.trySuccess(t) // can this fail?
        }
        
        guard let v = p.future.forced(self) else {
            throw KineticSessionErrors.Timeout
        }
        
        return v.value!
    }
    
}

