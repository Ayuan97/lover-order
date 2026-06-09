import SwiftUI

// 编辑昵称 + 头像
struct EditProfileSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var avatar: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

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
                PrimaryButton(title: isSaving ? "保存中" : "保存", isLoading: isSaving) {
                    Task { await save() }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.appBackground)
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消").foregroundStyle(Color.inkSecondary)
                    }
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
            PhotoPickerField(imageURL: $avatar, label: "选张自己喜欢的图", height: 160)
        }
    }

    private var nicknameCard: some View {
        SectionCard {
            FieldLabel("昵称", required: true)
            TextField("想被怎么称呼", text: $nickname)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private func save() async {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "请填一个昵称"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let user = try await AuthService.shared.updateProfile(
                UpdateProfileRequest(nickname: trimmed, avatar: avatar)
            )
            appState.currentUser = user
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
