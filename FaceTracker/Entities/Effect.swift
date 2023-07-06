//
//  Effect.swift
//  FaceTracker
//
//  Created by Oleg Malovichko on 06.07.2023.
//

import MetalPetal

enum Effect: String, Identifiable, CaseIterable {
    case faceTrackingPixellate = "Face"
    case grayscale = "Gray"
    case none = "No Filter"
    
    typealias Filter = (MTIImage, [Face]) -> MTIImage
    
    var id: String {
        rawValue
    }
    
    func makeFilter() -> Filter {
        switch self {
        case .none:
            return { image, faces in image }
        case .grayscale:
            return { image, faces in image.adjusting(saturation: 0) }
        case .faceTrackingPixellate:
            return { image, faces in
                let kernel = MTIPixellateFilter.kernel()
                var renderCommands =  [MTIRenderCommand]()
                renderCommands.append(MTIRenderCommand(kernel: .passthrough, geometry: MTIVertices.fullViewportSquare, images: [image], parameters: [:]))
                for face in faces {
                    let normalizedX = Float(face.bounds.origin.x / image.size.width)
                    let normalizedY = Float(face.bounds.origin.y / image.size.height)
                    let normalizedWidth = Float(face.bounds.width / image.size.width)
                    let normalizedHeight = Float(face.bounds.height / image.size.height)
                    let vertices = MTIVertices(vertices: [
                        MTIVertex(x: normalizedX * 2 - 1, y: (1.0 - normalizedY - normalizedHeight) * 2 - 1, z: 0, w: 1, u: normalizedX, v: normalizedY + normalizedHeight),
                        MTIVertex(x: (normalizedX + normalizedWidth) * 2 - 1, y: (1.0 - normalizedY - normalizedHeight) * 2 - 1, z: 0, w: 1, u: normalizedX + normalizedWidth, v: normalizedY + normalizedHeight),
                        MTIVertex(x: normalizedX * 2 - 1, y: (1.0 - normalizedY) * 2 - 1, z: 0, w: 1, u: normalizedX, v: normalizedY),
                        MTIVertex(x: (normalizedX + normalizedWidth) * 2 - 1, y: (1.0 - normalizedY) * 2 - 1, z: 0, w: 1, u: normalizedX + normalizedWidth, v: normalizedY),
                    ], primitiveType: .triangleStrip)
                    let faceRenderCommand = MTIRenderCommand(kernel: kernel, geometry: vertices, images: [image], parameters: ["scale": SIMD2<Float>(50, 50)])
                    renderCommands.append(faceRenderCommand)
                }
                return MTIRenderCommand.images(byPerforming: renderCommands, outputDescriptors: [MTIRenderPassOutputDescriptor(dimensions: image.dimensions, pixelFormat: .unspecified)])[0]
            }
        }
    }
}
