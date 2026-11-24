import SwiftUI
import PhotosUI
import UIKit

// 通用单图选择组件：支持相册选图、相机拍照、主图裁剪旋转，以及可选的画布透明抠图自定义精修
struct PhotoPickerField: View {
    @Binding var imageURL: String
    var label: String = "选张图"
    var height: CGFloat = 140
    var cutoutImageURL: Binding<String>?
    var isProcessing: Binding<Bool> = .constant(false)
    var galleryChoices: [RecipePhotoChoice] = []

    private enum ActiveCover: Identifiable {
        case camera
        case preview(PhotoGalleryPresentation)
        case cropMain(UIImage)
        case cropCutout(UIImage)
        case maskEditor

        var id: String {
            switch self {
            case .camera: return "camera"
            case .preview(let p): return "preview-\(p.id.uuidString)"
            case .cropMain: return "cropMain"
            case .cropCutout: return "cropCutout"
            case .maskEditor: return "maskEditor"
            }
        }
    }

    @State private var pickerItem: PhotosPickerItem?
    @State private var customCutoutPickerItem: PhotosPickerItem?
    @State private var isUploading: Bool = false
    @State private var errorMessage: String?
    @State private var activeCover: ActiveCover?
    @State private var processingMessage = "正在保存照片"

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !imageURL.isEmpty {
                Button {
                    Haptics.light()
                    activeCover = .preview(PhotoGalleryPresentation(urls: [imageURL]))
                } label: {
                    ZStack {
                        AsyncImageView(url: imageURL, name: label)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                if !isUploading {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.black.opacity(0.48), in: Circle())
                                        .overlay {
                                            Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6)
                                        }
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                            }
                        if isUploading {
                            uploadingOverlay
                        }
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .buttonStyle(.plain)
                .disabled(isUploading)
                .accessibilityLabel("查看大图")
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack {
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
                        if isUploading {
                            uploadingOverlay
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUploading)
            }

            HStack(spacing: AppSpacing.md) {
                if !imageURL.isEmpty {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("换照片", systemImage: "photo.on.rectangle")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                    }
                }
                Button {
                    activeCover = .camera
                } label: {
                    Label("拍照", systemImage: "camera")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                }
                if !imageURL.isEmpty {
                    Button {
                        Task { await openMainCropper() }
                    } label: {
                        Label("裁剪", systemImage: "crop.rotate")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                    }
                }
                Spacer()
                if !imageURL.isEmpty {
                    Button {
                        imageURL = ""
                        cutoutImageURL?.wrappedValue = ""
                    } label: {
                        Label("清除", systemImage: "trash")
                            .foregroundStyle(Color.errorInk)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                    }
                }
            }
            .font(AppFont.caption(12))
            .foregroundStyle(Color.brandGreen)
            .buttonStyle(.plain)
            .frame(minHeight: 40)
            .disabled(isUploading)

            if galleryChoices.count > 1, !isUploading {
                VStack(alignment: .leading, spacing: 6) {
                    Text("往期实拍图库（轻点切换）")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(galleryChoices) { choice in
                                let selected = choice.image == imageURL
                                Button {
                                    Haptics.light()
                                    imageURL = choice.image
                                    cutoutImageURL?.wrappedValue = choice.cutoutImage ?? ""
                                } label: {
                                    AsyncImageView(url: choice.image, name: label)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(
                                                    selected ? Color.actionInk : Color.dividerLine,
                                                    lineWidth: selected ? 2.2 : 0.7
                                                )
                                        }
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }
                }
            }

            if let cutoutBinding = cutoutImageURL, !isUploading {
                cutoutSection(cutoutBinding)
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
        .onChange(of: customCutoutPickerItem) { _, item in
            guard let item else { return }
            Task { await loadAndUploadCustomCutout(item) }
        }
        .fullScreenCover(item: $activeCover) { cover in
            switch cover {
            case .camera:
                CameraCaptureView(mode: cutoutImageURL == nil ? .photo : .dish) { photo in
                    try await upload(photo)
                }
                .ignoresSafeArea()
            case .preview(let presentation):
                PhotoGalleryViewer(slides: presentation.slides, initialIndex: presentation.initialIndex)
            case .cropMain(let img):
                ImageCropRotateSheet(initialImage: img, title: "裁剪与旋转照片", preservesAlpha: false) { cropped in
                    Task { await uploadCroppedMain(cropped) }
                }
            case .cropCutout(let img):
                ImageCropRotateSheet(initialImage: img, title: "裁剪画布贴图", preservesAlpha: true) { cropped in
                    Task { await uploadCroppedCutout(cropped) }
                }
            case .maskEditor:
                CutoutMaskEditorSheet(
                    sourceImageURL: imageURL.isEmpty ? nil : imageURL,
                    initialCutoutURL: (cutoutImageURL?.wrappedValue.isEmpty == false) ? cutoutImageURL?.wrappedValue : nil
                ) { pngData in
                    let uploaded = try await UploadService.shared.uploadImage(pngData, filename: "cutout.png", mime: "image/png")
                    await MainActor.run {
                        cutoutImageURL?.wrappedValue = uploaded.path
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cutoutSection(_ cutoutBinding: Binding<String>) -> some View {
        let hasCutout = !cutoutBinding.wrappedValue.isEmpty
        Divider().overlay(Color.dividerLine.opacity(0.6))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                if hasCutout {
                    Button {
                        Haptics.light()
                        activeCover = .preview(
                            PhotoGalleryPresentation(
                                urls: [cutoutBinding.wrappedValue],
                                caption: "画布透明贴图",
                                isTransparent: true
                            )
                        )
                    } label: {
                        ZStack {
                            TransparencyCheckerboard(cellSize: 8)
                            AsyncImageView(url: cutoutBinding.wrappedValue, name: "画布贴图", fitContent: true)
                                .padding(6)
                        }
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                .strokeBorder(Color.dividerLine.opacity(0.85), lineWidth: 0.7)
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel("查看画布贴图大图")
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(Color.appBackground)
                        .frame(width: 76, height: 76)
                        .overlay {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(Color.inkMuted)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(hasCutout ? "画布透明贴图" : "画布透明贴图（可选）")
                        .font(AppFont.headline(13.5))
                        .foregroundStyle(Color.inkPrimary)
                    Text(hasCutout ? "支持手涂擦除/恢复边缘、单独换贴图或裁剪" : "选主图自动生成，也可单独上传自定义透明贴图或手涂提取")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            FlowLayout(spacing: 8) {
                if hasCutout || !imageURL.isEmpty {
                    Button {
                        Haptics.light()
                        activeCover = .maskEditor
                    } label: {
                        cutoutActionPill(
                            title: hasCutout ? "涂抹精修" : "手动抠图",
                            icon: "paintbrush.pointed",
                            filled: true
                        )
                    }
                    .buttonStyle(SoftPressStyle())
                }

                if !imageURL.isEmpty {
                    Button {
                        Task { await regenerateCutout() }
                    } label: {
                        cutoutActionPill(title: "智能重抠", icon: "wand.and.stars")
                    }
                    .buttonStyle(SoftPressStyle())
                }

                PhotosPicker(selection: $customCutoutPickerItem, matching: .images) {
                    cutoutActionPill(title: "自定义贴图", icon: "square.and.arrow.up")
                }
                .buttonStyle(SoftPressStyle())

                if hasCutout {
                    Button {
                        Task { await openCutoutCropper() }
                    } label: {
                        cutoutActionPill(title: "裁剪贴图", icon: "crop")
                    }
                    .buttonStyle(SoftPressStyle())

                    Button {
                        Haptics.light()
                        cutoutBinding.wrappedValue = ""
                    } label: {
                        cutoutActionPill(title: "清除贴图", icon: "xmark", isDestructive: true)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
        .padding(.top, 2)
    }

    private func cutoutActionPill(
        title: String,
        icon: String,
        filled: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(filled ? .white : (isDestructive ? Color.errorInk : Color.inkPrimary))
        .padding(.horizontal, 11)
        .frame(height: 31)
        .background(filled ? Color.actionInk : Color.appBackground, in: Capsule())
        .overlay {
            if !filled {
                Capsule().strokeBorder(
                    isDestructive ? Color.errorInk.opacity(0.25) : Color.dividerLine.opacity(0.85),
                    lineWidth: 0.7
                )
            }
        }
    }

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 8) {
                ProgressView().tint(.white)
                Text(processingMessage).font(AppFont.caption()).foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    @MainActor
    private func loadAndUpload(_ item: PhotosPickerItem) async {
        guard !isUploading else { return }
        setProcessing(true)
        defer {
            setProcessing(false)
            pickerItem = nil
        }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "图片为空或无法读取，请换一张重试"
                return
            }
            if cutoutImageURL != nil {
                processingMessage = "正在保存照片与生成贴图"
                async let mainUpload: Void = savePhoto(data: data)
                async let cutoutTask: Result<Data, Error> = {
                    do {
                        return .success(try await ImageCutoutService.shared.makePNG(from: image))
                    } catch {
                        return .failure(error)
                    }
                }()
                try await mainUpload
                switch await cutoutTask {
                case .success(let png):
                    await uploadCutout(png)
                case .failure:
                    errorMessage = "照片已保留，自动抠图未识别主体，可点「手动抠图」涂抹提取"
                }
            } else {
                try await savePhoto(data: data)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func loadAndUploadCustomCutout(_ item: PhotosPickerItem) async {
        guard !isUploading else { return }
        setProcessing(true)
        processingMessage = "正在处理自定义贴图"
        defer {
            setProcessing(false)
            customCutoutPickerItem = nil
        }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取所选贴图，请重试"
                return
            }
            if RecipeImageEditHelpers.hasSignificantTransparency(image),
               let trimmed = RecipeImageEditHelpers.trimTransparentPixels(image, padding: 6),
               let png = trimmed.pngData() {
                await uploadCutout(png)
            } else if let png = try? await ImageCutoutService.shared.makePNG(from: image) {
                await uploadCutout(png)
            } else if let rawPNG = RecipeImageEditHelpers.normalizedUpImage(image, maxSide: 1200, opaque: false).pngData() {
                await uploadCutout(rawPNG)
                errorMessage = "未自动识别分离背景，已载入贴图，可点「涂抹精修」擦掉多余背景"
            } else {
                errorMessage = "无法编码透明贴图"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openMainCropper() async {
        guard !isUploading, !imageURL.isEmpty else { return }
        setProcessing(true)
        processingMessage = "正在读取照片"
        defer { setProcessing(false) }
        guard let img = await RecipeImageEditHelpers.loadUIImage(from: imageURL) else {
            errorMessage = "无法读取当前照片，请重新选择"
            return
        }
        activeCover = .cropMain(img)
    }

    @MainActor
    private func openCutoutCropper() async {
        guard !isUploading, let path = cutoutImageURL?.wrappedValue, !path.isEmpty else { return }
        setProcessing(true)
        processingMessage = "正在读取贴图"
        defer { setProcessing(false) }
        guard let img = await RecipeImageEditHelpers.loadUIImage(from: path) else {
            errorMessage = "无法读取当前贴图，请重试"
            return
        }
        activeCover = .cropCutout(img)
    }

    @MainActor
    private func uploadCroppedMain(_ cropped: UIImage) async {
        guard !isUploading, let jpeg = RecipeImageEditHelpers.compressedJPEG(cropped) else { return }
        setProcessing(true)
        processingMessage = "正在保存裁剪后的照片"
        defer { setProcessing(false) }
        errorMessage = nil
        do {
            let uploaded = try await UploadService.shared.uploadImage(jpeg, filename: "cropped.jpg", mime: "image/jpeg")
            imageURL = uploaded.path
            // 仅在尚未设置贴图时自动抠图，保留已有的自定义或手涂精修贴图
            if let cutoutBinding = cutoutImageURL, cutoutBinding.wrappedValue.isEmpty {
                await generateCutout(from: cropped)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func uploadCroppedCutout(_ cropped: UIImage) async {
        let finalImg = RecipeImageEditHelpers.trimTransparentPixels(cropped, padding: 6) ?? cropped
        guard !isUploading, let png = finalImg.pngData() else { return }
        setProcessing(true)
        processingMessage = "正在保存裁剪后的贴图"
        defer { setProcessing(false) }
        errorMessage = nil
        await uploadCutout(png)
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
        let compressed = await Self.compressOffMain(data: data)
        let uploaded = try await UploadService.shared.uploadImage(compressed)
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
            errorMessage = "照片已保留，自动抠图未识别主体，可点「手动抠图」涂抹提取"
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
        guard !isUploading, !imageURL.isEmpty else { return }
        setProcessing(true)
        defer { setProcessing(false) }
        errorMessage = nil
        guard let image = await RecipeImageEditHelpers.loadUIImage(from: imageURL) else {
            errorMessage = "无法读取主图，请重新选择照片"
            return
        }
        await generateCutout(from: image)
    }

    private func setProcessing(_ value: Bool) {
        isUploading = value
        isProcessing.wrappedValue = value
        processingMessage = "正在保存照片"
    }

    private static func compressOffMain(data: Data) async -> Data {
        await Task.detached(priority: .userInitiated) {
            guard let img = UIImage(data: data) else { return data }
            let maxSide: CGFloat = 1600
            let size = img.size
            guard size.width > 0, size.height > 0 else { return data }
            let scale = min(1.0, maxSide / max(size.width, size.height))
            let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: target, format: format)
            let resized = renderer.image { _ in
                img.draw(in: CGRect(origin: .zero, size: target))
            }
            return resized.jpegData(compressionQuality: 0.82) ?? data
        }.value
    }
}
