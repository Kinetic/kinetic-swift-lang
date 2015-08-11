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

public enum KineticConnectionErrors: ErrorType {
    case InvalidMagicNumber
}

public enum StatusCode : Int {
    case InvalidStatusCode = -1
    case NotAttempted = 0
    case Success = 1
    case HmacFailure = 2
    case NotAuthorized = 3
    case VersionFailure = 4
    case InternalError = 5
    case HeaderRequired = 6
    case NotFound = 7
    case VersionMismatch = 8
    case ServiceBusy = 9
    case Expired = 10
    case DataError = 11
    case PermDataError = 12
    case RemoteConnectionError = 13
    case NoSpace = 14
    case NoSuchHmacAlgorithm = 15
    case InvalidRequest = 16
    case NestedOperationErrors = 17
    case DeviceLocked = 18
    case DeviceAlreadyUnlocked = 19
    case ConnectionTerminated = 20
    case InvalidBatch = 21
}

extension StatusCode {
    static func parse(protoCode: Command.Status.StatusCode) -> StatusCode {
        switch protoCode {
        case .InvalidStatusCode: return StatusCode.InvalidStatusCode
        case .NotAttempted: return StatusCode.NotAttempted
        case .Success: return StatusCode.Success
        case .HmacFailure: return StatusCode.HmacFailure
        case .NotAuthorized: return StatusCode.NotAuthorized
        case .VersionFailure: return StatusCode.VersionFailure
        case .InternalError: return StatusCode.InternalError
        case .HeaderRequired: return StatusCode.HeaderRequired
        case .NotFound: return StatusCode.NotFound
        case .VersionMismatch: return StatusCode.VersionMismatch
        case .ServiceBusy: return StatusCode.ServiceBusy
        case .Expired: return StatusCode.Expired
        case .DataError: return StatusCode.DataError
        case .PermDataError: return StatusCode.PermDataError
        case .RemoteConnectionError: return StatusCode.RemoteConnectionError
        case .NoSpace: return StatusCode.NoSpace
        case .NoSuchHmacAlgorithm: return StatusCode.NoSuchHmacAlgorithm
        case .InvalidRequest: return StatusCode.InvalidRequest
        case .NestedOperationErrors: return StatusCode.NestedOperationErrors
        case .DeviceLocked: return StatusCode.DeviceLocked
        case .DeviceAlreadyUnlocked: return StatusCode.DeviceAlreadyUnlocked
        case .ConnectionTerminated: return StatusCode.ConnectionTerminated
        case .InvalidBatch: return StatusCode.InvalidBatch
        }
    }
}

public struct KineticRemoteError: ErrorType {
    let code: StatusCode
    let message: String
    let detailedMessage: NSData
    
    // ErrorType
    public var _code: Int { return self.code.rawValue }
    public var _domain: String { return self.message }
    
    init(raw: Command.Status) {
        self.code = StatusCode.parse(raw.code)
        self.message = raw.statusMessage
        self.detailedMessage = raw.detailedMessage
    }

    static func fromStatus(status: Command.Status) -> KineticRemoteError? {
        switch status.code {
        case .Success: return nil
        default: return KineticRemoteError(raw: status)
        }
    }
}