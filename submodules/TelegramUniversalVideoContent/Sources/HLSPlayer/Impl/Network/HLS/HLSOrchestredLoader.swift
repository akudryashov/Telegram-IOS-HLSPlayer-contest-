//
//  Created by qubasta on 26.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

final class HLSOrchestredStreamLoader: HLSStreamLoader {
    enum Error: Swift.Error {
        case failedToChooseStream
    }

    final class Stream {
        private var subscription: Cancellable?

        let name: String
        let loader: HLSStreamLoader
        var sample: TSBuffer?

        init(
            name: String?,
            loader: HLSStreamLoader,
            update: @escaping () -> Void
        ) {
            self.name = name ?? "???"
            self.loader = loader
            subscription = loader.output.sink { [unowned self] in
                sample = $0
                update()
            }
        }

        deinit {
            cancel()
        }

        func cancel() {
            subscription?.cancel()
        }
    }

    var configVariant: HLSVariant.Full? {
        currentStream?.loader.configVariant
    }
    var output: HLSSignal<TSBuffer> {
        outputImpl
    }
    private let outputImpl = DefaultSignal<TSBuffer>()
    private(set) var isRunning: Bool = false

    var migrationAllowed: Bool {
        !onMigration && (isRunning || currentStream.isNone)
    }
    private var onMigration: Bool = false
    private var lastSample: TSBuffer?

    private let playbackTimeProvider: () -> TimeInterval?
    private let streamLoaderFactory: (HLSVariant.Full) -> HLSStreamLoaderImpl
    private var currentStream: Stream?
    private var futureStream: Stream?

    init(
        playbackTimeProvider: @escaping () -> TimeInterval?,
        streamLoaderFactory: @escaping (HLSVariant.Full) -> HLSStreamLoaderImpl
    ) {
        self.playbackTimeProvider = playbackTimeProvider
        self.streamLoaderFactory = streamLoaderFactory
    }

    func choose(
        fullVariant variant: HLSVariant.Full,
        strategy: LoadingStrategy
    ) throws {
        let usingOneStream = !strategy.isAutomatic
        if usingOneStream {
            stopMigration()
        }
        guard currentStream?.loader.configVariant != variant else {
            throw Error.failedToChooseStream
        }
        guard futureStream?.loader.configVariant != variant, !onMigration else {
            throw Error.failedToChooseStream
        }
        let streamLoader = streamLoaderFactory(variant)
        if currentStream.isNone || usingOneStream {
            currentStream?.cancel()
            currentStream = Stream(
                name: variant.additionalInfo.name,
                loader: streamLoader,
                update: { [unowned self] in update() }
            )
            if isRunning {
                pause(reset: true)
                currentStream?.loader.start()
            }
        } else {
            futureStream?.cancel()
            futureStream = Stream(
                name: variant.additionalInfo.name,
                loader: streamLoader,
                update: { [unowned self] in update() }
            )
            migrateToFuture()
        }
    }

    private func migrateToFuture() {
        guard isRunning else { return }

        onMigration = true
        futureStream?.loader.start()
        print("[HLSOrchestratedStreamLoader] mark needs to migrate")
    }

    private func migrateIfNeeded() {
        guard onMigration, futureStream.isSome else { return }

        currentStream?.cancel()
        currentStream = futureStream
        futureStream = nil

        onMigration = false
        print("[HLSOrchestratedStreamLoader] migrated to \(String(describing: currentStream?.name))")
    }

    private func stopMigration() {
        guard onMigration || futureStream.isSome else {
            return
        }

        onMigration = false
        futureStream = nil
        print("[HLSOrchestratedStreamLoader] stops migration to \(String(describing: futureStream?.name))")
    }

    func update() {
        if onMigration,
            let currentTime = playbackTimeProvider(),
            let lastSample,
            let futureSample = futureStream?.sample,
            futureSample.ptr.mediaType == lastSample.ptr.mediaType,
            futureSample.pts.seconds > lastSample.pts.seconds,
            abs(futureSample.pts.seconds - lastSample.pts.seconds) < 0.5,
            futureSample.pts.seconds > currentTime + 5
        {
            migrateIfNeeded()
            outputImpl.send(futureSample)
            self.lastSample = futureSample
        } else if let sample = currentStream?.sample {
            outputImpl.send(sample)
            currentStream?.sample = nil
            lastSample = sample
        }
    }

    func seek(
        to time: TimeInterval,
        completion: @escaping () -> Void
    ) {
        print("[HLSOrchestratedStreamLoader] seek: \(time)")
        stopMigration()
        currentStream?.loader.seek(to: time, completion: completion)
    }

    func start() {
        print("[HLSOrchestratedStreamLoader] start")
        isRunning = true
        currentStream?.loader.start()
        futureStream?.loader.start()
    }

    func pause(reset: Bool) {
        print("[HLSOrchestratedStreamLoader] pause reset:\(reset)")
        isRunning = false
        currentStream?.loader.pause(reset: reset)
        futureStream?.loader.pause(reset: reset)
    }
}
