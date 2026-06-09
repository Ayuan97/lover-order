import SwiftUI
import PhotosUI
import UIKit

// 多图选择 + 上传 用于评价配图等
struct MultiPhotoPicker: View {
    @Binding var urls: [String]
    var maxCount: Int = 9

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(urls, id: \.self) { url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImageView(url: url, name: "")
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                            Button {
                                urls.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                    if urls.count < maxCount {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: maxCount - urls.count,
                            matching: .images
                        ) {
                            ZStack {
                                Color.appBackground
                                    .frame(width: 96, height: 96)
                                if isUploading {
                                    ProgressView().tint(Color.brandGreen)
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 18))
                                        Text("加照片")
                                            .font(AppFont.caption(11))
                                    }
                                    .foregroundStyle(Color.brandGreen)
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                    .stroke(Color.brandGreen.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                    }
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.errorInk)
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await uploadAll(items) }
        }
    }

    private func uploadAll(_ items: [PhotosPickerItem]) async {
        errorMessage = nil
        isUploading = true
        defer {
            isUploading = false
            pickerItems = []
        }
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let compressed = compress(data: data)
                let uploaded = try await UploadService.shared.uploadImage(compressed)
                urls.append(uploaded.url)
            } catch {
                errorMessage = error.localizedDescription
            }
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
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.82) ?? data
    }
}
