import SwiftUI
import PhotosUI
import UIKit

// 通用单图选择组件 选完自动上传 返回 URL
struct PhotoPickerField: View {
    @Binding var imageURL: String
    var label: String = "选张图"
    var height: CGFloat = 140

    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading: Bool = false
    @State private var errorMessage: String?

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
                            ProgressView().tint(.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    }
                }
            }
            .buttonStyle(.plain)

            if !imageURL.isEmpty {
                Button {
                    imageURL = ""
                } label: {
                    Label("清掉这张图", systemImage: "trash")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
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
    }

    private func loadAndUpload(_ item: PhotosPickerItem) async {
        errorMessage = nil
        isUploading = true
        defer { isUploading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "图片为空"
                return
            }
            let compressed = compress(data: data)
            let uploaded = try await UploadService.shared.uploadImage(compressed)
            imageURL = uploaded.url
        } catch {
            errorMessage = error.localizedDescription
        }
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
