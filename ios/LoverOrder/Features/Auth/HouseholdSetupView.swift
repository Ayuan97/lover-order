import SwiftUI

// 首次进入 没有家时引导：创建新家 或 用邀请码加入
struct HouseholdSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: Mode = .create
    @State private var newName: String = ""
    @State private var inviteCode: String = ""
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var showJoinDining = false
    // 建家成功先弹餐券 关闭后再写 membership 避免与 Root 切页抢跑
    @State private var pendingCreated: Household?
    @State private var showInviteAfterCreate = false

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
                    .foregroundStyle(Color.errorInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            PrimaryButton(title: confirmTitle, isLoading: isLoading, action: submit)
                .padding(.horizontal, AppSpacing.xl)

            // 来蹭饭的朋友不该被迫先建一个家 聚餐参与不要求有家
            Button {
                showJoinDining = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "qrcode.viewfinder")
                    Text("先不建家 · 去朋友家蹭一顿")
                }
                .font(AppFont.caption(13))
                .foregroundStyle(Color.inkMuted)
            }

            // 半状态：资料不同步时可见重试；也可退出换账号
            VStack(spacing: AppSpacing.sm) {
                Button {
                    Task { await resync() }
                } label: {
                    HStack(spacing: 5) {
                        if isSyncing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("重新同步家庭状态")
                    }
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.brandGreen)
                }
                .disabled(isSyncing)

                Button {
                    Task { await appState.didLogout() }
                } label: {
                    Text("退出登录")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.top, AppSpacing.xxl)
        .background(Color.appBackground.ignoresSafeArea())
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerScreen(hint: "对准对方餐券上的二维码", manualEntryTitle: "改为手输邀请码") { code in
                inviteCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                submit()
            }
        }
        .fullScreenCover(isPresented: $showJoinDining) {
            DiningJoinView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showInviteAfterCreate, onDismiss: {
            // 同步乐观写入 立刻让 Root 进主页 再后台刷新资料
            if let h = pendingCreated {
                pendingCreated = nil
                appState.applyHouseholdMembership(h)
                Task {
                    if await appState.refreshProfile() {
                        await appState.refreshHousehold()
                    }
                }
            }
        }) {
            if let h = pendingCreated {
                InviteTicketView(
                    household: h,
                    inviterName: appState.currentUser?.nickname ?? "我"
                )
            }
        }
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
            Button {
                showScanner = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "qrcode.viewfinder")
                    Text("扫一扫 · 对方的餐券")
                }
                .font(AppFont.headline(15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(Color.brandGreen)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
            Text("或手输邀请码")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
            TextField("对方分享的邀请码", text: $inviteCode)
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
                switch mode {
                case .create:
                    let household = try await HouseholdService.shared.create(
                        CreateHouseholdRequest(name: newName.trimmingCharacters(in: .whitespaces))
                    )
                    pendingCreated = household
                    showInviteAfterCreate = true
                case .join:
                    let household = try await HouseholdService.shared.join(
                        code: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    await finishMembership(household)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // 乐观写 householdId 再 refresh 失败也可进主页 并给出可见重试
    private func finishMembership(_ household: Household) async {
        appState.applyHouseholdMembership(household)
        let synced = await appState.refreshProfile()
        if !synced {
            errorMessage = "家已就绪，但资料同步失败，可点下方重新同步"
        } else {
            await appState.refreshHousehold()
        }
    }

    private func resync() async {
        isSyncing = true
        defer { isSyncing = false }
        errorMessage = nil
        let ok = await appState.resyncMembership()
        if !ok {
            errorMessage = "同步失败，请检查网络后重试"
        } else if appState.currentUser?.hasHousehold != true && appState.household == nil {
            errorMessage = "尚未加入任何家，请创建或输入邀请码"
        }
    }
}
