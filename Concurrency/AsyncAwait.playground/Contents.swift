import Foundation


// MARK: - Example 1: Async/Await and Task

struct CurrentDate: Decodable {
    let date: String
}

final class Clock {
    func printDate() async {
        guard let currentDate = await getDate() else { return }
        print(currentDate)
    }

    private func getDate() async -> CurrentDate? {
        guard let url = URL(
            string: "https://ember-sparkly-rule.glitch.me/current-date"
        ) else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try? JSONDecoder().decode(CurrentDate.self, from: data)
        } catch {
            return nil
        }
    }
}

let clock = Clock()
Task {
    await clock.printDate()
}


// MARK: - Example 2: Continuation

enum NetworkError: Error {
    case badURL
    case noData
    case decodingError
}

struct Post: Decodable {
    let title: String
}

func getPosts(completion: @escaping (Result<[Post], NetworkError>) -> Void) {
    guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
        return completion(.failure(.badURL))
    }
    URLSession.shared.dataTask(with: url) { data, _, error in
        guard let data = data, error == nil else { return completion(.failure(.noData)) }
        do {
            let posts = try JSONDecoder().decode([Post].self, from: data)
            completion(.success(posts))
        } catch {
            completion(.failure(.decodingError))
        }
    }.resume()
}

func getPosts() async throws -> [Post] {
    try await withCheckedThrowingContinuation { continuation in
        getPosts { result in
            switch result {
            case .success(let posts):
                continuation.resume(returning: posts)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

Task {
    do {
        let posts = try await getPosts()
    } catch {
        print(error)
    }
}


// MARK: - Example 3: Async let

struct Todo: Decodable {
    let title: String
}

struct Schedule {
    let todo: Todo
    let date: CurrentDate
}

func getSchedule(for id: Int) async throws -> Schedule {
    guard let todoURL = URL(string: "https://jsonplaceholder.typicode.com/todos/\(id)"),
          let dateURL = URL(string: "https://ember-sparkly-rule.glitch.me/current-date") else {
        throw NetworkError.badURL
    }

    /// This way, tasks are executed sequentially, which makes the function slower
    // let (todoData, _) = try await URLSession.shared.data(from: todoURL)
    // let (dateData, _) = try await URLSession.shared.data(from: dateURL)

    // let todo = try? JSONDecoder().decode(Todo.self, from: todoData)
    // let date = try? JSONDecoder().decode(CurrentDate.self, from: dateData)

    /// This way, the call is treated as asynchronous and control returns immediately, executing another task asynchronously
    async let (todoData, _) = URLSession.shared.data(from: todoURL)
    async let (dateData, _) = URLSession.shared.data(from: dateURL)

    let todo = try? JSONDecoder().decode(Todo.self, from: try await todoData)
    let date = try? JSONDecoder().decode(CurrentDate.self, from: try await dateData)

    guard let todo, let date else {
        throw NetworkError.decodingError
    }

    return Schedule(todo: todo, date: date)
}

Task {
    do {
        print(try await getSchedule(for: 1))
    } catch {
        print(error)
    }
}


// MARK: - Example 4: Cancelation

let ids = [1, 2, 3]

Task {
    for id in ids {
        do {
            try Task.checkCancellation()
            let schedule = try await getSchedule(for: id)
            print(schedule)
        } catch {
            print(error)
        }
    }
}


// MARK: - Example 5: Async let in loop

/// This way, at each iteration of the loop it is necessary to wait for the asynchronous task to complete to continue to the next item
// Task {
//     for id in ids {
//         let schedule = try await getSchedule(for: id)
//         print(schedule)
//     }
// }

func getSchedules(for ids: [Int]) async throws -> [Int: Schedule] {
    var schedules: [Int: Schedule] = [:]

    try await withThrowingTaskGroup(of: (Int, Schedule).self) {
        for id in ids {
            $0.addTask {
                return (id, try await getSchedule(for: id))
            }
        }

        for try await (id, schedule) in $0 {
            print("\(id): \(schedule)")
            schedules[id] = schedule
        }
    }

    return schedules
}

Task {
    let _ = try await getSchedules(for: ids)
}

// MARK: - Example 6: Async Sequence

struct Lines: Sequence {
    let url: URL

    func makeIterator() -> some IteratorProtocol {
        let lines = (try? String(contentsOf: url))?.split(separator: "\n") ?? []
        return LinesIterator(lines: lines)
    }
}

struct LinesIterator: IteratorProtocol {
    typealias Element = String

    var lines: [String.SubSequence]

    mutating func next() -> Element? {
        lines.isEmpty ? nil : String(lines.removeFirst())
    }
}

let earthquakeURL = URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv")!

/// Sync Sequence
// extension URL {
//     func allLines() async -> Lines {
//         Lines(url: self)
//     }
// }
//
// Task {
//     for line in await earthquakeURL.allLines() {
//         print(line)
//     }
// }

/// Async Sequence
Task {
    for try await line in earthquakeURL.lines {
        print(line)
    }
}


// MARK: - Example 7: AsyncStream

final class PriceMonitor {
    var completion: (Double) -> Void = { _ in }
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(getPrice), userInfo: nil, repeats: true)
    }

    func stop() {
        timer?.invalidate()
    }

    @objc private func getPrice() {
        completion(Double.random(in: 20000...40000))
    }
}

let priceStream = AsyncStream(Double.self) { continuation in
    let priceMonitor = PriceMonitor()
    priceMonitor.completion = { continuation.yield($0) }
    priceMonitor.start()
}

Task {
    for await price in priceStream {
        print(price)
    }
}


