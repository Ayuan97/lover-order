import SwiftUI
import UIKit
import AVFoundation

struct CameraPhoto {
    let image: UIImage
    let cutoutData: Data?
    let cutoutError: String?
}

enum CameraCaptureMode {
    case photo, dish, sticker

    var extractsSubject: Bool { self != .photo }
    var title: String {
        switch self {
        case .photo: return "拍摄照片"
        case .dish: return "拍摄菜品主图"
        case .sticker: return "拍照做贴图"
        }
    }
}

struct CameraCaptureView: View {
    var mode: CameraCaptureMode = .photo
    var onCaptured: (CameraPhoto) async throws -> Void
    #if DEBUG && targetEnvironment(simulator)
    var simulatorPreview: ImageCutout?
    #endif

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraCaptureController()
    @State private var cutout: ImageCutout?
    @State private var generationID = UUID()
    @State private var revealPhase = 0
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var flashEnabled = false
    @State private var message: String?
    @State private var cutoutError: String?

    private var isReviewing: Bool { camera.photo != nil }
    private var previewSample: ImageCutout? {
        #if DEBUG && targetEnvironment(simulator)
        simulatorPreview
        #else
        nil
        #endif
    }
    private var canCapture: Bool { camera.isReady || previewSample != nil }
    private var ink: Color { isReviewing ? .inkPrimary : .white }
    private var canConfirm: Bool {
        let finished = !mode.extractsSubject || cutout != nil || cutoutError != nil
        return finished && !isProcessing && (mode != .sticker || cutout != nil)
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            header
            viewfinder
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
            status
            controls
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.lg)
        .background((isReviewing ? Color.appBackground : Color.actionInk).ignoresSafeArea())
        .statusBarHidden()
        .interactiveDismissDisabled(isSaving)
        .task { await startCamera() }
        .task(id: generationID) { await processPhoto() }
        .onChange(of: camera.photoID) { _, _ in
            cutout = nil
            cutoutError = nil
            message = nil
            revealPhase = 0
            generationID = UUID()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !isReviewing { Task { await startCamera() } }
            else if phase != .active { camera.stop() }
        }
        .onDisappear { camera.stop() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("关闭拍摄")
            .disabled(isSaving)
            Spacer()
            Text(mode.title).font(AppFont.headline(17)).lineLimit(1)
            Spacer()
            Button { flashEnabled.toggle() } label: {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
            }
            .opacity(!isReviewing && camera.supportsFlash ? 1 : 0)
            .disabled(isReviewing || !camera.supportsFlash)
            .accessibilityHidden(isReviewing || !camera.supportsFlash)
            .accessibilityLabel(flashEnabled ? "关闭闪光灯" : "开启闪光灯")
        }
        .foregroundStyle(ink)
        .buttonStyle(SoftPressStyle())
    }

    private var viewfinder: some View {
        ZStack {
            if let photo = camera.photo {
                CutoutRevealView(photo: photo, cutout: cutout, phase: revealPhase)
            } else {
                if let previewSample {
                    Image(uiImage: previewSample.source).resizable().scaledToFit()
                } else {
                    CameraPreview(session: camera.session, onFocus: camera.focus)
                }
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [12, 8]))
                    .padding(28)
                    .allowsHitTesting(false)
                if !canCapture {
                    if message != nil || camera.errorMessage != nil {
                        Label("相机尚未开启", systemImage: "camera")
                            .font(AppFont.body(15)).foregroundStyle(.white)
                            .padding(20).background(.black.opacity(0.5), in: Capsule())
                    } else {
                        ProgressView().tint(.white).padding(20)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var status: some View {
        VStack(spacing: 8) {
            if previewSample != nil {
                Text("模拟器示例 · 仅演示界面与动效")
                    .font(AppFont.caption()).foregroundStyle(ink.opacity(0.7))
            }
            HStack(spacing: 8) {
                if isProcessing { ProgressView().tint(Color.brandGreen) }
                else if cutout != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandGreen) }
                Text(isProcessing ? "正在分离主体" : cutout != nil ? "背景已移除，贴图准备好了" : isReviewing ? "确认这张照片" : "让主体完整地出现在画面里，轻点画面可对焦")
                    .font(AppFont.body(14))
            }
            .foregroundStyle(ink.opacity(0.85))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            if let error = message ?? camera.errorMessage {
                Text(error).font(AppFont.caption())
                    .foregroundStyle(isReviewing ? Color.errorInk : Color.white)
                    .multilineTextAlignment(.center)
            }
            if cutoutError != nil, !isProcessing {
                Button("重新抠图") { generationID = UUID() }
                    .font(AppFont.body(14)).foregroundStyle(Color.brandGreen)
                    .frame(minHeight: 44).disabled(isSaving)
            } else if !isReviewing, message != nil || camera.errorMessage != nil {
                Button("重试相机") { Task { await startCamera() } }
                    .foregroundStyle(.white).frame(minHeight: 44)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var controls: some View {
        if isReviewing {
            HStack(spacing: AppSpacing.md) {
                SecondaryButton(title: "重拍", icon: "arrow.clockwise") {
                    camera.clearPhoto()
                    if previewSample == nil { camera.start() }
                }
                .frame(width: 100)
                .disabled(isProcessing || isSaving)
                PrimaryButton(
                    title: previewSample != nil ? "重播动效" : mode == .sticker ? "添加到画布" : cutoutError != nil ? "保留照片" : "使用照片",
                    isLoading: isSaving
                ) {
                    if previewSample != nil { generationID = UUID() }
                    else { Task { await confirmPhoto() } }
                }
                .disabled(!canConfirm)
            }
        } else {
            Button {
                if let previewSample { camera.acceptPhoto(previewSample.source) }
                else { camera.capture(flash: flashEnabled) }
            } label: {
                Circle().fill(.white)
                    .padding(6)
                    .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                    .frame(width: 76, height: 76)
                    .opacity(canCapture && !camera.isCapturing ? 1 : 0.4)
            }
            .buttonStyle(SoftPressStyle())
            .disabled(!canCapture || camera.isCapturing)
            .accessibilityLabel("拍照")
            .padding(.vertical, 8)
        }
    }

    @MainActor
    private func startCamera() async {
        guard previewSample == nil else { return }
        do {
            try await CameraCaptureController.requestAccess()
            try Task.checkCancellation()
            message = nil
            camera.start()
        } catch is CancellationError {
        } catch { message = error.localizedDescription }
    }

    @MainActor
    private func processPhoto() async {
        guard let photo = camera.photo, mode.extractsSubject else { return }
        cutout = nil
        cutoutError = nil
        message = nil
        revealPhase = 0
        isProcessing = true
        do {
            let result: ImageCutout
            if let previewSample { result = previewSample }
            else { result = try await ImageCutoutService.shared.makeCutout(from: photo) }
            try Task.checkCancellation()
            cutout = result
            isProcessing = false
            if reduceMotion {
                revealPhase = 3
            } else {
                withAnimation(.easeOut(duration: 0.24)) { revealPhase = 1 }
                try await Task.sleep(for: .milliseconds(240))
                withAnimation(.easeInOut(duration: 0.4)) { revealPhase = 2 }
                try await Task.sleep(for: .milliseconds(400))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { revealPhase = 3 }
            }
            Haptics.light()
        } catch is CancellationError {
            isProcessing = false
        } catch {
            isProcessing = false
            cutoutError = error.localizedDescription
            message = error.localizedDescription
        }
    }

    @MainActor
    private func confirmPhoto() async {
        guard let photo = camera.photo, canConfirm, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await onCaptured(CameraPhoto(image: photo, cutoutData: cutout?.pngData, cutoutError: cutoutError))
            dismiss()
        } catch { message = error.localizedDescription }
    }
}

private final class CameraCaptureController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var supportsFlash = false
    @Published private(set) var photo: UIImage?
    @Published private(set) var photoID: UUID?
    @Published private(set) var errorMessage: String?
    private let queue = DispatchQueue(label: "com.loverorder.camera")
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false

    static func requestAccess() async throws {
        guard AVCaptureDevice.default(for: .video) != nil else { throw CameraError.unavailable }
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraError.denied }
    }

    func start() {
        queue.async {
            do {
                if !self.isConfigured { try self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async {
                    self.isReady = self.session.isRunning
                    self.errorMessage = nil
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isReady = false }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(output) else { throw CameraError.unavailable }
        session.addInput(input)
        session.addOutput(output)
        self.device = device
        isConfigured = true
        DispatchQueue.main.async { self.supportsFlash = device.hasFlash }
    }

    func capture(flash: Bool) {
        guard isReady, !isCapturing else { return }
        isCapturing = true
        errorMessage = nil
        queue.async {
            guard self.session.isRunning else {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.errorMessage = "相机尚未准备好，请稍后再拍"
                }
                return
            }
            let settings = AVCapturePhotoSettings()
            if self.device?.hasFlash == true { settings.flashMode = flash ? .on : .off }
            if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func clearPhoto() {
        photo = nil
        photoID = nil
    }

    func acceptPhoto(_ image: UIImage) {
        isCapturing = false
        photo = image
        photoID = UUID()
    }

    func focus(at point: CGPoint) {
        queue.async {
            guard let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "暂时无法对焦，请稍后再点一下" }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.isCapturing = false
                self.errorMessage = error?.localizedDescription ?? "没有拍到照片，请再试一次"
            }
            return
        }
        DispatchQueue.main.async {
            self.acceptPhoto(image)
        }
        stop()
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onFocus: (CGPoint) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        view.onFocus = onFocus
        view.setNeedsLayout()
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onFocus: ((CGPoint) -> Void)?
    private let focusRing = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        focusRing.layer.borderWidth = 1.5
        focusRing.layer.borderColor = UIColor.white.cgColor
        focusRing.layer.cornerRadius = 12
        focusRing.isUserInteractionEnabled = false
        focusRing.alpha = 0
        addSubview(focusRing)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = preview.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    @objc private func focus(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        onFocus?(preview.captureDevicePointConverted(fromLayerPoint: point))
        focusRing.layer.removeAllAnimations()
        focusRing.frame = CGRect(x: point.x - 30, y: point.y - 30, width: 60, height: 60)
        focusRing.alpha = 1
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2, delay: 0.8) {
            self.focusRing.alpha = 0
        }
    }
}

private enum CameraError: LocalizedError {
    case unavailable, denied

    var errorDescription: String? {
        switch self {
        case .unavailable: return "当前设备无法使用相机，请使用有相机的设备"
        case .denied: return "请在系统设置中允许访问相机后再拍照"
        }
    }
}
