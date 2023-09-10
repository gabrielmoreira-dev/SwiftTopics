import Foundation


// MARK: - Example 1: Block operation

let blockOperation = BlockOperation()
blockOperation.addExecutionBlock {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
blockOperation.addExecutionBlock {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
blockOperation.completionBlock = {
    print("#1 finished on \(Thread.current)")
}
DispatchQueue.global().async {
    print("#1 started")
    blockOperation.start()
    print("#1 finished")
}


// MARK: - Example 2: Custom Operations

final class MyOperation: Operation {
    // To run asynchronously
    override func start() {
        Thread.init(block: main).start()
    }

    override func main() {
        for i in 0 ... 3 {
            print("A: \(i)")
        }
    }
}

let myOperation = MyOperation()
myOperation.start()
print("#2 finished")


// MARK: - Example 3: Operations Queue

let operationQueue = OperationQueue()
let blockOperation1 = BlockOperation  {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
let blockOperation2 = BlockOperation  {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
let blockOperation3 = BlockOperation  {
    for i in 0 ... 3 {
        print("C: \(i)")
    }
}
//operationQueue.maxConcurrentOperationCount = 1 // 1 - To run as a serial queue
blockOperation3.addDependency(blockOperation2) // Block Operation 3 will execute only after BO 2
operationQueue.addOperations([blockOperation1, blockOperation2, blockOperation3], waitUntilFinished: false) // waitUntilFinished = true blocks the thread
print("#3 finished")


