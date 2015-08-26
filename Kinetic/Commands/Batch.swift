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

internal struct NoResponse : ChannelResponse {
    typealias ContextType = Void
    let success: Bool
    let error: KineticRemoteError?
    
    init() {
        self.success = true
        self.error = nil
    }
    
    static func parse(raw: RawResponse, context: Void) -> NoResponse {
        return NoResponse()
    }
}

class BatchBeginCommand : ChannelCommand {
    
    typealias ResponseType = VoidResponse
    
    private static var nextBatchId: UInt32 = 1
    
    private let batchId: UInt32
    
    internal init() {
        self.batchId = BatchBeginCommand.nextBatchId++
    }
    
    func build(builder: Builder, device: KineticDevice) {
        builder.header.messageType = .StartBatch
        builder.header.batchId = self.batchId
    }
    
}

class BatchPutCommand : ChannelCommand {
    
    typealias ResponseType = NoResponse
    
    let batchId: UInt32
    let key: KeyType
    let value: ValueType
    
    internal init(batchId: UInt32, key: KeyType, value: ValueType) {
        self.batchId = batchId
        self.key = key
        self.value = value
    }
    
    func build(builder: Builder, device: KineticDevice) {
        builder.header.messageType = .Put
        builder.header.batchId = self.batchId
        builder.keyValue.key = self.key.toData()
        builder.keyValue.tag = "1337".toData()
        builder.keyValue.algorithm = .Sha1
        builder.value = value.toBytes()
    }
    
}

class BatchDeleteCommand : ChannelCommand {
    
    typealias ResponseType = NoResponse
    
    let batchId: UInt32
    let key: KeyType
    
    internal init(batchId: UInt32, key: KeyType) {
        self.batchId = batchId
        self.key = key
    }
    
    func build(builder: Builder, device: KineticDevice) {
        builder.header.messageType = .Delete
        builder.header.batchId = self.batchId
        builder.keyValue.key = self.key.toData()
    }
    
}

class BatchCommitCommand : ChannelCommand {
    
    typealias ResponseType = VoidResponse // TODO: create a BatchCommitResponse
    
    let batchId: UInt32
    let count: Int32
    
    internal init(batchId: UInt32, count: Int32) {
        self.batchId = batchId
        self.count = count
    }
    
    func build(builder: Builder, device: KineticDevice) {
        builder.header.messageType = .EndBatch
        builder.header.batchId = self.batchId
        builder.batch.count = self.count
    }
    
}

class BatchAbortCommand : ChannelCommand {
    
    typealias ResponseType = VoidResponse
    
    let batchId: UInt32
    
    internal init(batchId: UInt32) {
        self.batchId = batchId
    }
    
    func build(builder: Builder, device: KineticDevice) {
        builder.header.messageType = .AbortBatch
        builder.header.batchId = self.batchId
    }
    
}

public enum BatchErrors: KineticError {
    case BatchIsNotActive
}

public class Batch {
    
    public unowned let session: KineticSession
    
    public let id: UInt32
    public private(set) var count: UInt
    public private(set) var aborted: Bool
    public private(set) var commited: Bool
    
    public var active: Bool { return !self.aborted  && !self.commited }
    
    internal init(_ session: KineticSession, id: UInt32) {
        self.session = session
        self.id = id
        self.count = 0
        self.aborted = false
        self.commited = false 
    }
    
    public func put(key: KeyType, value: ValueType) throws {
        guard self.active else { throw BatchErrors.BatchIsNotActive }
        
        let cmd = BatchPutCommand(batchId: self.id, key: key, value: value)
        try self.session.send(cmd)
        self.count += 1
    }
    
    public func delete(key: KeyType) throws {
        guard self.active else { throw BatchErrors.BatchIsNotActive }
        
        let cmd = BatchDeleteCommand(batchId: self.id, key: key)
        try self.session.send(cmd)
        self.count += 1
    }
    
    public func commit() throws {
        guard self.active else { throw BatchErrors.BatchIsNotActive }
        
        let cmd = BatchCommitCommand(batchId: self.id, count: Int32(self.count))
        try self.session.send(cmd)
        self.commited = true
    }
    
    public func abort() throws {
        guard self.active else { throw BatchErrors.BatchIsNotActive }
        
        let cmd = BatchAbortCommand(batchId: self.id)
        try self.session.send(cmd)
        self.aborted = true
    }
    
}

public extension KineticSession {
    func beginBatch() throws -> Batch {
        let cmd = BatchBeginCommand()
        try self.send(cmd)
        return Batch(self, id: cmd.batchId)
    }
    
    func swap(a: KeyType, _ b: KeyType) throws {
        let ar = try self.get(a)
        let br = try self.get(b)
        let batch = try self.beginBatch()
        try batch.put("a", value: br.value!)
        try batch.put("b", value: ar.value!)
        try batch.commit()
    }
}