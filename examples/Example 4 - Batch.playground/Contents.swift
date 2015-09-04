//: Playground - noun: a place where people can play

import Kinetic

let c = try Kinetic.connect("localhost", port: 8123)

try c.put("a", value: "10")
try c.put("b", value: "200")
try c.swap("a","b")

try c.get("a").value!.toUtf8String()
try c.get("b").value!.toUtf8String()

c.close()