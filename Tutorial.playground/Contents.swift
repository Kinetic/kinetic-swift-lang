//: Playground - noun: a place where people can play

import Kinetic

let c = Kinetic.connect("localhost", port: 8123)

// commands
let put = PutCommand(key:"nacho", value:"awesome")
try put.sendTo(c)

let get = GetCommand(key:"nacho")
let x = try get.sendTo(c)
String.fromUtf8(x.value!)

// convenience extensions on the channel
try c.put("hello", value: "from swift!")
let v = try c.get("hello")
String.fromUtf8(v.value!)
let v2 = try c.get("wooow")
v2.exists

var d = try c.delete("hello")
d.exists
d = try c.delete("hello")
d.exists