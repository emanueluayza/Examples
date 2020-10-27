//
//  CameraFeed.swift
//  DelayCameraFeed
//
//  Created by Emanuel Luayza on 27/10/2020.
//

import Foundation
import AVFoundation

class CameraFeed: NSObject {

    // MARK: - Properties

    fileprivate var captureSession: AVCaptureSession!
    fileprivate var captureDevice: AVCaptureDevice!
    fileprivate var captureDeviceInput: AVCaptureDeviceInput!
    fileprivate var captureVideoOutput: AVCaptureVideoDataOutput!
    fileprivate var latency: Double = 1.0
    fileprivate var assetWriter: AVAssetWriter!
    fileprivate var assetWriterInput: AVAssetWriterInput!
    fileprivate var chunkNumber: Int = 0
    fileprivate var chunkStartTime: CMTime!
    fileprivate var chunkOutputURL: URL!

    // MARK: - Closures

    var didOutputPlayerItem: ((_ item: AVPlayerItem) -> ())?

    // MARK: - Inits

    override init() {
        super.init()
        setupSession()
    }

    // MARK: - Setups

    private func setupSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1920x1080 // 1

        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                               mediaType: .video,
                                                               position: .back).devices // 2

        if let device = availableDevices.first { // 3
            captureDevice = device

            setupDeviceInput()
            setupDeviceOutput()
        }
    }

    private func setupDeviceInput() {
        do {
            captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice) // 1

            if captureSession.canAddInput(captureDeviceInput) { // 2
                captureSession.addInput(captureDeviceInput)
            }

            captureDevice.updateFormatWithPreferredVideoSpec(preferredSpec: AVCaptureDevice.VideoSpec(fps: 60,
                                                                                                      size: CGSize(width: 1920,
                                                                                                                   height: 1080))) // 3
        } catch {
            print(error.localizedDescription) // 4
        }
    }

    private func setupDeviceOutput() {
        captureVideoOutput = AVCaptureVideoDataOutput()
        captureVideoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String):NSNumber(value: kCVPixelFormatType_32BGRA)]
        captureVideoOutput.alwaysDiscardsLateVideoFrames = false // 1

        if captureSession.canAddOutput(captureVideoOutput) { // 2
            captureSession.addOutput(captureVideoOutput)
        }

        captureSession.commitConfiguration() // 3

        let queue = DispatchQueue(label: "some string")
        captureVideoOutput.setSampleBufferDelegate(self, queue: queue) // 4
    }

    func startCamera() {
        captureSession.startRunning()
    }

    func stopCamera() {
        captureSession.stopRunning()
    }

    // MARK: - Chunks of Video

    fileprivate func createWriterInput(for presentationTimeStamp: CMTime) {
        let fileManager = FileManager.default
        chunkOutputURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("chunk\(chunkNumber).mov")
        try? fileManager.removeItem(at: chunkOutputURL) // 1

        assetWriter = try! AVAssetWriter(outputURL: chunkOutputURL, fileType: AVFileType.mov)
        assetWriter.shouldOptimizeForNetworkUse = true // 2

        let outputSettings: [String: Any] = [AVVideoCodecKey:AVVideoCodecType.h264,
                                             AVVideoWidthKey: 1920,
                                             AVVideoHeightKey: 1080,
                                             AVVideoCompressionPropertiesKey: [AVVideoExpectedSourceFrameRateKey: 60,
                                                                               AVVideoAverageNonDroppableFrameRateKey: 60,
                                                                               AVVideoAverageBitRateKey: 60000000,
                                                                               AVVideoMaxKeyFrameIntervalDurationKey: 0.0,
                                                                               AVVideoMaxKeyFrameIntervalKey: 1.0,
                                                                               AVVideoAllowFrameReorderingKey: true]]

        assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        assetWriterInput.expectsMediaDataInRealTime = true
        assetWriter.add(assetWriterInput) // 3

        chunkNumber += 1
        chunkStartTime = presentationTimeStamp // 4

        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: chunkStartTime) // 5
    }

    fileprivate func createVideoOutput(from buffer: CMSampleBuffer) {
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(buffer) // 1

        if assetWriter == nil {
            createWriterInput(for: presentationTimeStamp) // 2
        } else {
            let chunkDuration = CMTimeGetSeconds(CMTimeSubtract(presentationTimeStamp, chunkStartTime)) // 3

            if chunkDuration > latency {
                assetWriter.endSession(atSourceTime: presentationTimeStamp)

                let newChunkURL = chunkOutputURL!
                let chunkAssetWriter = assetWriter!

                chunkAssetWriter.finishWriting { [weak self] in
                    let item = AVPlayerItem(url: newChunkURL)
                    self?.didOutputPlayerItem?(item)
                }

                createWriterInput(for: presentationTimeStamp)
            }
        }

        if assetWriterInput.isReadyForMoreMediaData { // 4
            if !assetWriterInput.append(buffer) {
                print("append says NO: \(assetWriter.status.rawValue)")
            }
        }
    }
}

extension CameraFeed: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        createVideoOutput(from: sampleBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped Frame")
    }
}

extension AVCaptureDevice {

    // MARK: - Structs

    struct VideoSpec {
        var fps: Int32?
        var size: CGSize?
    }

    // MARK: - Private Methods

    private func availableFormatsFor(preferredFps: Float64) -> [AVCaptureDevice.Format] {
        var availableFormats: [AVCaptureDevice.Format] = []
        for format in formats {
            let ranges = format.videoSupportedFrameRateRanges
            for range in ranges where range.minFrameRate <= preferredFps && preferredFps <= range.maxFrameRate {
                availableFormats.append(format)
            }
        }
        return availableFormats
    }

    private func formatWithHighestResolution(_ availableFormats: [AVCaptureDevice.Format]) -> AVCaptureDevice.Format? {
        var maxWidth: Int32 = 0
        var selectedFormat: AVCaptureDevice.Format?
        for format in availableFormats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = dimensions.width
            if width >= maxWidth {
                maxWidth = width
                selectedFormat = format
            }
        }
        return selectedFormat
    }

    private func formatFor(preferredSize: CGSize, availableFormats: [AVCaptureDevice.Format]) -> AVCaptureDevice.Format? {
        for format in availableFormats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)

            if dimensions.width >= Int32(preferredSize.width) && dimensions.height >= Int32(preferredSize.height) {
                return format
            }
        }
        return nil
    }

    // MARK: - Public Methods

    func updateFormatWithPreferredVideoSpec(preferredSpec: VideoSpec) {
        let availableFormats: [AVCaptureDevice.Format]
        if let preferredFps = preferredSpec.fps {
            availableFormats = availableFormatsFor(preferredFps: Float64(preferredFps))
        } else {
            availableFormats = formats
        }

        var format: AVCaptureDevice.Format?
        if let preferredSize = preferredSpec.size {
            format = formatFor(preferredSize: preferredSize, availableFormats: availableFormats)
        } else {
            format = formatWithHighestResolution(availableFormats)
        }

        guard let selectedFormat = format else {return}
        print("selected format: \(selectedFormat)")
        do {
            try lockForConfiguration()
        } catch {
            fatalError("")
        }
        activeFormat = selectedFormat

        if let preferredFps = preferredSpec.fps {
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: preferredFps)
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: preferredFps)
            unlockForConfiguration()
        }
    }
}
