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
