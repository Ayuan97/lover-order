import SwiftUI

// 编辑昵称 + 头像
struct EditProfileSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var avatar: String = ""
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
                    title: isUploadingAvatar ? "头像上传中" : (isSaving ? "保存中" : "保存"),
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
        }
    }

    private var avatarCard: some View {
        SectionCard {
            FieldLabel("头像", required: false)
            HStack {
                Spacer()
                AvatarView(user: previewUser, size: 84, ring: true)
                    .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
                Spacer()
            }
            .padding(.bottom, AppSpacing.xs)

            PhotoPickerField(
                imageURL: $avatar,
                label: "点这里从相册选一张头像",
                height: 140,
                isProcessing: $isUploadingAvatar
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
