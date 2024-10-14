//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

final class HLSLoader: HLSChunkLoader {
    enum HLSError: Error {
        case invalidConfig
        case missingFullConfig
        case missingURL
        case missingChunkData
    }

    private let session = HTTPSession()
    @Atomic([])
    private var cancellables: [Cancellable]
    @Atomic([:])
    private var cachedVariants: [URL: HLSVariant.Full]

    private func reset() {
        _cachedVariants.mutate { $0.removeAll() }
        _cancellables.mutate { $0.removeAll() }
    }

    func loadConfig(
        url: URL,
        additionalInfo: HLSVariant.AdditionalInfo? = nil,
        completion: @escaping (Result<HLSConfig, Error>) -> Void
    ) {
        if let host = url.host, session.host != host {
            if session.host.isSome {
                session.stopMonitoring()
            }
            session.startMonitoring(host: host)
            reset()
        }
        let task = session.httpTask(
            with: URLRequest(url: url)
        ) { result in
            do {
                let data = try result.get().data.get(elseThrow: HLSError.invalidConfig)
                let contents = String(decoding: data, as: UTF8.self)
                let config = try HLSConfig(raw: contents, configURL: url, additionalInfo: additionalInfo)
                completion(.success(config))
            } catch {
                print("failed to load master config: \(error)")
                completion(.failure(error))
            }
        }
        _cancellables.mutate { $0.append(task) }
    }

    func loadFullConfigIfNeeded(
        variant: HLSVariant,
        completion: @escaping (Result<HLSVariant.Full, Error>) -> Void
    ) {
        switch variant {
        case let .ref(info):
            if let full = cachedVariants[info.url] {
                completion(.success(full))
                return
            }
            loadConfig(
                url: info.url,
                additionalInfo: info
            ) { [weak self] result in
                let variantFull = try? result.get().variants.first?.full
                self?._cachedVariants.mutate { $0[info.url] = variantFull }

                completion(Result(catching: {
                    try variantFull.get(elseThrow: HLSError.missingFullConfig)
                }))
            }
        case let .full(full):
            completion(.success(full))
            return
        }
    }

    func loadChunk(
        configURL: URL,
        chunk: HLSChunk,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let url = configURL
            .deletingLastPathComponent()
            .appendingPathComponent(chunk.uri)
        var request = URLRequest(url: url)
        request.timeoutInterval = 25

        let task = session.httpTask(with: request) { result in
            do {
                completion(.success(try result.get().data.get(elseThrow: HLSError.missingChunkData)))
            } catch {
                completion(.failure(error))
            }
        }
        _cancellables.mutate { $0.append(task) }
    }
}
