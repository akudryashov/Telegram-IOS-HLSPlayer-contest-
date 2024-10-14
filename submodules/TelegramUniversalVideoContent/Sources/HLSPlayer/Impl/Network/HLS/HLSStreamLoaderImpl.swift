//
//  Created by qubasta on 08.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import AVFoundation
import Foundation

final class HLSStreamLoaderImpl: HLSStreamLoader {
    struct RefChunk {
        let chunk: HLSChunk
        let index: Int
    }
    struct LoadedChunk {
        let data: Data
        let index: Int
    }
    
    var output: HLSSignal<TSBuffer> {
        reader.output
    }

    private let playbackTimeProvider: () -> TimeInterval?
    private let reader = TSReader()
    private var chunks: [RefChunk] = []
    private var position = 0
    private var nextLoadingTask: Cancellable?
    private var buffer = RingBuffer<LoadedChunk>(capacity: 10)
    var isRunning: Bool = false
    private var lastLoadedPosition: Int?
    private var lastDecodedPosition: Int?
    private var decodingCancellable: Cancellable?
    private(set) var configVariant: HLSVariant.Full?

    weak var loader: (any HLSChunkLoader)?

    private var name: String {
        configVariant?.additionalInfo.name ?? "???"
    }

    init(
        loader: any HLSChunkLoader,
        mediaVariant: HLSVariant.Full,
        playbackTimeProvider: @escaping () -> TimeInterval?
    ) {
        self.playbackTimeProvider = playbackTimeProvider
        self.loader = loader
        configVariant = mediaVariant
        chunks = mediaVariant.chunks.enumerated().map { RefChunk(chunk: $0.element, index: $0.offset) }
    }

    private func scheduleLoading() {
        nextLoadingTask?.cancel()
        guard
            isRunning,
            let currentTime = playbackTimeProvider(),
            position < chunks.count,
            chunks[position].chunk.startTime - currentTime < 20,
            lastLoadedPosition != position,
            lastDecodedPosition != position
        else {
            nextLoadingTask = GCD.after(delay: 10) { [weak self] in
                self?.scheduleLoading()
            }
            return
        }
        loadIfNeeded()
    }

    private func loadIfNeeded() {
        nextLoadingTask?.cancel()
        let ref = chunks[position]
        if let head = buffer.first {
            let location = position - head.index

            if location >= 0, let current = buffer.at(index: location) {
                print("[StreamLoader][\(name)] loaded from cache: \(location) \(current.data)")
                decodeData(current.data)
                scheduleLoading()
                return
            }
        }
        guard let url = configVariant?.additionalInfo.url else { return }

        loader?.loadChunk(
            configURL: url,
            chunk: ref.chunk,
            completion: { [weak self] in
                switch $0 {
                case let .success(data):
                    self?.onRecvChunk(ref, data: data)
                case let .failure(error):
                    self?.failedLoadChunk(ref, error: error)
                }
            }
        )
        print("[StreamLoader][\(name)] starts loading: \(position)=\(ref.index)")
    }

    private func onRecvChunk(_ ref: RefChunk, data: Data) {
        GCD.onMainThread { [self] in
            print("[StreamLoader][\(name)] recv: \(data.count) at: \(ref.chunk.startTime)")
            lastLoadedPosition = position
            buffer.enqueue(LoadedChunk(data: data, index: position))
            decodeData(data)
            scheduleLoading()
        }
    }

    private func failedLoadChunk(_ ref: RefChunk, error: any Error) {
        print("[StreamLoader][\(name)] failed to load: \(ref.chunk.uri) - \(error)")
        // TODO: Drop with retries
        scheduleLoading()
    }

    private func decodeData(_ data: Data) {
        guard reader.isRunning else { return }

        lastDecodedPosition = position
        reader.read(
            data,
            from: playbackTimeProvider() ?? 0
        )
        position += 1
    }
}

extension HLSStreamLoaderImpl: Runner {
    func start() {
        print("[StreamLoader][\(name)] started")
        isRunning = true
        reader.start()
        loadIfNeeded()
    }

    func pause(reset: Bool) {
        print("[StreamLoader][\(name)] paused")
        isRunning = false
        reader.pause()
        if reset {
            reader.reset {}
        }
    }

    func seek(to time: TimeInterval, completion: @escaping () -> Void) {
        let searchChunk = HLSChunk(startTime: time)
        let value = chunks.reversed()
            .lowerBound(searchItem: RefChunk(chunk: searchChunk, index: 0)) {
                $0.chunk.startTime > $1.chunk.startTime
            }
        guard let value else { return }

        print("[StreamLoader][\(name)] Found chunk at \(value.chunk.startTime) for time: \(time), \(value.index)")
        position = value.index
        lastDecodedPosition = nil
        reader.reset(completion)
    }
}
