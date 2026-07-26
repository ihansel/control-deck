import AVFoundation
import FluidAudio
import Foundation
import WhisperKit

enum SmokeTestError: LocalizedError {
    case usage
    case audioBuffer
    case noText

    var errorDescription: String? {
        switch self {
        case .usage:
            "Usage: swift run LocalSpeechSmokeTest <parakeet|whisperkit|whisperkit-small> <audio-file> <models-root>"
        case .audioBuffer:
            "The audio file could not be read"
        case .noText:
            "The model returned no text"
        }
    }
}

@main
struct LocalSpeechSmokeTest {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            throw SmokeTestError.usage
        }
        let engine = arguments[1].lowercased()
        let audioURL = URL(fileURLWithPath: arguments[2])
        let modelsRoot = URL(fileURLWithPath: arguments[3])
        let transcript: String

        switch engine {
        case "parakeet":
            transcript = try await transcribeParakeet(
                audioURL: audioURL,
                modelsRoot: modelsRoot
            )
        case "whisperkit":
            transcript = try await transcribeWhisperKit(
                audioURL: audioURL,
                modelsRoot: modelsRoot,
                variant: "base.en"
            )
        case "whisperkit-small":
            transcript = try await transcribeWhisperKit(
                audioURL: audioURL,
                modelsRoot: modelsRoot,
                variant: "small.en"
            )
        default:
            throw SmokeTestError.usage
        }

        let text = transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !text.isEmpty else {
            throw SmokeTestError.noText
        }
        print(text)
    }

    private static func transcribeParakeet(
        audioURL: URL,
        modelsRoot: URL
    ) async throws -> String {
        let manager = StreamingEouAsrManager(
            chunkSize: .ms320,
            eouDebounceMs: 960
        )
        try await manager.loadModels(to: modelsRoot)
        let converter = AudioConverter(sampleRate: 16_000)
        var samples = try converter.resampleAudioFile(audioURL)
        samples.append(
            contentsOf: repeatElement(0, count: 10_240)
        )
        let feedFrames = 5_120
        var offset = 0
        while offset < samples.count {
            let end = min(samples.count, offset + feedFrames)
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            ),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(end - offset)
            ),
            let destination = buffer.floatChannelData?[0]
            else {
                throw SmokeTestError.audioBuffer
            }
            buffer.frameLength = AVAudioFrameCount(end - offset)
            samples.withUnsafeBufferPointer { source in
                destination.update(
                    from: source.baseAddress! + offset,
                    count: end - offset
                )
            }
            _ = try await manager.process(audioBuffer: buffer)
            offset = end
        }
        return try await manager.finish()
    }

    private static func transcribeWhisperKit(
        audioURL: URL,
        modelsRoot: URL,
        variant: String
    ) async throws -> String {
        let downloadBase = modelsRoot.appendingPathComponent(
            "WhisperKit",
            isDirectory: true
        )
        let cachedFolder = downloadBase
            .appendingPathComponent(
                "models/argmaxinc/whisperkit-coreml",
                isDirectory: true
            )
            .appendingPathComponent(
                "openai_whisper-\(variant)",
                isDirectory: true
            )
        let hasCachedModel = FileManager.default.fileExists(
            atPath: cachedFolder.appendingPathComponent(
                "AudioEncoder.mlmodelc/weights/weight.bin"
            ).path
        ) && FileManager.default.fileExists(
            atPath: cachedFolder.appendingPathComponent(
                "TextDecoder.mlmodelc/weights/weight.bin"
            ).path
        )
        let modelFolder = if hasCachedModel {
            cachedFolder
        } else {
            try await WhisperKit.download(
                variant: variant,
                downloadBase: downloadBase
            )
        }
        let configuration = WhisperKitConfig(
            model: variant,
            downloadBase: downloadBase,
            modelFolder: modelFolder.path,
            verbose: false,
            prewarm: true,
            load: true,
            download: false
        )
        let whisperKit = try await WhisperKit(configuration)
        var audio = try AudioProcessor.loadAudioAsFloatArray(
            fromPath: audioURL.path
        )
        FileHandle.standardError.write(
            Data("Loaded \(audio.count) normalized audio frames\n".utf8)
        )
        // WhisperKit intentionally ignores the final second of a window. Match
        // ControlDeck's production dictation path so short/final phrases are
        // part of this smoke test instead of being silently skipped.
        audio.append(contentsOf: repeatElement(0, count: 17_600))
        let options = DecodingOptions(
            language: "en",
            concurrentWorkerCount: 2,
            chunkingStrategy: .vad
        )
        let batches = await whisperKit.transcribe(
            audioArrays: [audio],
            decodeOptions: options
        )
        let results = (batches.first ?? nil) ?? []
        return results.map(\.text).joined(separator: " ")
    }
}
