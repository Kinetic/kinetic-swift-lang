import Foundation

public class Server {
    public var port: in_port_t = 0
    
    var socket:Stream? = nil
    
    public init(port p: String = "0", service:(Stream) -> ()) throws {
        socket = try Stream(listenPort: p)
        port = socket!.port
        dispatch_async(dispatch_get_global_queue(0,0)) {
            do {
                let instance = try self.socket!.acceptConnection()
                if instance == nil {
                    return
                }
                dispatch_async(dispatch_get_global_queue(0,0)) {
                    service(instance!)
                }
            } catch let x {
                print(x)
                self.shutDown()
            }
        }
    }
    
    public func shutDown() {
        socket!.releaseSock()
    }
}