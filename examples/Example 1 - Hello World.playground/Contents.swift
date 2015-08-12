//: Playground - noun: a place where people can play

import Kinetic

// Connect to a device
// This creates a KineticSession against a KineticDevice
let c = Kinetic.connect("localhost", port: 8123)

// Write a key/value pair
try c.put("hello", value: "world")

// Read the value back
let x = try c.get("hello")

// The Strings on the methods are just for convenience
// the actual values are byte arrays ([UInt8])
print("Received: \(String.fromUtf8(x.value!))")