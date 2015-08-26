import Foundation

public class PosixError: NSError {
    
    var s:String = ""
    let callStack = NSThread.callStackSymbols()
    
    public override var description:String {
        return (super.description + ", " + s)
    }
    
    public init (comment: String) {
        s = comment
        super.init(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
