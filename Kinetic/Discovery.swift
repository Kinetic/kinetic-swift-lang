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

// @author: James Hughes

import Socket

public class KineticDiscovery {
    
    enum jroot:String {
        case firmware_version = "firmware_version"
        case manufacturer = "manufacturer"
        case model = "model"
        case network_interfaces = "network_interfaces"
        case port = "port"
        case protocol_version = "protocol_version"
        case serial_number = "serial_number"
        case tlsPort = "tlsPort"
        case world_wide_name = "world_wide_name"
    }
    
    enum jnet:String {
        case ipv4_addr = "ipv4_addr"
        case ipv6_addr = "ipv6_addr"
        case mac_addr = "mac_addr"
        case name = "name"
    }
    
    public private(set) var active: Bool
    public private(set) var error:ErrorType? = nil
    
    private var stopping: Bool
    private var socket: Datagram?
    
    init (multicast mAddr:String = "239.1.2.3", port mPort:String = "8123", timeout:Double = 0, f:(AnyObject)->()) throws {
        
        self.active = true
        self.stopping = false
        self.socket = try Datagram(multicast: mAddr, port: mPort)
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            do {
                defer {
                    self.active = false
                }
    
                while true {
                    // recieve it on the multicast socket
                    var (_, _, bytes) = try self.socket!.recv(65535, timeout:timeout) // assumes you have access to
                    if self.stopping {
                        return
                    }
                    let data = NSData(bytesNoCopy: &bytes, length: bytes.count, freeWhenDone:false)
                    let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
                    f(json)
                }
                
            } catch let x {
                self.error = x
            }
        }
    }
    
    public func stop() {
        self.active = true
        self.socket!.sockClose()
    }
}