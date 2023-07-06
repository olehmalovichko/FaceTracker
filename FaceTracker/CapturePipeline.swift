//
//  CapturePipeline.swift
//  FaceTracker
//
//  Created by Oleg Malovichko on 04.07.2023.
//

import Foundation
import SwiftUI
import MetalPetal
import VideoToolbox
import AVKit
import VideoIO

class CapturePipeline: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    struct State {
        var isRecording = false
        var isVideoMirrored = true
    }
    
    @Published private var stateChangeCount: Int = 0
    
    private var _state: State = State()
    
    private let stateLock = MTILockCreate()
    
    private(set) var state: State {
        get {
            stateLock.lock()
            defer {
                stateLock.unlock()
            }
            return _state
        }
        set {
            stateLock.lock()
            defer {
                stateLock.unlock()
                stateChangeCount += 1
            }
            _state = newValue
        }
    }
    
    @Published var previewImage: CGImage?
    
    private let renderContext = try! MTIContext(device: MTLCreateSystemDefaultDevice()!)
    
    private let camera: Camera = {
        var configurator = Camera.Configurator()
        let interfaceOrientation = UIApplication.shared.keyWindowFirst?.windowScene?.interfaceOrientation
        configurator.videoConnectionConfigurator = { camera, connection in
            switch interfaceOrientation {
            case .landscapeLeft:
                connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                connection.videoOrientation = .portrait
            }
        }
        return Camera(captureSessionPreset: .high, defaultCameraPosition: .front, configurator: configurator)
    }()
    
    private let imageRenderer = PixelBufferPoolBackedImageRenderer()
    
    private var filter: Effect.Filter = { image, faces in image }
    
    private var faces: [Face] = []
    
    private var isMetadataOutputEnabled: Bool = false
    
    private var recorder: MovieRecorder?
    
    @Published var effect: Effect = .none {
        didSet {
            let filter = effect.makeFilter()
            let currentEffect = effect
            Task {
                if currentEffect == .faceTrackingPixellate && !self.isMetadataOutputEnabled {
                    self.camera.stopRunningCaptureSession()
                    try? self.camera.enableMetadataOutput(for: [.face], on: .main, delegate: self)
                    self.camera.startRunningCaptureSession()
                    self.isMetadataOutputEnabled = true
                }
                self.filter = filter
            }
        }
    }
    
    override init() {
        super.init()
        try? self.camera.enableVideoDataOutput(on: .main, delegate: self)
        try? self.camera.enableAudioDataOutput(on: .main, delegate: self)
        self.camera.videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        self.effect = .faceTrackingPixellate
    }
    
    func startRunningCaptureSession() {
        Task {
            self.camera.startRunningCaptureSession()
        }
    }
    
    func stopRunningCaptureSession() {
        Task {
            self.camera.stopRunningCaptureSession()
        }
    }
    
    func startRecording() throws {
        let sessionID = UUID()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sessionID.uuidString).mp4")
        let hasAudio = self.camera.audioDataOutput != nil
        let recorder = try MovieRecorder(url: url, configuration: MovieRecorder.Configuration(hasAudio: hasAudio))
        state.isRecording = true
        
        Task {
            self.recorder = recorder
        }
    }
    
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        if let recorder = recorder {
            recorder.stopRecording(completion: { error in
                self.state.isRecording = false
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(recorder.url))
                }
            })
            
            Task {
                self.recorder = nil
            }
        }
    }
    
    @MainActor
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDescription = sampleBuffer.formatDescription else {
            return
        }
        switch formatDescription.mediaType {
        case .audio:
            do {
                try self.recorder?.appendSampleBuffer(sampleBuffer)
            } catch {
                print(error)
            }
        case .video:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            do {
                let image = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .alphaIsOne)
                let filterOutputImage = self.filter(image, faces)
                let outputImage = self.state.isVideoMirrored ? filterOutputImage.oriented(.upMirrored) : filterOutputImage
                let renderOutput = try self.imageRenderer.render(outputImage, using: renderContext)
                try self.recorder?.appendSampleBuffer(SampleBufferUtilities.makeSampleBufferByReplacingImageBuffer(of: sampleBuffer, with: renderOutput.pixelBuffer)!)
                Task {
                    self.previewImage = renderOutput.cgImage
                }
            } catch {
                print(error)
            }
        default:
            break
        }
    }
}

extension CapturePipeline: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        var faces = [Face]()
        for faceMetadataObject in metadataObjects.compactMap ({ $0 as? AVMetadataFaceObject }) {
            if let rect = self.camera.videoDataOutput?.outputRectConverted(fromMetadataOutputRect: faceMetadataObject.bounds) {
                faces.append(Face(bounds: rect.insetBy(dx: -rect.width/4, dy: -rect.height/4)))
            }
        }
        self.faces = faces
    }
}
