import AVFoundation
import COpus
import Foundation
import OSLog

@MainActor
final class BluetoothMicrophoneService: ObservableObject {
    @Published private(set) var isPublished = false
    @Published private(set) var isCapturing = false
    @Published private(set) var inputLevel: Float = 0
    @Published private(set) var peakInputLevel: Float = 0
    @Published private(set) var receivedPacketCount = 0
    @Published private(set) var decodedFrameCount = 0
    @Published private(set) var lastResult = "Wireless microphone is offline"

    private let publisher = ProcessTapMicrophoneService()
    private let pipeline = BluetoothOpusPipeline()
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var engineConfigurationObserver: NSObjectProtocol?
    private var captureGeneration: UInt64?
    private var loggedFirstDecodedFrame = false
    private let logger = Logger(
        subsystem: "com.ianhansel.controldeck",
        category: "bluetooth-microphone"
    )

    @discardableResult
    func prepare() -> Bool {
        guard #available(macOS 14.2, *) else {
            lastResult = "Bluetooth microphone requires macOS 14.2 or later"
            return false
        }

        if let engine, !engine.isRunning {
            guard recoverAudioBridge(engine) else { return false }
        } else if engine == nil {
            guard startSilentAudioBridge() else { return false }
        }
        guard publisher.publish() else {
            lastResult = publisher.lastResult
            stopAudioBridge()
            return false
        }

        isPublished = true
        lastResult = publisher.lastResult
        return true
    }

    @discardableResult
    func startCapture() -> Bool {
        guard prepare() else { return false }
        let session = pipeline.reset()
        guard session.decoderResult == OPUS_OK else {
            captureGeneration = nil
            isCapturing = false
            inputLevel = 0
            lastResult =
                "Could not create Opus decoder (\(session.decoderResult))"
            return false
        }
        captureGeneration = session.generation
        receivedPacketCount = 0
        decodedFrameCount = 0
        inputLevel = 0
        peakInputLevel = 0
        loggedFirstDecodedFrame = false
        isCapturing = true
        lastResult = "Waiting for DualSense Bluetooth audio"
        logger.notice("Bluetooth microphone diagnostic capture started")

        let generation = session.generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { [weak self] in
            guard let self,
                  self.isCapturing,
                  self.captureGeneration == generation,
                  self.receivedPacketCount == 0
            else {
                return
            }
            self.lastResult =
                "No microphone packets yet — check the Bluetooth connection"
        }
        return true
    }

    func stopCapture() {
        if isCapturing {
            logger.notice(
                "Bluetooth microphone stopped; packets=\(self.receivedPacketCount, privacy: .public) decodedFrames=\(self.decodedFrameCount, privacy: .public) peak=\(self.peakInputLevel, privacy: .public)"
            )
        }
        captureGeneration = nil
        isCapturing = false
        pipeline.clear()
        inputLevel = 0
        lastResult = isPublished
            ? "\(ProcessTapMicrophoneService.deviceName) is ready"
            : "Wireless microphone is offline"
    }

    func teardown() {
        stopCapture()
        publisher.unpublish()
        isPublished = false
        stopAudioBridge()
    }

    func runAudioBridgeSelfTest() {
        guard prepare() else { return }
        pipeline.playTestTone(duration: 15)
        lastResult = "Playing a private test signal into DualSense Microphone"
    }

    func ingest(_ opusPayload: Data) {
        guard isCapturing,
              opusPayload.count ==
                DualSenseBluetoothAudioProtocol.microphoneOpusByteCount
        else {
            return
        }

        guard let generation = captureGeneration else { return }
        pipeline.enqueue(opusPayload, generation: generation) {
            [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.isCapturing,
                      self.captureGeneration == result.generation
                else {
                    return
                }

                self.receivedPacketCount += result.receivedPackets
                self.decodedFrameCount += result.decodedFrames
                self.inputLevel = result.level
                self.peakInputLevel = max(
                    self.peakInputLevel,
                    result.level
                )

                if let decodeError = result.decodeError {
                    self.lastResult =
                        "Opus decode failed (\(decodeError))"
                } else if result.decodedFrames > 0 {
                    self.lastResult =
                        "Receiving DualSense Bluetooth microphone"
                    if !self.loggedFirstDecodedFrame {
                        self.loggedFirstDecodedFrame = true
                        self.logger.notice(
                            "Decoded first Bluetooth microphone frame; level=\(result.level, privacy: .public)"
                        )
                    }
                }
            }
        }
    }

    private func startSilentAudioBridge() -> Bool {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Double(
                DualSenseBluetoothAudioProtocol.microphoneSampleRate
            ),
            channels: 2
        ) else {
            lastResult = "Could not create the wireless microphone format"
            return false
        }

        let engine = AVAudioEngine()
        let ring = pipeline.ring
        let sourceNode = AVAudioSourceNode(format: format) {
            _, _, frameCount, audioBufferList -> OSStatus in
            ring.render(
                frameCount: Int(frameCount),
                into: audioBufferList
            )
            return noErr
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            lastResult = "Could not start the audio bridge: \(error.localizedDescription)"
            return false
        }

        self.sourceNode = sourceNode
        self.engine = engine
        engineConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let engine = self.engine else {
                    return
                }
                _ = self.recoverAudioBridge(engine)
            }
        }
        return true
    }

    @discardableResult
    private func recoverAudioBridge(_ expectedEngine: AVAudioEngine) -> Bool {
        guard engine === expectedEngine else { return engine?.isRunning == true }
        if expectedEngine.isRunning {
            return true
        }
        do {
            try expectedEngine.start()
            return true
        } catch {
            // A hardware route change can invalidate the old graph. Recreate
            // only that graph; retain the decoder/ring during active capture.
            stopAudioBridge(clearPipeline: !isCapturing)
            guard startSilentAudioBridge() else {
                lastResult =
                    "Wireless microphone audio engine stopped: " +
                    error.localizedDescription
                return false
            }
            return true
        }
    }

    private func stopAudioBridge(clearPipeline: Bool = true) {
        if let engineConfigurationObserver {
            NotificationCenter.default.removeObserver(
                engineConfigurationObserver
            )
            self.engineConfigurationObserver = nil
        }
        engine?.stop()
        if clearPipeline {
            pipeline.clear()
        }
        engine = nil
        sourceNode = nil
    }
}

private struct BluetoothPipelineSession {
    let generation: UInt64
    let decoderResult: Int32
}

private struct BluetoothDecodeResult {
    let generation: UInt64
    let receivedPackets: Int
    let decodedFrames: Int
    let level: Float
    let decodeError: Int32?
}

private final class BluetoothOpusPipeline: @unchecked Sendable {
    let ring = MicrophonePCMRingBuffer()

    private let queue = DispatchQueue(
        label: "com.ianhansel.controldeck.bluetooth-microphone-decode",
        qos: .userInteractive
    )
    private var decoder: OpaquePointer?
    private var generation: UInt64 = 0
    private var pendingPacketCount = 0
    private var pendingDecodedFrameCount = 0
    private var pendingLevel: Float = 0
    private var pendingDecodeError: Int32?
    private var totalPacketCount = 0
    private var lastMetricsEmissionNanoseconds: UInt64 = 0
    private let metricsEmissionIntervalNanoseconds: UInt64 = 100_000_000

    deinit {
        if let decoder {
            opus_decoder_destroy(decoder)
        }
    }

    func reset() -> BluetoothPipelineSession {
        queue.sync {
            generation &+= 1
            if let decoder {
                opus_decoder_destroy(decoder)
                self.decoder = nil
            }
            ring.reset()
            resetPendingMetrics()
            var error: Int32 = 0
            decoder = opus_decoder_create(
                Int32(DualSenseBluetoothAudioProtocol.microphoneSampleRate),
                1,
                &error
            )
            return BluetoothPipelineSession(
                generation: generation,
                decoderResult: error
            )
        }
    }

    func clear() {
        queue.sync {
            generation &+= 1
            if let decoder {
                opus_decoder_destroy(decoder)
                self.decoder = nil
            }
            resetPendingMetrics()
            ring.reset()
        }
    }

    func playTestTone(duration: TimeInterval) {
        ring.playTestTone(duration: duration)
    }

    func enqueue(
        _ payload: Data,
        generation requestedGeneration: UInt64,
        completion: @escaping (BluetoothDecodeResult) -> Void
    ) {
        queue.async { [weak self] in
            guard let self,
                  requestedGeneration == self.generation,
                  let decoder = self.decoder
            else {
                return
            }
            var mono = [Float](
                repeating: 0,
                count: DualSenseBluetoothAudioProtocol.microphoneFrameCount
            )
            let decodedFrames = payload.withUnsafeBytes { encodedBytes in
                mono.withUnsafeMutableBufferPointer { pcm in
                    opus_decode_float(
                        decoder,
                        encodedBytes.bindMemory(to: UInt8.self).baseAddress,
                        Int32(payload.count),
                        pcm.baseAddress!,
                        Int32(
                            DualSenseBluetoothAudioProtocol.microphoneFrameCount
                        ),
                        0
                    )
                }
            }

            var level: Float = 0
            if decodedFrames > 0 {
                let frameCount = Int(decodedFrames)
                self.ring.write(mono, count: frameCount)
                var energy: Float = 0
                for sample in mono.prefix(frameCount) {
                    energy += sample * sample
                }
                let rms = sqrt(energy / Float(frameCount))
                let decibels = 20 * log10(max(rms, 0.000_01))
                level = min(1, max(0, (decibels + 60) / 60))
            }

            // The decode queue is serial, so reset/clear cannot interleave with
            // this write. The generation guard also rejects packets queued by
            // an earlier push-to-talk session.
            guard requestedGeneration == self.generation else { return }
            self.pendingPacketCount += 1
            self.totalPacketCount += 1
            self.pendingLevel = max(self.pendingLevel, level)
            if decodedFrames > 0 {
                self.pendingDecodedFrameCount += Int(decodedFrames)
            } else if decodedFrames < 0 {
                self.pendingDecodeError = decodedFrames
            }

            let now = DispatchTime.now().uptimeNanoseconds
            let isFirstPacket = self.totalPacketCount == 1
            let intervalElapsed =
                now &- self.lastMetricsEmissionNanoseconds >=
                self.metricsEmissionIntervalNanoseconds
            guard isFirstPacket || intervalElapsed else { return }

            completion(
                BluetoothDecodeResult(
                    generation: requestedGeneration,
                    receivedPackets: self.pendingPacketCount,
                    decodedFrames: self.pendingDecodedFrameCount,
                    level: self.pendingLevel,
                    decodeError: self.pendingDecodeError
                )
            )
            self.pendingPacketCount = 0
            self.pendingDecodedFrameCount = 0
            self.pendingLevel = 0
            self.pendingDecodeError = nil
            self.lastMetricsEmissionNanoseconds = now
        }
    }

    private func resetPendingMetrics() {
        pendingPacketCount = 0
        pendingDecodedFrameCount = 0
        pendingLevel = 0
        pendingDecodeError = nil
        totalPacketCount = 0
        lastMetricsEmissionNanoseconds = 0
    }
}

private final class MicrophonePCMRingBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = [Float](repeating: 0, count: 96_000)
    private var readIndex = 0
    private var writeIndex = 0
    private var availableFrames = 0
    private var isPrimed = false
    private var testToneFramesRemaining = 0
    private var testTonePhase: Float = 0
    private let primeFrames = 2_400 // 50 ms of Bluetooth jitter tolerance.

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        readIndex = 0
        writeIndex = 0
        availableFrames = 0
        isPrimed = false
        testToneFramesRemaining = 0
        testTonePhase = 0
    }

    func playTestTone(duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        testToneFramesRemaining = max(
            0,
            Int(
                duration * Double(
                    DualSenseBluetoothAudioProtocol.microphoneSampleRate
                )
            )
        )
        testTonePhase = 0
    }

    func write(_ samples: [Float], count: Int) {
        lock.lock()
        defer { lock.unlock() }
        let safeCount = min(max(0, count), samples.count)
        for index in 0..<safeCount {
            let sample = samples[index]
            if availableFrames == storage.count {
                readIndex = (readIndex + 1) % storage.count
                availableFrames -= 1
            }
            storage[writeIndex] = sample
            writeIndex = (writeIndex + 1) % storage.count
            availableFrames += 1
        }

        // Recover from an interrupted render callback without carrying seconds
        // of stale speech into the next Codex capture window.
        if availableFrames > storage.count * 3 / 4 {
            let target = primeFrames * 2
            let framesToDrop = availableFrames - target
            readIndex = (readIndex + framesToDrop) % storage.count
            availableFrames = target
        }
    }

    func render(
        frameCount: Int,
        into audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        // AVAudioSourceNode invokes this on a real-time thread. Never wait for
        // the decoder/reset writer: a contested callback emits silence and
        // catches up on the next render quantum.
        guard lock.try() else {
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                memset(data, 0, Int(buffer.mDataByteSize))
            }
            return
        }
        defer { lock.unlock() }

        if !isPrimed, availableFrames >= primeFrames {
            isPrimed = true
        }

        for frame in 0..<frameCount {
            let sample: Float
            if testToneFramesRemaining > 0 {
                sample = sin(testTonePhase) * 0.16
                testTonePhase += 2 * .pi * 523.25 /
                    Float(
                        DualSenseBluetoothAudioProtocol.microphoneSampleRate
                    )
                testToneFramesRemaining -= 1
            } else if isPrimed, availableFrames > 0 {
                sample = storage[readIndex]
                readIndex = (readIndex + 1) % storage.count
                availableFrames -= 1
            } else {
                sample = 0
            }
            if isPrimed, availableFrames == 0 {
                isPrimed = false
            }

            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let channels = max(1, Int(buffer.mNumberChannels))
                let destination = data.assumingMemoryBound(to: Float.self)
                for channel in 0..<channels {
                    destination[frame * channels + channel] = sample
                }
            }
        }
    }
}
