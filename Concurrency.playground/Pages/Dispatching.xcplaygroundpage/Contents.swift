import Foundation


// MARK: - Example 1: Global vs. Custom Dispatch Queue

let globalQueue1 = DispatchQueue.global()
let globalQueue2 = DispatchQueue.global()

print("Global Queue 1: \(Unmanaged.passUnretained(globalQueue1).toOpaque())")
print("Global Queue 2: \(Unmanaged.passUnretained(globalQueue2).toOpaque())")

let customQueue1 = DispatchQueue(label: "custom queue 1")
let customQueue2 = DispatchQueue(label: "custom queue 2", attributes: [.concurrent])

print("Custom Queue 1: \(Unmanaged.passUnretained(customQueue1).toOpaque())")
print("Custom Queue 2: \(Unmanaged.passUnretained(customQueue2).toOpaque())\n")


// MARK: - Example 2: Serial vs. Concurrent Queue

print("Serial Dispatch Queue")
customQueue1.async {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
customQueue1.async {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
print("Concurrent Dispatch Queue")
customQueue2.async {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
customQueue2.async {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}


// MARK: - Example 3: Synchronous vs. Asynchronous dequeue

DispatchQueue.global().sync {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
DispatchQueue.global().sync {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
print("Return from sync tasks after completion")

DispatchQueue.global().async {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
DispatchQueue.global().async {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
print("Return from async tasks immediately")


// MARK: - Example 4: DispatchWorkItem

let workItem = DispatchWorkItem() {
    print("Stored task")
}
DispatchQueue.global().sync(execute: workItem)
DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1, execute: workItem)
workItem.cancel()


// MARK: - Example 5: Dispatch Group using wait

let group1 = DispatchGroup()
group1.enter()
DispatchQueue.global().async {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
    group1.leave()
}
group1.enter()
DispatchQueue.global().async {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
    group1.leave()
}
DispatchQueue.global().async {
    group1.wait()
    print("#5 finished")
}


// MARK: - Example 6: Dispatch Group using notify

let group2 = DispatchGroup()
DispatchQueue.global().async(group: group2) {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
DispatchQueue.global().async(group: group2) {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
group2.notify(queue: .main) {
    print("#6 finished")
}


// MARK: - Example 7: Dispatch barrier

let queue7 = DispatchQueue(label: "com.company.app.queue", attributes: [.concurrent])
queue7.async {
    for i in 0 ... 3 {
        print("A: \(i)")
    }
}
queue7.async {
    for i in 0 ... 3 {
        print("B: \(i)")
    }
}
queue7.async(flags: .barrier) {
    for i in 0 ... 3 {
        print("C: \(i)")
    }
}
queue7.async {
    print("#7 finished")
}
