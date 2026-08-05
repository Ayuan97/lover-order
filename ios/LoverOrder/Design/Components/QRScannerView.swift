import SwiftUI
import AVFoundation
import UIKit

// 扫码页 扫对方餐券/聚餐码 拿到字符串；权限未开时说明+去设置+手输
struct QRScannerScreen: View {
    var hint: String = "对准对方餐券上的二维码"
    var manualEntryTitle: String = "改为手输"
    let onCode: (String) -> Void
    var onManualEntry: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var permission: CameraPermission = .checking

    private enum CameraPermission {
        case checking, authorized, denied
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch permission {
            case .checking:
                ProgressView().tint(.white)
            case .authorized:
                scannerContent
            case .denied:
                deniedContent
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .padding(AppSpacing.lg)
        }
        .onAppear { resolvePermission() }
    }

    private var scannerContent: some View {
        ZStack {
            QRScannerRepresentable { code in
                onCode(code)
                dismiss()
            }
            .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 230, height: 230)
                Text(hint)
                    .font(AppFont.body())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                Spacer()
            }
        }
    }

    private var deniedContent: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
            Text("需要相机权限才能扫码")
                .font(AppFont.headline(18))
                .foregroundStyle(.white)
            Text("请在系统设置中允许使用相机\n也可以先关掉此页 用手输邀请码或房间号")
                .font(AppFont.body(14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("去设置开启相机")
                    .font(AppFont.headline(16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.xxl)

            Button {
                onManualEntry?()
                dismiss()
            } label: {
                Text(manualEntryTitle)
                    .font(AppFont.body(15))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
    }

    private func resolvePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    permission = ok ? .authorized : .denied
                }
            }
        default:
            permission = .denied
        }
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onScan = onScan
        return vc
    }
    func updateUIViewController(_ vc: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var handled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // 权限已在 SwiftUI 层确认 这里只负责开流
        configure()
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.layer.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !handled,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue, !str.isEmpty else { return }
        handled = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        session.stopRunning()
        onScan?(str)
    }
}
