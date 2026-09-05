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

    enum Mode: Hashable { case create, join }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            header

            Picker("", selection: $mode) {
                Text("建个家").tag(Mode.create)
                Text("进 Ta 的家").tag(Mode.join)
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
                    Text("不建家 只去朋友那儿蹭一顿")
                }
                .font(AppFont.caption(13))
                .foregroundStyle(Color.inkMuted)
            }

            // 卡住时能自救 也能换账号
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
                        Text("好像卡住了 再试一次")
                    }
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.brandGreen)
                }
                .disabled(isSyncing)

                Button {
                    Task { await appState.didLogout() }
                } label: {
                    Text("换个账号")
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
                handleScannedInvite(code)
            }
        }
        .fullScreenCover(isPresented: $showJoinDining) {
            DiningJoinView()
                .environmentObject(appState)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("先有个家")
                .font(AppFont.title(28))
                .foregroundStyle(Color.inkPrimary)
            Text("两个人的菜单 得放在同一个地方")
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
            Text("建好后把餐券给 Ta 就行")
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
                .background(Color.actionInk)
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
            Text("这是入伙餐券，要进家用上面；蹭饭要房间号")
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var confirmTitle: String {
        mode == .create ? "建好" : "进去"
    }

    private func submit() {
        errorMessage = nil
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                switch mode {
                case .create:
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else {
                        errorMessage = "先给家起个名字吧"
                        return
                    }
                    let household = try await HouseholdService.shared.create(
                        CreateHouseholdRequest(name: name)
                    )
                    // 立刻写 membership，关票才算进家会半状态卡死
                    appState.applyHouseholdMembership(household)
                    appState.pendingInviteTicket = household
                case .join:
                    let raw = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !raw.isEmpty else {
                        errorMessage = "把 Ta 的邀请码填进来再点"
                        return
                    }
                    // 手输：邀请码本体；若贴了深链只接受 home
                    let code: String
                    if let kind = LoverScanLink.parse(raw) {
                        switch kind {
                        case .home(let c): code = c
                        case .room:
                            errorMessage = "这是蹭饭房间号 进家要用餐券码"
                            return
                        }
                    } else {
                        code = raw
                    }
                    let household = try await HouseholdService.shared.join(code: code)
                    await finishMembership(household)
                }
            } catch {
                errorMessage = humanize(error)
            }
        }
    }

    // 扫码只认 lo://home/；裸串不当餐券（无兼容）
    private func handleScannedInvite(_ raw: String) {
        switch LoverScanLink.parse(raw) {
        case .home(let code):
            inviteCode = code
            submit()
        case .room:
            errorMessage = "扫到的是蹭饭房间号，不是入伙餐券——要进家用餐券；蹭饭点下面那行"
        case nil:
            errorMessage = "请扫餐券上的码（手输邀请码用上面输入框）"
        }
    }

    // 乐观写 householdId 再 refresh 失败也可进主页 并给出可见重试
    private func finishMembership(_ household: Household) async {
        appState.applyHouseholdMembership(household)
        let synced = await appState.refreshProfile()
        if !synced {
            errorMessage = "家有了 资料还没跟上 点下面再试一次"
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
            errorMessage = "网有点不稳，再点一次试试"
        } else if appState.currentUser?.hasHousehold != true && appState.household == nil {
            errorMessage = "还没进哪个家——上面建一个，或把 Ta 的码填进来"
        }
    }

    private func humanize(_ error: Error) -> String {
        let msg = error.localizedDescription
        if msg.contains("已加入") {
            return "你已经在一个家里了 点下面「再试一次」同步一下"
        }
        if msg.contains("参数有误") {
            return "填的有点不对 再看看"
        }
        if msg.contains("邀请码无效") || msg.contains("过期") || msg.contains("失效") {
            return "这个码进不去 是不是扫成房间号了？进家要用餐券上的码"
        }
        if msg.contains("网络") || (error as? APIError).map({
            if case .requestFailed = $0 { return true }
            return false
        }) == true {
            return "网有点不稳，再点一次试试"
        }
        return msg
    }
}
