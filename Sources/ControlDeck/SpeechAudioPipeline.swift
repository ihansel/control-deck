import AVFoundation
import Foundation

struct SpeechAudioMetrics: Equatable, Sendable {
    var receivedFrames = 0
    var normalizedFrames = 0
    var droppedFrames = 0
    var peak: Float = 0
    var rms: Float = 0
    var level: Float = 0
    var recognitionGain: Float = 1

    var duration: TimeInterval {
        Double(normalizedFrames) / 16_000
    }
}

/// A session-scoped, continuous audio front end shared by the local speech
/// engines. The converter is deliberately retained for the whole utterance:
/// recreating it for every 10 ms Bluetooth packet loses converter state and
/// leaves streaming recognizers with discontinuous audio.
final class ContinuousSpeechAudioProcessor {
    static let outputSampleRate: Int32 = 16_000

    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(outputSampleRate),
        channels: 1,
        interleaved: false
    )!
    private var inputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var normalizedSamples: [Float] = []
    private var previousInput: Float = 0
    private var previousOutput: Float = 0
    private var accumulatedEnergy: Double = 0
    private(set) var metrics = SpeechAudioMetrics()

    func reset(leadingPadding: TimeInterval = 0.08) {
        inputFormat = nil
        converter = nil
        normalizedSamples.removeAll(keepingCapacity: true)
        previousInput = 0
        previousOutput = 0
        accumulatedEnergy = 0
        metrics = SpeechAudioMetrics()
        appendSilence(duration: leadingPadding)
    }

    func append(
        _ samples: [Float],
        sampleRate: Int32
    ) throws -> [Float] {
        guard !samples.isEmpty, sampleRate > 0 else { return [] }
        metrics.receivedFrames += samples.count

        let converted: [Float]
        if sampleRate == Self.outputSampleRate {
            converted = samples
        } else {
            converted = try resample(samples, sampleRate: sampleRate)
        }
        guard !converted.isEmpty else { return [] }

        var conditioned = [Float]()
        conditioned.reserveCapacity(converted.count)
        var energy: Float = 0
        var localPeak: Float = 0
        for input in converted {
            // Remove controller-microphone DC bias without applying aggressive
            // noise suppression or gain that could damage consonants.
            let highPassed =
                input - previousInput + 0.995 * previousOutput
            previousInput = input
            previousOutput = highPassed
            let sample = min(0.98, max(-0.98, highPassed))
            conditioned.append(sample)
            energy += sample * sample
            localPeak = max(localPeak, abs(sample))
        }

        let rms = sqrt(energy / Float(conditioned.count))
        let decibels = 20 * log10(max(rms, 0.000_01))
        metrics.level = min(1, max(0, (decibels + 60) / 60))
        metrics.peak = max(metrics.peak, localPeak)
        metrics.normalizedFrames += conditioned.count
        accumulatedEnergy += Double(energy)
        metrics.rms = Float(
            sqrt(
                accumulatedEnergy /
                    Double(max(1, metrics.normalizedFrames))
            )
        )
        normalizedSamples.append(contentsOf: conditioned)
        return conditioned
    }

    func appendSilence(duration: TimeInterval) {
        let count = max(
            0,
            Int(duration * Double(Self.outputSampleRate))
        )
        guard count > 0 else { return }
        normalizedSamples.append(
            contentsOf: repeatElement(0, count: count)
        )
        metrics.normalizedFrames += count
    }

    func allSamples(trailingPadding: TimeInterval = 0) -> [Float] {
        guard trailingPadding > 0 else { return normalizedSamples }
        var result = normalizedSamples
        result.append(
            contentsOf: repeatElement(
                0,
                count: Int(
                    trailingPadding * Double(Self.outputSampleRate)
                )
            )
        )
        return result
    }

    /// Produces a gently levelled copy for final recognizers. The DualSense
    /// microphone is often tens of decibels quieter than a laptop microphone;
    /// Apple Speech is robust to that, while compact local models are not. This
    /// estimates the session noise floor, raises only speech-bearing windows,
    /// caps gain and limits rare controller transients. The stored/raw stream
    /// and live level meter remain unchanged.
    func recognitionSamples(
        trailingPadding: TimeInterval = 0
    ) -> [Float] {
        guard !normalizedSamples.isEmpty else { return [] }
        let windowFrames = 320
        var windowRMS: [Float] = []
        windowRMS.reserveCapacity(
            max(1, normalizedSamples.count / windowFrames)
        )
        for start in stride(
            from: 0,
            to: normalizedSamples.count,
            by: windowFrames
        ) {
            let end = min(start + windowFrames, normalizedSamples.count)
            guard end > start else { continue }
            var energy: Float = 0
            for sample in normalizedSamples[start..<end] {
                energy += sample * sample
            }
            windowRMS.append(
                sqrt(energy / Float(end - start))
            )
        }

        let sorted = windowRMS.sorted()
        let noiseIndex = min(
            max(0, Int(Double(sorted.count) * 0.2)),
            max(0, sorted.count - 1)
        )
        let noiseFloor = sorted.isEmpty ? 0 : sorted[noiseIndex]
        let speechThreshold = max(0.0015, noiseFloor * 2.5)
        let active = windowRMS.filter { $0 > speechThreshold }
        let activeRMS = active.isEmpty
            ? metrics.rms
            : sqrt(
                active.reduce(Float(0)) { $0 + $1 * $1 } /
                    Float(active.count)
            )
        var gain = min(
            8,
            max(1, 0.075 / max(activeRMS, 0.000_01))
        )
        if metrics.peak > 0.000_01 {
            gain = min(gain, 1.2 / metrics.peak)
        }
        metrics.recognitionGain = gain

        var result = normalizedSamples.map {
            min(0.98, max(-0.98, $0 * gain))
        }
        if trailingPadding > 0 {
            result.append(
                contentsOf: repeatElement(
                    0,
                    count: Int(
                        trailingPadding *
                            Double(Self.outputSampleRate)
                    )
                )
            )
        }
        return result
    }

    private func resample(
        _ samples: [Float],
        sampleRate: Int32
    ) throws -> [Float] {
        if inputFormat?.sampleRate != Double(sampleRate) {
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(sampleRate),
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(
                from: format,
                to: outputFormat
            )
            else {
                throw LocalSpeechTranscriptionError.microphoneUnavailable
            }
            inputFormat = format
            self.converter = converter
        }
        guard let inputFormat, let converter,
              let input = AVAudioPCMBuffer(
                  pcmFormat: inputFormat,
                  frameCapacity: AVAudioFrameCount(samples.count)
              ),
              let inputChannel = input.floatChannelData?[0]
        else {
            throw LocalSpeechTranscriptionError.microphoneUnavailable
        }
        input.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let baseAddress = source.baseAddress {
                inputChannel.update(
                    from: baseAddress,
                    count: source.count
                )
            }
        }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        guard let output = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(
                max(1, ceil(Double(samples.count) * ratio) + 64)
            )
        ) else {
            throw LocalSpeechTranscriptionError.microphoneUnavailable
        }

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
            return input
        }
        guard status != .error, conversionError == nil,
              let outputChannel = output.floatChannelData?[0]
        else {
            metrics.droppedFrames += samples.count
            throw conversionError ??
                LocalSpeechTranscriptionError.microphoneUnavailable
        }
        return Array(
            UnsafeBufferPointer(
                start: outputChannel,
                count: Int(output.frameLength)
            )
        )
    }
}
