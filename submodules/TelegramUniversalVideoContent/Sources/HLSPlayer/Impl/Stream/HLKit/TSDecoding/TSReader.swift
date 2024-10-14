import AVFoundation
import Foundation

/// A class represents that reads MPEG-2 transport stream data.
final class TSReader {
    /// An asynchronous sequence for reading data.
    var output: HLSSignal<TSBuffer> {
        outputImpl
    }
    private var pat: TSProgramAssociation? {
        didSet {
            guard let pat else {
                return
            }
            for (channel, PID) in pat.programs {
                programs[PID] = channel
            }
        }
    }
    private var pmt: [UInt16: TSProgramMap] = [:] {
        didSet {
            for pmt in pmt.values {
                for data in pmt.elementaryStreamSpecificData where esSpecData[data.elementaryPID] != data {
                    esSpecData[data.elementaryPID] = data
                }
            }
        }
    }
    private var timeCorrection: CMTime?
    private var programs: [UInt16: UInt16] = [:]
    private var esSpecData: [UInt16: ESSpecificData] = [:]
    private var outputImpl = DefaultSignal<TSBuffer>()
    private var nalUnitReader = NALUnitReader()
    private var formatDescriptions: [UInt16: CMFormatDescription] = [:]
    private var packetizedElementaryStreams: [UInt16: PacketizedElementaryStream] = [:]
    private var previousPresentationTimeStamps: [UInt16: CMTime] = [:]
    private var needSync: Bool = false
    private var invalidated: Bool = false
    private var lastVideoSyncTimeStamp: TimeInterval?

    private var actionsQueue = ActionQueue(queue: DispatchQueue(
        label: "com.hlsplayer.reader.\(UUID().uuidString.prefix(8))",
        qos: .userInitiated
    ))

    var isRunning: Bool { !actionsQueue.paused }

    /// Clears the reader object for new transport stream.
    func reset(_ completion: @escaping () -> Void = {}) {
        print("[TSReader] reset called")
        invalidated = true
        actionsQueue.paused = true
        actionsQueue.removeAll()
        actionsQueue.paused = false
        actionsQueue.enqueue { [unowned self] in
            pat = nil
            pmt.removeAll()
            programs.removeAll()
            esSpecData.removeAll()
            formatDescriptions.removeAll()
            packetizedElementaryStreams.removeAll()
            previousPresentationTimeStamps.removeAll()
            lastVideoSyncTimeStamp = nil
            needSync = true
            actionsQueue.paused = true
            completion()
            print("[TSReader] reset finished")
        }
    }

    func pause() {
        actionsQueue.paused = true
    }

    func start() {
        invalidated = false
        actionsQueue.paused = false
    }

    func read(_ data: Data, from: TimeInterval) {
        actionsQueue.enqueue { [unowned self] in
            print("[TSReader] schedule \(data.count) from: \(from)")

            splitIntoSmallerPackets(data, from: from)
        }
    }
    
    private func splitIntoSmallerPackets(_ data: Data, from: TimeInterval) {
        print("[TSReader] split-read \(data.count) from: \(from)")
        guard !invalidated else {
            print("[TSReader] invalidate split \(data.count) from: \(from)")
            return
        }
        var ptr = 0
        while ptr < data.endIndex {
            let end = min(ptr + 2000 * TSPacket.size, data.endIndex)
            let subdata = data.subdata(in: ptr..<end)
            ptr = end
            actionsQueue.enqueue { [unowned self] in
                readImpl(subdata, from: from)
            }
        }
    }

    /// Reads transport-stream data.
    private func readImpl(_ data: Data, from: TimeInterval) {
        //print("[TSReader] read \(data.count) from: \(from)")
        let count = data.count / TSPacket.size
        for i in 0..<count {
            guard !invalidated else {
                print("[TSReader] invalidate readImpl \(data.count)")
                return
            }
            guard let packet = TSPacket(data: data.subdata(in: i * TSPacket.size..<(i + 1) * TSPacket.size)) else {
                continue
            }
            if packet.pid == 0x0000 {
                pat = TSProgramAssociation(packet.payload)
                continue
            }
            if let channel = programs[packet.pid] {
                pmt[channel] = TSProgramMap(packet.payload)
                continue
            }
            if let buffer = readPacketizedElementaryStream(packet) {
                if buffer.pts.seconds >= from - 2 {
                    switch buffer.ptr.mediaType {
                    case .video:
                        if needSync, buffer.isSync {
                            send(buffer: buffer)
                            lastVideoSyncTimeStamp = buffer.pts.seconds
                            needSync = false
                        } else if !needSync {
                            send(buffer: buffer)
                        }
                    case .audio:
                        if let lastVideoSyncTimeStamp, buffer.pts.seconds >= lastVideoSyncTimeStamp {
                            send(buffer: buffer)
                            self.lastVideoSyncTimeStamp = nil
                        } else if lastVideoSyncTimeStamp.isNone, !needSync {
                            send(buffer: buffer)
                        }
                    case .none:
                        break
                    }
                }
            }
        }
    }

    private func send(buffer: TSBuffer) {
        guard !invalidated else {
            print("[TSReader] invalidate send \(buffer.pts.seconds)")
            return
        }
        guard !actionsQueue.paused else {
            actionsQueue.enqueue { [weak self] in
                self?.outputImpl.send(buffer)
            }
            return
        }
        outputImpl.send(buffer)
    }

    private func readPacketizedElementaryStream(_ packet: TSPacket) -> TSBuffer? {
        if packet.payloadUnitStartIndicator {
            let sampleBuffer = makeSampleBuffer(packet.pid, forUpdate: true)
            packetizedElementaryStreams[packet.pid] = PacketizedElementaryStream(packet.payload)
            return sampleBuffer
        }
        _ = packetizedElementaryStreams[packet.pid]?.append(packet.payload)
        if let sampleBuffer = makeSampleBuffer(packet.pid) {
            return sampleBuffer
        }
        return nil
    }

    private func makeSampleBuffer(_ id: UInt16, forUpdate: Bool = false) -> TSBuffer? {
        guard
            let data = esSpecData[id],
            var pes = packetizedElementaryStreams[id], pes.isEntired || forUpdate else {
            return nil
        }
        defer {
            packetizedElementaryStreams[id] = nil
        }
        let formatDescription = makeFormatDescription(data, pes: &pes)
        if let formatDescription, formatDescriptions[id] != formatDescription {
            formatDescriptions[id] = formatDescription
        }
        var isNotSync = true
        switch data.streamType {
        case .h264:
            let units = nalUnitReader.read(&pes.data, type: AVCNALUnit.self)
            if let unit = units.first(where: { $0.type == .idr || $0.type == .slice }) {
                var data = Data([0x00, 0x00, 0x00, 0x01])
                data.append(unit.data)
                pes.data = data
            }
            isNotSync = !units.contains { $0.type == .idr }
        case .h265:
            let units = nalUnitReader.read(&pes.data, type: HEVCNALUnit.self)
            isNotSync = units.contains { $0.type == .sps }
        case .adtsAac:
            isNotSync = false
        default:
            break
        }

        let sampleBuffer = pes.makeSampleBuffer(
            data.streamType,
            previousPresentationTimeStamp: previousPresentationTimeStamps[id] ?? .invalid,
            formatDescription: formatDescriptions[id]
        )
        sampleBuffer?.isNotSync = isNotSync
        previousPresentationTimeStamps[id] = sampleBuffer?.presentationTimeStamp

        guard let sampleBuffer else { return nil }
        if timeCorrection.isNone {
            timeCorrection = sampleBuffer.presentationTimeStamp
        }

        return TSBuffer(
            ptr: sampleBuffer,
            timeCorrection: timeCorrection!,
            pid: id,
            isSync: !isNotSync
        )
    }

    private func makeFormatDescription(
        _ data: ESSpecificData,
        pes: inout PacketizedElementaryStream
    ) -> CMFormatDescription? {
        switch data.streamType {
        case .adtsAac:
            return ADTSHeader(data: pes.data).makeFormatDescription()
        case .h264, .h265:
            return nalUnitReader.makeFormatDescription(&pes.data, type: data.streamType)
        default:
            return nil
        }
    }
}

