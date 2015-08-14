//: ## Example 2 - Async

import Kinetic
import XCPlayground

//: First connect to a `KineticDevice` by creating a `KineticSession`
let c = Kinetic.connect("localhost", port: 8123)

//: Create some command to send
let put = PutCommand(key: "hello", value: "world")

//: Ask the session to promise some result
print("Make me a promise...")
let future = c.promise(put)
future
    .onSuccess { v in
        print("Promised fulfilled.")
        print("Result: \(v)") }
    .andThen { _ in
        print("< closing session >")
        c.close() }

//: You can also force the value
future.forced(1.0)

//: Allow the background threads to do their work
XCPSetExecutionShouldContinueIndefinitely()
