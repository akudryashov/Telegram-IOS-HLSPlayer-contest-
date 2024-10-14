//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import SwiftUI
import Metal
import AVFoundation

public final class HLSPlayerCore {
    public let view: MTHKView
    public var playbackController: Playback

    private let loadingController: LoadingController
    private let audioPlayer: AudioPlayer

    init() {
        let view = MTHKView(frame: .zero)
        self.view = view
        let audioPlayer = AudioPlayer(audioEngine: AVAudioEngine())
        self.audioPlayer = audioPlayer
        let hlk = HLKitStreamWrapper()
        hlk.addOutput(view)
        hlk.attachAudioPlayer(audioPlayer)

        let loader = HLSLoader()
        let playbackTimeProvider: () -> TimeInterval? = { hlk.currentTime }
        let streamLoader = HLSOrchestredStreamLoader(
            playbackTimeProvider: playbackTimeProvider,
            streamLoaderFactory: {
                HLSStreamLoaderImpl(
                    loader: loader,
                    mediaVariant: $0,
                    playbackTimeProvider: playbackTimeProvider
                )
            }
        )
        loadingController = LoadingController(
            loader: loader,
            streamLoader: streamLoader
        )
        let playbackController = PlaybackController(
            loadingController: loadingController,
            hlk: hlk
        )
        hlk.attachPlaybackController(playbackController)
        hlk.loader = streamLoader
        self.playbackController = playbackController
    }
}
