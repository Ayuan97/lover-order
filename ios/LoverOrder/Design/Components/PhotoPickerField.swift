import SwiftUI
import PhotosUI
import UIKit

// 通用单图选择组件 选完自动上传 返回 URL
struct PhotoPickerField: View {
    @Binding var imageURL: String
    var label: String = "选张图"
    var height: CGFloat = 140
    var cutoutImageURL: Binding<String>?
    var isProcessing: Binding<Bool> = .constant(false)

    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading: Bool = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var processingMessage = "正在保存照片"

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    if !imageURL.isEmpty {
                        AsyncImageView(url: imageURL, name: label)
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    } else {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Color.brandGreen)
                            Text(label)
                                .font(AppFont.body(14))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .stroke(Color.brandGreen.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    if isUploading {
                        ZStack {
                            Color.black.opacity(0.25)
                            VStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text(processingMessage).font(AppFont.caption()).foregroundStyle(.white)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploading)

            HStack {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                Spacer()
                if !imageURL.isEmpty {
                    Button {
                        imageURL = ""
                        cutoutImageURL?.wrappedValue = ""
                    } label: {
                        Label("清掉这张图", systemImage: "trash")
                    }
                }
            }
            .font(AppFont.caption(12))
            .foregroundStyle(Color.brandGreen)
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .disabled(isUploading)

            if let cutoutImageURL, !imageURL.isEmpty, !isUploading {
                if !cutoutImageURL.wrappedValue.isEmpty {
                    HStack(spacing: AppSpacing.md) {
                        AsyncImage(url: APIConfig.imageURL(cutoutImageURL.wrappedValue)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { ProgressView() }
                        .frame(width: 72, height: 72)
                        .background(Color.paperGreen, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                        Text("画布贴图已生成")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.inkSecondary)
                    }
                } else {
                    Button("重新生成画布贴图") { Task { await regenerateCutout() } }
                        .font(AppFont.caption())
                        .foregroundStyle(Color.brandGreen)
                        .frame(minHeight: 44)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.errorInk)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadAndUpload(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(mode: cutoutImageURL == nil ? .photo : .dish) { photo in
                try await upload(photo)
            }
            .ignoresSafeArea()
        }
    }

    @MainActor
    private func loadAndUpload(_ item: PhotosPickerItem) async {
        guard !isUploading else { return }
        setProcessing(true)
        defer { setProcessing(false) }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "图片为空"
                return
            }
            try await savePhoto(data: data)
            if cutoutImageURL != nil { await generateCutout(from: image) }
        } catch { errorMessage = error.localizedDescription }
        pickerItem = nil
    }

    @MainActor
    private func upload(_ photo: CameraPhoto) async throws {
        guard !isUploading, let data = photo.image.jpegData(compressionQuality: 0.95) else {
            throw CocoaError(.fileWriteUnknown)
        }
        setProcessing(true)
        defer { setProcessing(false) }
        errorMessage = nil
        try await savePhoto(data: data)
        if let png = photo.cutoutData {
            await uploadCutout(png)
        } else if let message = photo.cutoutError {
            errorMessage = "照片已保留，画布贴图生成失败：\(message)"
        }
    }

    @MainActor
    private func savePhoto(data: Data) async throws {
        let uploaded = try await UploadService.shared.uploadImage(compress(data: data))
        // 存相对路径 换 IP / 模拟器真机混用时图都不挂
        imageURL = uploaded.path
        cutoutImageURL?.wrappedValue = ""
    }

    @MainActor
    private func generateCutout(from image: UIImage) async {
        processingMessage = "正在生成画布贴图"
        do {
            let png = try await ImageCutoutService.shared.makePNG(from: image)
            await uploadCutout(png)
        } catch {
            errorMessage = "照片已保留，画布贴图生成失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func uploadCutout(_ png: Data) async {
        do {
            let uploaded = try await UploadService.shared.uploadImage(png, filename: "cutout.png", mime: "image/png")
            cutoutImageURL?.wrappedValue = uploaded.path
        } catch {
            errorMessage = "照片已保留，画布贴图上传失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func regenerateCutout() async {
        guard !isUploading, let url = APIConfig.imageURL(imageURL) else { return }
        setProcessing(true)
        defer { setProcessing(false) }
        errorMessage = nil
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else {
                errorMessage = "无法读取主图，请重新选择照片"
                return
            }
            await generateCutout(from: image)
        } catch { errorMessage = error.localizedDescription }
    }

    private func setProcessing(_ value: Bool) {
        isUploading = value
        isProcessing.wrappedValue = value
        processingMessage = "正在保存照片"
    }

    private func compress(data: Data) -> Data {
        guard let img = UIImage(data: data) else { return data }
        let maxSide: CGFloat = 1600
        let size = img.size
        let scale = min(1.0, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82) ?? data
    }
}
