import SwiftUI

// 首次进入 没有家时引导：创建新家 或 用邀请码加入
struct HouseholdSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: Mode = .create
    @State private var newName: String = ""
    @State private var inviteCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode: Hashable { case create, join }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            header

            Picker("", selection: $mode) {
                Text("创建一个家").tag(Mode.create)
                Text("加入一个家").tag(Mode.join)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.xl)

            SectionCard {
                switch mode {
                case .create:
                    createSection
                case .join:
                    joinSection
                }
            }
            .padding(.horizontal, AppSpacing.xl)

            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.caption())
                    .foregroundStyle(.red)
            }

            Spacer()

            PrimaryButton(title: confirmTitle, isLoading: isLoading, action: submit)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.top, AppSpacing.xxl)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("先建一个家吧")
                .font(AppFont.title(28))
                .foregroundStyle(Color.inkPrimary)
            Text("有了家 才能一起决定每一顿吃什么")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("家的名字")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            TextField("如：我们的小食堂", text: $newName)
                .textInputAutocapitalization(.never)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            Text("创建后会得到一个邀请码 让 Ta 加入")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("邀请码")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            TextField("输入对方分享的 8 位邀请码", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var confirmTitle: String {
        mode == .create ? "建好这个家" : "加入"
    }

    private func submit() {
        errorMessage = nil
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let household: Household
                switch mode {
                case .create:
                    household = try await HouseholdService.shared.create(
                        CreateHouseholdRequest(name: newName.trimmingCharacters(in: .whitespaces))
                    )
                case .join:
                    household = try await HouseholdService.shared.join(
                        code: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                await appState.refreshProfile()
                appState.household = household
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
