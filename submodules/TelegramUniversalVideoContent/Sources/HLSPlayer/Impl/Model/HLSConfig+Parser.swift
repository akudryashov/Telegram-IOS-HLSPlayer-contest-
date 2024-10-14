//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

enum HLSConfigError: Error {
    case missingMatch(String, key: String)
    case chunkDifferComponentsCount
    case missingAttribute(key: String)
    case missingVariants
}

extension HLSConfig {
    init(raw: String, configURL: URL, additionalInfo: HLSVariant.AdditionalInfo?) throws {
        let isMediaPlaylist = try NSRegularExpression(pattern: "#EXT(?:INF|-X-TARGETDURATION):")
        let range = NSRange(location: 0, length: raw.utf16.count)

        if let _ = isMediaPlaylist.firstMatch(in: raw, range: range) {
            variants = [
                try HLSVariant.parseFull(raw: raw, additionalInfo: additionalInfo ?? .init(
                    name: "single-variant",
                    bandwidth: 0,
                    codecs: [],
                    url: configURL
                ))
            ]
            isMasterConfig = false
        } else {
            let masterRegex = try NSRegularExpression(pattern: [
                "#EXT-X-STREAM-INF:(?<attrs>[^\r\n]*)(?:[\r\n](?:#[^\r\n]*)?)*(?<uri>[^\r\n]+)",
                "#EXT-X-(SESSION-DATA|SESSION-KEY|DEFINE|CONTENT-STEERING|START):([^\r\n]*)[\r\n]+"
            ].joined(separator: "|"))
            let matches = masterRegex.matches(in: raw, range: range)

            var variants = [HLSVariant]()
            for match in matches {
                let value = try raw.substring(nsRange: match.range)
                    .get(elseThrow: HLSConfigError.missingMatch(raw, key: "master_value"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let _ = value.removePrefixIfContains("#EXT-X-STREAM-INF:") {
                    let attrsRange = match.range(withName: "attrs")
                    let uriRange = match.range(withName: "uri")

                    let attrs = try raw.substring(nsRange: attrsRange)
                        .get(elseThrow: HLSConfigError.missingMatch(raw, key: "master_attrs"))
                        .parseAttrs()
                    let uri = try raw.substring(nsRange: uriRange)
                        .get(elseThrow: HLSConfigError.missingMatch(raw, key: "master_uri"))

                    let bandwidth = try attrs["BANDWIDTH"].flatMap { Int($0) }
                        .get(elseThrow: HLSConfigError.missingAttribute(key: "BANDWIDTH"))
                    let extra = try HLSVariant.AdditionalInfo(
                        name: attrs["NAME"] ?? String(bandwidth),
                        bandwidth: bandwidth,
                        codecs: attrs["CODECS"]
                            .get(elseThrow: HLSConfigError.missingAttribute(key: "CODECS"))
                            .components(separatedBy: ","),
                        url: configURL.deletingLastPathComponent().appendingPathComponent(uri)
                    )
                    variants.append(.ref(extra))
                }
            }
            self.variants = variants.sorted(by: { $0.additionalInfo.bandwidth < $1.additionalInfo.bandwidth })
            isMasterConfig = true
        }
    }
}

extension HLSVariant {
    static func parseFull(raw: String, additionalInfo: AdditionalInfo) throws -> Self {
        let range = NSRange(location: 0, length: raw.utf16.count)
        let configRegex = try NSRegularExpression(pattern: [
            #"#EXTINF:\s*(\d*(?:\.\d+)?)(?:,(.*)\s+)?"#, // duration (#EXTINF:<duration>,<title>), group 1 => duration, group 2 => title
            #"(?!#) *(\S[^\r\n]*)"#, // segment URI, group 3 => the URI (note newline is not eaten)
            "#EXT-X-BYTERANGE:*(.+)", // next segment's byterange, group 4 => range spec (x@y)
            "#EXT-X-PROGRAM-DATE-TIME:(.+)", // next segment's program date/time group 5 => the datetime spec
            "#.*", // All other non-segment oriented tags will match with all groups empty
        ].joined(separator: "|"))
        let matches = configRegex.matches(in: raw, range: range)
        var version: Int?
        var targetDuration = 0.0
        var chunks = [HLSChunk]()
        var chunk: HLSChunk?
        var startTime: TimeInterval = 0.0
        for match in matches {
            let value = try raw.substring(nsRange: match.range)
                .get(elseThrow: HLSConfigError.missingMatch(raw, key: "config_value"))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if chunk.isSome {
                chunk?.uri = value
                chunks.append(chunk!)
                chunk = nil
            } else if let rest = value.removePrefixIfContains("#EXTINF:") {
                let components = rest.components(separatedBy: ",")
                guard components.count >= 1, components.count <= 2 else {
                    throw HLSConfigError.chunkDifferComponentsCount
                }
                var current = HLSChunk()
                current.duration = try TimeInterval(components[0])
                    .get(elseThrow: HLSConfigError.missingAttribute(key: "ChunkDuration"))
                current.name = components.count > 1 ? components[1] : nil
                current.startTime = startTime
                startTime += current.duration

                chunk = current
            } else if let rest = value.removePrefixIfContains("#EXT-X-VERSION:") {
                version = Int(rest)
            } else if let rest = value.removePrefixIfContains("#EXT-X-TARGETDURATION:") {
                targetDuration = try TimeInterval(rest)
                    .get(elseThrow: HLSConfigError.missingAttribute(key: "TargetDuration"))
            }
        }
        return .full(Full(
            additionalInfo: additionalInfo,
            version: version,
            targetDuration: targetDuration,
            chunks: chunks
        ))
    }
}

extension String {
    fileprivate func substring(nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else {
            return nil
        }
        return String(self[range])
    }

    fileprivate func removePrefixIfContains(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }
        return String(dropFirst(prefix.count))
    }

    fileprivate func parseAttrs() throws -> [String: String] {
        let regex = try NSRegularExpression(pattern: #"(.+?)=(".*?"|.*?)(?:,|$)"#)
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: utf16.count))

        return try matches.reduce(into: [:]) {
            let key = try substring(nsRange: $1.range(at: 1))
                .get(elseThrow: HLSConfigError.missingMatch(self, key: "attr-key"))
            let value = try substring(nsRange: $1.range(at: 2))
                .get(elseThrow: HLSConfigError.missingMatch(self, key: "attr-value"))
                .replacingOccurrences(of: "\"", with: "")
            $0[key] = value
        }
    }
}
