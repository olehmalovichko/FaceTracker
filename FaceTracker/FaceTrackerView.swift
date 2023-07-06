//
//  ContentView.swift
//  FaceTracker
//
//  Created by Oleg Malovichko on 04.07.2023.
//

import SwiftUI
import MetalPetal
import AVKit

struct FaceTrackerView: View {
    
    @StateObject private var capturePipeline = CapturePipeline()
    
    @State private var isRecordButtonEnabled = true
    @State private var isVideoPlayerPresented = false
    
    @State private var error: Error?
    @State private var videoPlayer: AVPlayer?
    
    var body: some View {
        ZStack {
            VStack {
                Group {
                    if let cgImage = capturePipeline.previewImage {
                        Image(uiImage: UIImage(cgImage: cgImage))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        cameraUnavailableView()
                    }
                }
                
                startButton()
            }
            .overlay {
                controlsView()
            }
            
            if let error = self.error {
                Text(error.localizedDescription)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(Color.black.opacity(0.7))
                    }
            }
        }
        .onAppear(perform: {
            capturePipeline.startRunningCaptureSession()
        })
        
        .onDisappear(perform: {
            capturePipeline.stopRunningCaptureSession()
        })
        
        .sheet(isPresented: $isVideoPlayerPresented, content: {
            if let player = videoPlayer {
                VideoPlayer(player: player).onAppear(perform: {
                    player.play()
                })
                .frame(minHeight: 480)
                .overlay {
                    videoPlayerOverlay()
                }
            }
        })
    }
}


// MARK: Views
private extension FaceTrackerView {
    
    @ViewBuilder private func videoPlayerOverlay() -> some View {
        VStack {
            
            Spacer(minLength: 0)
            
            Button {
                isVideoPlayerPresented = false
            } label: {
                Text("Dismiss")
                    .foregroundColor(.black)
                    .padding(8)
                    .background(.yellow)
                    .cornerRadius(30)
            }
            .padding(.bottom, 30)
        }
    }
    
    @ViewBuilder private func controlsView() -> some View {
        VStack(spacing: 0) {
            Picker(selection: $capturePipeline.effect, label: Text(capturePipeline.effect.rawValue), content: {
                ForEach(Effect.allCases) { effect in
                    Text(effect.rawValue)
                        .tag(effect)
                        .foregroundColor(.black)
                }
            })
            .scaledToFit()
            .pickerStyle(
                SegmentedPickerStyle()
            )
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder private func cameraUnavailableView() -> some View {
        Rectangle()
            .foregroundColor(
                Color.gray.opacity(0.5)
            )
            .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fit)
            .overlay(
                Image(systemName: "video.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color.white.opacity(0.5))
            )
    }
    
    @ViewBuilder private func startButton() -> some View {
        Button {
            if capturePipeline.state.isRecording {
                isRecordButtonEnabled = false
                capturePipeline.stopRecording(completion: { result in
                    isRecordButtonEnabled = true
                    switch result {
                    case .success(let url):
                        videoPlayer = AVPlayer(url: url)
                        isVideoPlayerPresented = true
                    case .failure(let error):
                        Task {
                            await showError(error)
                        }
                    }
                })
            } else {
                videoPlayer = nil
                isVideoPlayerPresented = false
                do {
                    try capturePipeline.startRecording()
                } catch {
                    Task {
                        await showError(error)
                    }
                }
            }
        } label: {
            Text(capturePipeline.state.isRecording ? "Stop Recording" : "Start Recording")
                .foregroundColor(.black)
                .padding(8)
                .background(
                    capturePipeline.state.isRecording ? .red : .yellow
                )
                .cornerRadius(30)
        }
        .disabled(!isRecordButtonEnabled)
    }
}

// MARK: Functions
private extension FaceTrackerView {
    func showError(_ error: Error) async {
        
        withAnimation {
            isRecordButtonEnabled = false
            self.error = error
        }
        
        try? await Task.sleep(seconds: 1.5)
        withAnimation {
            isRecordButtonEnabled = true
            self.error = nil
        }
        
    }
}

struct FaceTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        FaceTrackerView()
    }
}
