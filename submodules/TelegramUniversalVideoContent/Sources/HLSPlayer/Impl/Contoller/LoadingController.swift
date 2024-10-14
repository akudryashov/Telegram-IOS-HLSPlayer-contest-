//
//  Created by qubasta on 08.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

final class LoadingController {
    enum State {
        case empty
        case loading
        case loaded(HLSVariant)
    }

    private let loader: HLSLoader
    private let streamLoader: HLSOrchestredStreamLoader
    private var config: HLSConfig?
    private var lastChoosenVariant: HLSVariant?
    private var lastExpectedVariant: HLSVariant?

    var state: HLSSignal<State> {
        stateSignal
    }
    private var stateSignal = DefaultSignal<State>()
    private var stateImpl: State = .empty {
        didSet {
            stateSignal.send(stateImpl)
        }
    }
    @Atomic(.automatic)
    private(set) var strategy: LoadingStrategy
    var loadingOptions: [LoadingStrategyOption] {
        if config?.isMasterConfig ?? false {
            config?.variants.map { .init(
                bandwidth: $0.additionalInfo.bandwidth
            ) } ?? []
        } else {
            []
        }
    }

    init(
        loader: HLSLoader,
        streamLoader: HLSOrchestredStreamLoader
    ) {
        self.loader = loader
        self.streamLoader = streamLoader

        FNMNetworkMonitor.shared.subscribe(observer: self)
    }

    func setLoadingStrategy(to strategy: LoadingStrategy) {
        self.strategy = strategy
        switch strategy {
        case .automatic:
            break
        case let .current(option):
            guard
                let variant = config?.variants.first(where: { $0.additionalInfo.bandwidth == option.bandwidth })
            else { return }
            chooseVariant(variant: variant)
        }
    }

    func startLoading(url: URL) {
        stateImpl = .loading
        loader.loadConfig(url: url) { [weak self] result in
            guard let self else { return }
            do {
                let config = try result.get()
                guard let variant = config.variants.first else {
                    throw HLSConfigError.missingVariants
                }
                self.config = config

                chooseVariant(variant: variant)
            } catch {
                print("failed to load config: \(error)")
                stateImpl = .empty
            }
        }
    }

    private func chooseVariant(variant: HLSVariant) {
        guard
            (variant != lastChoosenVariant &&
            variant != lastExpectedVariant &&
            streamLoader.migrationAllowed) || !strategy.isAutomatic
        else { return }
        lastExpectedVariant = variant

        print("[LoadingController] choose \(variant.debugInfo)")
        loader.loadFullConfigIfNeeded(variant: variant) { [weak self] result in
            guard let self else { return }
            do {
                let full = try result.get()
                try streamLoader.choose(
                    fullVariant: full,
                    strategy: strategy
                )
                stateImpl = .loaded(.full(full))
                lastChoosenVariant = variant
            } catch {
                switch stateImpl {
                case .loading:
                    stateImpl = .empty
                case .loaded, .empty:
                    break
                }
                lastExpectedVariant = nil
            }
        }
    }
}

extension LoadingController: FNMNetworkMonitorObserver {
    func recordsUpdated(records: [FNMHTTPRequestRecord]) {
        guard
            let currentVariantIndex = config?.variants.firstIndex(where: {$0 == lastChoosenVariant}),
            case .automatic = strategy
        else { return }

        let filteredRecords = records.filter {
            $0.responseSize > 10000 ||
            $0.request.url?.lastPathComponent.hasSuffix(".ts") ?? false
        }
        .sorted(by: { $0.startTimestamp > $1.startTimestamp })
        .prefix(3)

        let speeds = filteredRecords.map { record in
            if let responseLoadingTime = record.responseLoadingTime {
                return Double(record.responseSize) / responseLoadingTime
            } else {
                return 0
            }
        }
        guard !speeds.isEmpty else {
            return
        }

        let mean = Int(speeds.reduce(0, +) / Double(speeds.count))
        print("[LoadingController] mean speed: \(mean)")
        let expectedVariantIndex = config?.variants.lastIndex(where: { $0.additionalInfo.bandwidth < mean }) ?? 0
        guard
            currentVariantIndex != expectedVariantIndex
        else { return }
        let nextVariant: HLSVariant?
        if expectedVariantIndex - currentVariantIndex > 0 {
            nextVariant = config?.variants[currentVariantIndex + 1]
        } else {
            nextVariant = config?.variants[expectedVariantIndex]
        }
        guard let nextVariant else { return }

        print("[LoadingController] updates config: \(nextVariant.debugInfo) from \(String(describing: config?.variants.count))")
        chooseVariant(variant: nextVariant)
    }
}

extension HLSVariant {
    fileprivate var debugInfo: String {
        "\(additionalInfo.name) - \(additionalInfo.bandwidth)"
    }
}
