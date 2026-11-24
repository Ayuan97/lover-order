import PhotosUI
import SwiftUI
import UIKit

struct DishPhotoApplyResult {
    let updatedDish: MealDish
    let newlyCaptured: Bool
    let isAlreadyCover: Bool
}

// 画布选中菜品 / 餐后记录共用的「换一张菜图」面板：
// 支持拍今天这盘、从相册抠图，以及在菜谱历次实拍与默认封面之间自由切换。
struct DishPhotoPickerSheet: View {
    let mealId: UInt
    let dish: MealDish
    var onApplied: (DishPhotoApplyResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var isLoadingGallery = false
    @State private var isProcessing = false
    @State private var processingText = "正在保存照片"
    @State private var albumItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var shouldDismissAfterCamera = false
    @State private var errorMessage: String?
    @State private var tipMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    captureButtons
                    if dish.recipeId != nil {
                        gallerySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }

            if isProcessing {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(processingText)
                        .font(AppFont.body(14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(Color.actionInk.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isProcessing)
        .toast($errorMessage)
        .tipToast($tipMessage)
        .task {
            await loadRecipeGallery()
        }
        .onChange(of: albumItem) { _, item in
            guard let item else { return }
            Task { await handlePickedPhoto(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(mode: .dish) { photo in
                try await handleCapturedPhoto(photo)
            }
            .ignoresSafeArea()
        }
        .onChange(of: showCamera) { _, presented in
            if !presented && shouldDismissAfterCamera {
                shouldDismissAfterCamera = false
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("换一张「\(dish.recipeName)」的图")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                Text("默认仅替换这一顿的菜图，拍过的新图会自动存进菜谱图库")
                    .font(AppFont.caption(12.5))
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.dividerLine, lineWidth: 0.7)
                    }
            }
            .buttonStyle(SoftPressStyle())
            .disabled(isProcessing)
            .accessibilityLabel("关闭")
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.light()
                showCamera = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("拍今天这盘")
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.actionInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(isProcessing)

            PhotosPicker(selection: $albumItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("从相册挑一张")
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.dividerLine, lineWidth: 0.8)
                }
            }
            .buttonStyle(SoftPressStyle())
            .disabled(isProcessing)
        }
    }

    @ViewBuilder
    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text("这道菜的图库")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)

                let choices = recipe?.photoChoices ?? []
                if !choices.isEmpty {
                    Text("\(choices.count) 张")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                        .monospacedDigit()
                }

                Spacer()

                if let defaultChoice = choices.first(where: \.isDefaultCover),
                   !isChoiceSelected(defaultChoice) {
                    Button {
                        Haptics.light()
                        Task { await applyChoice(defaultChoice) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .semibold))
                            Text("恢复默认")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.cardBackground, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.dividerLine, lineWidth: 0.7)
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                    .disabled(isProcessing)
                }
            }

            if isLoadingGallery && recipe == nil {
                HStack(spacing: 8) {
                    ProgressView().tint(Color.inkSecondary)
                    Text("正在读取菜谱图库")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
            } else {
                let choices = recipe?.photoChoices ?? []
                if choices.isEmpty {
                    Text("拍第一张后会自动保存在这里，以后可以随时换回来")
                        .font(AppFont.caption(12.5))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(choices) { choice in
                            galleryCard(choice)
                        }
                    }
                    Text("轻点立即换进当前画布；长按往期实拍可设为菜谱默认封面")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
    }

    private func galleryCard(_ choice: RecipePhotoChoice) -> some View {
        let selected = isChoiceSelected(choice)
        return Button {
            Haptics.light()
            Task { await applyChoice(choice) }
        } label: {
            Color.cardBackground
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncImageView(url: choice.image, name: dish.recipeName)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if choice.isDefaultCover {
                        Text("默认")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.actionInk.opacity(0.84), in: Capsule())
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let dateLabel = formattedShortDate(choice.createdAt) {
                        Text(dateLabel)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.black.opacity(0.56), in: Capsule())
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.actionInk)
                            .background(Color.white, in: Circle())
                            .padding(6)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            selected ? Color.actionInk : Color.dividerLine.opacity(0.8),
                            lineWidth: selected ? 2.5 : 0.7
                        )
                }
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isProcessing)
        .contextMenu {
            if !choice.isDefaultCover, let rid = dish.recipeId {
                Button("设为菜谱默认封面", systemImage: "star") {
                    Task { await setAsDefaultCover(recipeId: rid, choice: choice) }
                }
            }
        }
    }

    private func isChoiceSelected(_ choice: RecipePhotoChoice) -> Bool {
        if let current = dish.recipeImage, !current.isEmpty, current == choice.image {
            return true
        }
        if let currentCutout = dish.recipeCutoutImage, !currentCutout.isEmpty,
           let choiceCutout = choice.cutoutImage, choiceCutout == currentCutout {
            return true
        }
        return false
    }

    private func formattedShortDate(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let parts = raw.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[1]).\(parts[2])"
        }
        return raw
    }

    @MainActor
    private func loadRecipeGallery() async {
        guard let rid = dish.recipeId else { return }
        isLoadingGallery = true
        defer { isLoadingGallery = false }
        if let detail = try? await RecipeService.shared.detail(id: rid) {
            recipe = detail
        }
    }

    @MainActor
    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        guard !isProcessing else { return }
        albumItem = nil
        isProcessing = true
        processingText = "正在生成画布贴图"
        defer { isProcessing = false }

        do {
            guard let rawData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: rawData),
                  let jpeg = compressedJPEG(from: image) else {
                errorMessage = "无法读取选中的照片，请重试"
                return
            }
            let cutoutPNG = try? await ImageCutoutService.shared.makePNG(from: image)
            try await uploadAndApply(originalJPEG: jpeg, cutoutPNG: cutoutPNG, dismissImmediately: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleCapturedPhoto(_ photo: CameraPhoto) async throws {
        guard !isProcessing else { return }
        guard let jpeg = compressedJPEG(from: photo.image) else {
            throw CocoaError(.fileWriteUnknown)
        }
        isProcessing = true
        processingText = "正在保存今天这盘"
        defer { isProcessing = false }
        try await uploadAndApply(originalJPEG: jpeg, cutoutPNG: photo.cutoutData, dismissImmediately: false)
        shouldDismissAfterCamera = true
    }

    @MainActor
    private func uploadAndApply(originalJPEG: Data, cutoutPNG: Data?, dismissImmediately: Bool) async throws {
        processingText = "正在上传照片"
        let uploadedOrig = try await UploadService.shared.uploadImage(
            originalJPEG,
            filename: "dish_today.jpg",
            mime: "image/jpeg"
        )

        var cutoutPath: String?
        if let cutoutPNG {
            processingText = "正在保存透明贴图"
            if let uploadedCutout = try? await UploadService.shared.uploadImage(
                cutoutPNG,
                filename: "dish_today_cutout.png",
                mime: "image/png"
            ) {
                cutoutPath = uploadedCutout.path
            }
        }

        let updated = try await MealService.shared.updateDishImage(
            mealId: mealId,
            dishId: dish.id,
            DishImageUpdateInput(
                image: uploadedOrig.path,
                cutoutImage: cutoutPath,
                saveToGallery: true,
                setAsCover: false
            )
        )
        let isCover = recipe?.coverImage == uploadedOrig.path
        onApplied(DishPhotoApplyResult(
            updatedDish: updated,
            newlyCaptured: true,
            isAlreadyCover: isCover
        ))
        if dismissImmediately {
            dismiss()
        }
    }

    @MainActor
    private func applyChoice(_ choice: RecipePhotoChoice) async {
        guard !isProcessing else { return }
        isProcessing = true
        processingText = "正在更新菜图"
        defer { isProcessing = false }
        do {
            let updated = try await MealService.shared.updateDishImage(
                mealId: mealId,
                dishId: dish.id,
                DishImageUpdateInput(
                    image: choice.image,
                    cutoutImage: choice.cutoutImage,
                    saveToGallery: false,
                    setAsCover: false
                )
            )
            onApplied(DishPhotoApplyResult(
                updatedDish: updated,
                newlyCaptured: false,
                isAlreadyCover: choice.isDefaultCover
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func setAsDefaultCover(recipeId: UInt, choice: RecipePhotoChoice) async {
        guard !isProcessing else { return }
        isProcessing = true
        processingText = "正在设为默认封面"
        defer { isProcessing = false }
        do {
            let updatedRecipe = try await RecipeService.shared.setCover(
                id: recipeId,
                image: choice.image,
                cutoutImage: choice.cutoutImage
            )
            recipe = updatedRecipe
            tipMessage = "已设为「\(dish.recipeName)」默认封面"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func compressedJPEG(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 1600
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1.0, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.85) ?? image.jpegData(compressionQuality: 0.85)
    }
}
