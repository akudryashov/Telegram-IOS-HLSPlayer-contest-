//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

final class HTTPSession {
    struct HTTPResponse {
        let response: HTTPURLResponse
        let data: Data?
    }
    
    enum HTTPError: Error {
        case invalidState
        case badResponse
    }

    private let session: URLSession
    private(set) var host: String?

    convenience init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = FNMNetworkMonitor.normalizedURLProtocols()
        let session = URLSession(configuration: configuration)
        self.init(session: session)
    }

    init(session: URLSession) {
        self.session = session
    }

    func startMonitoring(host: String) {
        self.host = host

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()
    }

    func stopMonitoring() {
        FNMNetworkMonitor.shared.stopMonitoring()
        host = nil
    }

    func httpTask(
        with request: URLRequest,
        retryStrategy: RetryStrategy? = SimpleRetryStrategy(),
        completion: @escaping (Result<HTTPResponse, Error>) -> Void
    ) -> Cancellable {
        HTTPRetryTask { [weak self] retryHandler in
            guard let self else {
                completion(.failure(HTTPError.invalidState))
                return AnyCancellable()
            }
            let task = session.dataTask(with: request) { data, response, error in
                guard
                    error.isNone,
                    let response = (response as? HTTPURLResponse),
                    (200...299).contains(response.statusCode)
                else {
                    if let retryStrategy,
                       retryStrategy.shouldRetry(response: response, error: error) {
                        retryHandler(retryStrategy.delay)
                    } else {
                        completion(.failure(error ?? HTTPError.badResponse))
                    }
                    return
                }
                completion(.success(HTTPResponse(response: response, data: data)))
            }
            task.resume()
            return task
        }
    }
}

private final class HTTPRetryTask: Cancellable {
    var makeRequest: (@escaping RetryCallback) -> Cancellable
    var task: Cancellable?
    var cancelled: Bool = false

    init(
        makeRequest: @escaping (@escaping RetryCallback) -> Cancellable
    ) {
        self.makeRequest = makeRequest
        startRequest()
    }

    private func startRequest() {
        guard !cancelled else { return }
        task = makeRequest() { [weak self] delay in
            if let delay {
                self?.task = GCD.after(delay: delay) {
                    self?.startRequest()
                }
            } else {
                self?.startRequest()
            }
        }
    }

    func cancel() {
        cancelled = true
        task?.cancel()
    }
}
