//
//  CameraPreviewView.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//
//  UIViewRepresentable wrapping AVCaptureVideoPreviewLayer.
//  The preview layer is backed by the same AVCaptureSession as VisionPoseTracker,
//  so no additional session or extra permissions are needed.
//

import SwiftUI
import AVFoundation

#if os(iOS)
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> _PreviewView {
        let v = _PreviewView()
        v.previewLayer.session      = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: _PreviewView, context: Context) {
        // Preview layer automatically follows the session; nothing to update.
    }

    // Internal UIView subclass that uses AVCaptureVideoPreviewLayer as its backing layer.
    final class _PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
#endif
