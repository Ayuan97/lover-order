import PhotosUI
import SwiftUI
import UIKit

// 编辑昵称 + 圆形头像选择与圆形裁剪
struct EditProfileSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private enum ActiveCover: Identifiable {
        case camera
        case crop(UUID, UIImage)

        var id: String {
            switch self {
            case .camera: return "camera"
            case .crop(let uid, _): return "crop-\(uid.uuidString)"
            }
        }
    }

    @State private var nickname: String = ""
    @State private var avatar: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var activeCover: ActiveCover?
    @State private var pendingCameraImage: UIImage?
    @State private var isUploadingAvatar: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private var previewUser: AppUser {
        let base = appState.currentUser
        return AppUser(
            id: base?.id ?? 0,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (base?.displayName ?? "我")
                : nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            avatar: avatar.isEmpty ? nil : avatar,
            email: base?.email,
            gender: base?.gender,
            householdId: base?.householdId,
            deviceId: base?.deviceId,
            hasPassword: base?.hasPassword
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    avatarCard
                    nicknameCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.errorInk)
                    }
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: isUploadingAvatar ? "头像处理中" : (isSaving ? "保存中" : "保存"),
                    isLoading: isSaving
                ) {
                    Task { await save() }
                }
                .disabled(isUploadingAvatar || isSaving)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.appBackground)
                .overlay(alignment: .top) {
                    Divider().overlay(Color.dividerLine.opacity(0.6))
                }
            }
            .interactiveDismissDisabled(isSaving || isUploadingAvatar)
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消").foregroundStyle(Color.inkSecondary)
                    }
                    .disabled(isSaving || isUploadingAvatar)
                }
            }
            .task {
                nickname = appState.currentUser?.nickname ?? ""
                avatar = appState.currentUser?.avatar ?? ""
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadPickerItemForCircularCrop(item) }
            }
            .fullScreenCover(item: $activeCover, onDismiss: {
                if let captured = pendingCameraImage {
                    pendingCameraImage = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        activeCover = .crop(UUID(), captured)
                    }
                }
            }) { cover in
                switch cover {
                case .camera:
                    CameraCaptureView(mode: .photo) { photo in
                        await MainActor.run {
                            pendingCameraImage = photo.image
                        }
                    }
                    .ignoresSafeArea()

                case .crop(_, let sourceImage):
                    CircularAvatarCropSheet(initialImage: sourceImage) { cropped in
                        Task { await uploadCroppedAvatar(cropped) }
                    }
                }
            }
        }
    }

    private var avatarCard: some View {
        SectionCard {
            FieldLabel("头像", required: false)

            VStack(spacing: 14) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            AvatarView(user: previewUser, size: 108, ring: false)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 3)
                                }
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.dividerLine.opacity(0.65), lineWidth: 0.8)
                                }
                                .shadow(color: Color.black.opacity(0.10), radius: 12, y: 4)

                            if isUploadingAvatar {
                                Circle()
                                    .fill(Color.black.opacity(0.34))
                                    .frame(width: 108, height: 108)
                                    .overlay {
                                        ProgressView().tint(.white)
                                    }
                            }
                        }

                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.actionInk, in: Circle())
                            .overlay {
                                Circle().strokeBorder(Color.cardBackground, lineWidth: 2.2)
                            }
                            .shadow(color: Color.black.opacity(0.14), radius: 5, y: 2)
                            .offset(x: 2, y: 2)
                    }
                    .padding(.top, 4)
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isUploadingAvatar || isSaving)
                .accessibilityLabel("从相册选择并圆形裁剪头像")

                Text("轻点圆形头像选图，支持拖动与缩放调整圆形范围")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        avatarActionPill(
                            title: avatar.isEmpty ? "相册选图" : "换一张",
                            icon: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(SoftPressStyle())

                    Button {
                        Haptics.light()
                        activeCover = .camera
                    } label: {
                        avatarActionPill(title: "拍照", icon: "camera")
                    }
                    .buttonStyle(SoftPressStyle())

                    if !avatar.isEmpty {
                        Button {
                            Haptics.light()
                            Task { await recropExistingAvatar() }
                        } label: {
                            avatarActionPill(title: "裁剪", icon: "crop")
                        }
                        .buttonStyle(SoftPressStyle())

                        Button {
                            Haptics.light()
                            avatar = ""
                        } label: {
                            avatarActionPill(title: "清除", icon: "trash", isDestructive: true)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .disabled(isUploadingAvatar || isSaving)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        }
    }

    private func avatarActionPill(title: String, icon: String, isDestructive: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
            Text(title)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(isDestructive ? Color.errorInk : Color.inkPrimary)
        .padding(.horizontal, 11)
        .frame(height: 33)
        .background(Color.appBackground, in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                isDestructive ? Color.errorInk.opacity(0.24) : Color.dividerLine.opacity(0.8),
                lineWidth: 0.7
            )
        }
    }

    private var nicknameCard: some View {
        SectionCard {
            FieldLabel("昵称", required: true)
            TextField("想被怎么称呼", text: $nickname)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                }
        }
    }

    @MainActor
    private func loadPickerItemForCircularCrop(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取所选图片，请换一张试试"
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
            activeCover = .crop(UUID(), image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func recropExistingAvatar() async {
        guard !avatar.isEmpty, !isUploadingAvatar else { return }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        errorMessage = nil
        guard let img = await RecipeImageEditHelpers.loadUIImage(from: avatar) else {
            errorMessage = "无法读取当前头像，请重新选择照片"
            return
        }
        activeCover = .crop(UUID(), img)
    }

    @MainActor
    private func uploadCroppedAvatar(_ cropped: UIImage) async {
        guard let jpeg = cropped.jpegData(compressionQuality: 0.88) else {
            errorMessage = "头像编码失败，请重试"
            return
        }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        errorMessage = nil
        do {
            let uploaded = try await UploadService.shared.uploadImage(
                jpeg,
                filename: "avatar.jpg",
                mime: "image/jpeg"
            )
            avatar = uploaded.path
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard !isUploadingAvatar else { return }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "请填一个昵称"
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let user = try await AuthService.shared.updateProfile(
                UpdateProfileRequest(nickname: trimmed, avatar: avatar)
            )
            appState.currentUser = user
            if user.deviceId == DeviceIdentity.shared.deviceID {
                UserDefaults.standard.set(user.nickname, forKey: "auth.last.nickname")
            }
            await appState.refreshHousehold()
            AppNotifications.householdChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 圆形视窗头像裁剪器（单指平移 + 双指/滑杆缩放 + 旋转翻转）

private struct CircularAvatarCropSheet: View {
    let initialImage: UIImage
    let onConfirm: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var workingImage: UIImage
    @State private var zoom: CGFloat = 1.0
    @State private var gestureZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragStartOffset: CGSize?
    @State private var isInteracting: Bool = false
    @State private var latestDiameter: CGFloat = 280

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 4.0

    init(initialImage: UIImage, onConfirm: @escaping (UIImage) -> Void) {
        self.initialImage = initialImage
        self.onConfirm = onConfirm
        let normalized = RecipeImageEditHelpers.normalizedUpImage(initialImage, maxSide: 1800, opaque: true)
        _workingImage = State(initialValue: normalized)
    }

    private var effectiveZoom: CGFloat {
        min(max(zoom * gestureZoom, minZoom), maxZoom)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            cropStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomPanel
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            .font(AppFont.body(15))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minHeight: 44)

            Spacer()

            Text("裁剪圆形头像")
                .font(AppFont.headline(16))
                .foregroundStyle(.white)

            Spacer()

            Button("复原") {
                Haptics.light()
                workingImage = RecipeImageEditHelpers.normalizedUpImage(initialImage, maxSide: 1800, opaque: true)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    zoom = 1.0
                    gestureZoom = 1.0
                    offset = .zero
                }
            }
            .font(AppFont.body(14))
            .foregroundStyle(.white.opacity(0.82))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var cropStage: some View {
        GeometryReader { geo in
            let diameter = max(180, min(min(geo.size.width - 44, geo.size.height - 32), 320))
            let center = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            let circleBox = CGRect(
                x: center.x - diameter * 0.5,
                y: center.y - diameter * 0.5,
                width: diameter,
                height: diameter
            )
            let displayed = displayedSize(for: diameter, scale: effectiveZoom)
            let clamped = clampedOffset(offset, displayed: displayed, diameter: diameter)

            ZStack {
                Image(uiImage: workingImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: displayed.width, height: displayed.height)
                    .position(x: center.x + clamped.width, y: center.y + clamped.height)

                // 圆形视窗外的暗角遮罩
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addEllipse(in: circleBox)
                }
                .fill(Color.black.opacity(0.64), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                // 圆形白边与交互辅助十字三分线
                ZStack {
                    if isInteracting {
                        Path { path in
                            for i in 1...2 {
                                let x = circleBox.minX + diameter * CGFloat(i) / 3.0
                                path.move(to: CGPoint(x: x, y: circleBox.minY))
                                path.addLine(to: CGPoint(x: x, y: circleBox.maxY))
                                let y = circleBox.minY + diameter * CGFloat(i) / 3.0
                                path.move(to: CGPoint(x: circleBox.minX, y: y))
                                path.addLine(to: CGPoint(x: circleBox.maxX, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.32), lineWidth: 0.7)
                        .clipShape(Circle())
                        .frame(width: diameter, height: diameter)
                        .position(center)
                    }

                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1.8)
                        .frame(width: diameter, height: diameter)
                        .shadow(color: Color.black.opacity(0.35), radius: 6)
                        .position(center)
                }
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.16), value: isInteracting)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isInteracting = true
                                let start = dragStartOffset ?? clamped
                                if dragStartOffset == nil {
                                    dragStartOffset = clamped
                                }
                                let proposed = CGSize(
                                    width: start.width + value.translation.width,
                                    height: start.height + value.translation.height
                                )
                                offset = clampedOffset(proposed, displayed: displayed, diameter: diameter)
                            }
                            .onEnded { _ in
                                dragStartOffset = nil
                                isInteracting = false
                            }
                            .simultaneously(
                                with: MagnificationGesture()
                                    .onChanged { mag in
                                        isInteracting = true
                                        gestureZoom = mag
                                        let nextDisp = displayedSize(for: diameter, scale: effectiveZoom)
                                        offset = clampedOffset(offset, displayed: nextDisp, diameter: diameter)
                                    }
                                    .onEnded { _ in
                                        zoom = effectiveZoom
                                        gestureZoom = 1.0
                                        let nextDisp = displayedSize(for: diameter, scale: zoom)
                                        offset = clampedOffset(offset, displayed: nextDisp, diameter: diameter)
                                        isInteracting = false
                                    }
                            )
                    )
            }
            .clipped()
            .onAppear { latestDiameter = diameter }
            .onChange(of: diameter) { _, next in
                latestDiameter = next
                let disp = displayedSize(for: next, scale: effectiveZoom)
                offset = clampedOffset(offset, displayed: disp, diameter: next)
            }
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))

                Slider(
                    value: Binding(
                        get: { effectiveZoom },
                        set: { next in
                            zoom = next
                            gestureZoom = 1.0
                            let disp = displayedSize(for: latestDiameter, scale: next)
                            offset = clampedOffset(offset, displayed: disp, diameter: latestDiameter)
                        }
                    ),
                    in: minZoom...maxZoom
                )
                .tint(.white)

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                transformButton(icon: "rotate.left", label: "左转") {
                    workingImage = RecipeImageEditHelpers.rotate90(workingImage, clockwise: false, opaque: true)
                    offset = .zero
                }
                transformButton(icon: "rotate.right", label: "右转") {
                    workingImage = RecipeImageEditHelpers.rotate90(workingImage, clockwise: true, opaque: true)
                    offset = .zero
                }
                transformButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "翻转") {
                    workingImage = RecipeImageEditHelpers.flipHorizontal(workingImage, opaque: true)
                    offset = CGSize(width: -offset.width, height: offset.height)
                }
            }

            Button {
                Haptics.light()
                let result = renderSquareAvatar(diameter: latestDiameter, outputSide: 640)
                onConfirm(result)
                dismiss()
            } label: {
                Text("完成裁剪")
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.actionInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.top, 14)
        .background(Color.black.opacity(0.45))
    }

    private func transformButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(SoftPressStyle())
    }

    private func displayedSize(for diameter: CGFloat, scale: CGFloat) -> CGSize {
        let imgW = max(1, workingImage.size.width)
        let imgH = max(1, workingImage.size.height)
        let baseScale = max(diameter / imgW, diameter / imgH)
        return CGSize(
            width: imgW * baseScale * scale,
            height: imgH * baseScale * scale
        )
    }

    private func clampedOffset(_ proposed: CGSize, displayed: CGSize, diameter: CGFloat) -> CGSize {
        let maxX = max(0, (displayed.width - diameter) * 0.5)
        let maxY = max(0, (displayed.height - diameter) * 0.5)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func renderSquareAvatar(diameter: CGFloat, outputSide: CGFloat) -> UIImage {
        let safeDiameter = max(1, diameter)
        let disp = displayedSize(for: safeDiameter, scale: effectiveZoom)
        let clamped = clampedOffset(offset, displayed: disp, diameter: safeDiameter)
        let drawXInCircle = clamped.width + (safeDiameter - disp.width) * 0.5
        let drawYInCircle = clamped.height + (safeDiameter - disp.height) * 0.5
        let factor = outputSide / safeDiameter

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format).image { _ in
            workingImage.draw(
                in: CGRect(
                    x: drawXInCircle * factor,
                    y: drawYInCircle * factor,
                    width: disp.width * factor,
                    height: disp.height * factor
                )
            )
        }
    }
}
