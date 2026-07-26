import AVFoundation
import Foundation
import Speech

@available(macOS 26.0, *)
enum AppleSpeechBufferTranscriber {
    private actor TranscriptAccumulator {
        private var text = ""

        func append(_ segment: String) {
            let clean = segment.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !clean.isEmpty else { return }
            if text.isEmpty ||
                text.last?.isWhitespace == true ||
                clean.first?.isPunctuation == true {
                text += clean
            } else {
                text += " " + clean
            }
        }

        var value: String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func transcribe(
        samples: [Float],
        contextualStrings: [String]
    ) async throws -> String {
        guard !samples.isEmpty,
              SFSpeechRecognizer.authorizationStatus() == .authorized,
              SpeechTranscriber.isAvailable
        else { return "" }
        let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: .autoupdatingCurrent
        )
        guard let locale else { return "" }

        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .transcription
        )
        if let installation = try await AssetInventory
            .assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }

        let modules: [any SpeechModule] = [transcriber]
        guard let analyzerFormat = await SpeechAnalyzer
            .bestAvailableAudioFormat(compatibleWith: modules)
        else { return "" }
        let analyzer = SpeechAnalyzer(modules: modules)
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        if !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = Array(
                contextualStrings.prefix(32)
            )
            try await analyzer.setContext(context)
        }

        let accumulator = TranscriptAccumulator()
        let resultTask = Task {
            for try await result in transcriber.results {
                await accumulator.append(
                    String(result.text.characters)
                )
            }
        }
        let (stream, continuation) = AsyncStream.makeStream(
            of: AnalyzerInput.self
        )
        try await analyzer.start(inputSequence: stream)
        guard let buffer = convert(
            samples: samples,
            to: analyzerFormat
        ) else {
            await analyzer.cancelAndFinishNow()
            resultTask.cancel()
            return ""
        }
        continuation.yield(AnalyzerInput(buffer: buffer))
        continuation.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        _ = try await resultTask.value
        return await accumulator.value
    }

    private static func convert(
        samples: [Float],
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(
                ContinuousSpeechAudioProcessor.outputSampleRate
            ),
            channels: 1,
            interleaved: false
        ),
        let source = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let sourceChannel = source.floatChannelData?[0]
        else { return nil }
        source.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { input in
            if let baseAddress = input.baseAddress {
                sourceChannel.update(
                    from: baseAddress,
                    count: input.count
                )
            }
        }
        if sourceFormat == outputFormat {
            return source
        }
        guard let converter = AVAudioConverter(
            from: sourceFormat,
            to: outputFormat
        ),
        let output = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(
                max(
                    1,
                    ceil(
                        Double(samples.count) *
                            outputFormat.sampleRate /
                            sourceFormat.sampleRate
                    ) + 64
                )
            )
        ) else { return nil }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(
            to: output,
            error: &conversionError
        ) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return source
        }
        guard status != .error,
              conversionError == nil,
              output.frameLength > 0
        else { return nil }
        return output
    }
}
