//: ## Example 2 - Basics

import Kinetic

//: ### Conneting with a Kinetic device
//: To connect to a Kinetic device over the network you need three things:
//: - [_Required_] A network address
//: - [_Optional_] a port (by default it is **8123**)
//: - [_Optional_] and a timeout
let c = try Kinetic.connect("localhost")
try Kinetic.connect("localhost", port: 8123) // timeout: `NetworkChannel.DEFAULT_CONNECT_TIMEOUT`
try Kinetic.connect("localhost", port: 8123, timeout: .In(3)) // 3 seconds

//: ### The `KeyType` and `ValueType`
//: Anything that conforms with `KeyType` can be considered a key on any command.
//: The built-in key types are: 
//: - `String`
//: - `NSData`
let x: KeyType = "some-key"
let y: KeyType = "some-other-key".toData()

//: Similarly, the `ValueType` is used for commands that require a value.
//: The built-in value types are also `String` and `NSData`.

//: ### Put
// Coming soon...

//: ### Get
// Coming soon..

//: ### Delete
// Coming soon..

//: ### Range
//: We have multiple ways to represent a range:
Range.From("some-key", true)      // from some-key (inclusive-start) to the end
Range.To("some-other-key", false) // from '' to some-other-key (exclusive-end)
Range.FromTo("a","z", true, true) // from a to b, both inclusive
Range.Prefix("/test/")            // everything that starts with /test/

//: To create a range command we use `GetKeyRangeCommand` which takes
//: a range, an order in which the keys will be returned, and a max number of keys
//: to be returned.
//: > **Note:** _the maximum numbers of keys allowed depends on the speicifc device_
let r = GetKeyRangeCommand(.From("", true), reverse: false, maxReturned: 10)

let range = try c.send(r)
range.keys // contains the keys in the range
range.hasMore // if the total # of keys reached the max limit, `hasMore` will be True

//: For a short-hand version of the command
try c.getKeyRange(.Prefix("demo"))
try c.getKeyRange(.Prefix("demo"), reverse: true)
try c.getKeyRange(.Prefix("demo"), reverse: true, maxReturned: 42)

c.close()
