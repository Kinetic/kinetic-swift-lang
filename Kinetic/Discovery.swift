//
//  Discovery.swift
//  Kinetic
//
//  Created by James Hughes on 9/4/15.
//  Copyright © 2015 Seagate. All rights reserved.
//

import Foundation
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
    

    
    
    public private(set) var discoverRunning: Bool = false
    public private(set) var error:ErrorType? = nil
    
    private var discoverStopping = false
    private var s:Datagram? = nil

    
    init (multicast mAddr:String = "239.1.2.3", port mPort:String = "8123", timeout:Double = 0, f:(AnyObject)->()) throws {
        
        s = try Datagram(multicast: mAddr, port: mPort)
        
        discoverRunning = true
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            do {
                defer {
                    self.discoverRunning = false
                }
    
                while true {
                    // recieve it on the multicast socket
                    var (_, _, bytes) = try self.s!.recv(65535, timeout:timeout) // assumes you have access to
                    if self.discoverStopping {
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
        discoverStopping = true
        s!.sockClose()
    }
}