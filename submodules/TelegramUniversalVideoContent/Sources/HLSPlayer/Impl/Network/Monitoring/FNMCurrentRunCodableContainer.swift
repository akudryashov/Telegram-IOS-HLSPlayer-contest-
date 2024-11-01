//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

private typealias FNMRecordNodeMatch = (requestRecord: FNMHTTPRequestRecord, node: FNMRequestNode)

final class FNMCurrentRunCodableContainer: NSObject {

    let record: FNMRecord
    let requestRecords: [FNMHTTPRequestRecord]

    private let matchesContainer: RecordNodeMatchesContainer?

    var unmatchedRequestRecords: [FNMHTTPRequestRecord] { return self.matchesContainer?.unmatchedRequestRecords() ?? [] }
    var unmatchedBlockingNodes: [FNMRequestNode] { return self.matchesContainer?.unmatchedBlockingNodes() ?? [] }

    var blockingRequestRecords: [FNMHTTPRequestRecord] { return self.matchesContainer?.blockingRequestRecords() ?? [] }
    var nonBlockingRequestNodes: [FNMRequestNode] { return self.matchesContainer?.nonBlockingRequestNodes() ?? [] }

    init(record: FNMRecord,
         requestRecords: [FNMHTTPRequestRecord],
         overallRecords: Bool = false) {

        self.record = record
        self.requestRecords = requestRecords

        self.matchesContainer = RecordNodeMatchesContainer(requestRecords: self.requestRecords,
                                                           and: self.record,
                                                           overallRecords: overallRecords)
    }
}

// MARK: - Private
private struct RecordNodeMatchesContainer {

    let allFirstPartyRequestRecords: [FNMHTTPRequestRecord]
    let allFirstPartyNodes: [FNMRequestNode]
    let matches: [FNMRecordNodeMatch]

    init?(requestRecords: [FNMHTTPRequestRecord],
          and record: FNMRecord, overallRecords: Bool = false) {

        let callElement = record.timestamps[overallRecords ? "overall" : "firstPartyAPISetup"]

        guard let callsStart = callElement?.start,
            let callsEnd = callElement?.end,
            let firstPartyNodes = record.requestCluster?.firstPartyNodes,
            let thirdPartyNodes = record.requestCluster?.thirdPartyNodes
            else { return nil }

        let firstPartyRequestRecords = requestRecords.filter { requestRecord -> Bool in

            guard let absoluteURLString = requestRecord.request.url?.absoluteString else { return false }

            guard callsStart.timeIntervalSince1970 < requestRecord.startTimestamp,
                callsEnd.timeIntervalSince1970 > requestRecord.startTimestamp else { return false }

            let allExpressions = thirdPartyNodes.flatMap { $0.expressions }
            return allExpressions.containsMatches(in: absoluteURLString) == false
        }

        let matches = firstPartyRequestRecords.compactMap { firstPartyRequestRecord -> FNMRecordNodeMatch? in

            if let matchedNode = firstPartyNodes.node(for: firstPartyRequestRecord) {

                return (firstPartyRequestRecord, matchedNode)
            }

            return nil
        }

        self.init(allFirstPartyRequestRecords: firstPartyRequestRecords,
                  allFirstPartyNodes: firstPartyNodes,
                  matches: matches)
    }

    init(allFirstPartyRequestRecords: [FNMHTTPRequestRecord],
         allFirstPartyNodes: [FNMRequestNode],
         matches: [FNMRecordNodeMatch]) {

        self.allFirstPartyRequestRecords = allFirstPartyRequestRecords
        self.allFirstPartyNodes = allFirstPartyNodes
        self.matches = matches
    }

    func unmatchedRequestRecords() -> [FNMHTTPRequestRecord] {

        return self.allFirstPartyRequestRecords.filter { (firstPartyRequestRecord) -> Bool in

            return self.matches.contains { return $0.requestRecord == firstPartyRequestRecord } == false
        }
    }

    func unmatchedBlockingNodes() -> [FNMRequestNode] {

        return self.allFirstPartyNodes
            .filter { $0.type == FNMRequestNode.FNMRequestNodeType.blocking }
            .filter { (firstPartyNode) -> Bool in

                return self.matches.contains { return $0.node.identifier == firstPartyNode.identifier } == false
        }
    }

    func blockingRequestRecords() -> [FNMHTTPRequestRecord]? {

        return self.matches.compactMap { tuple -> FNMHTTPRequestRecord? in

            return (tuple.node.type == .blocking) ? tuple.requestRecord : nil
        }
    }

    func nonBlockingRequestNodes() -> [FNMRequestNode]? {

        return self.allFirstPartyNodes
            .filter { $0.type == FNMRequestNode.FNMRequestNodeType.nonBlocking }
    }
}

extension FNMCurrentRunCodableContainer: Encodable {

    enum CodingKeys: String, CodingKey {

        case records = "performance"
        case uncataloguedCalls = "uncataloguedCalls"
        case unusedExpressions = "unusedExpressions"
        case blockingRequestRecords = "blockingRequestRecords"
        case nonBlockingRequestNodes = "nonBlockingRequestNodes"
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.record, forKey: .records)
        try container.encode(self.unmatchedRequestRecords, forKey: .uncataloguedCalls)
        try container.encode(self.blockingRequestRecords, forKey: .blockingRequestRecords)
        try container.encode(self.nonBlockingRequestNodes, forKey: .nonBlockingRequestNodes)
    }
}
