import SwiftUI

// 购物清单 按一顿聚合食材 支持勾选
struct ShoppingListView: View {
    let mealId: UInt
    var title: String = "购物清单"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var list: ShoppingList?
    @State private var checkedNames: Set<String> = []
    @State private var checkSyncVersion: Int = 0
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var tipMessage: String?

    private var checkedSet: Set<String> {
        checkedNames
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    if let list, !list.items.isEmpty {
                        contentCard(list)
                    } else if isLoading {
                        ProgressView().tint(Color.brandGreen).padding(.top, 60)
                    } else {
                        emptyHint
                    }
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if let list, !list.items.isEmpty {
                    bottomBar(list)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成").foregroundStyle(Color.inkPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        clearChecked()
                    } label: {
                        Text("重置")
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .task {
                await load()
            }
            .refreshable {
                await load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .shoppingChanged)) { _ in
                Task { await load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await load() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await load() }
            }
            .toast($errorMessage)
            .tipToast($tipMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("要买的食材")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.inkPrimary)
                Text("买到了就点一下")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
        }
    }

    private func contentCard(_ list: ShoppingList) -> some View {
        let checked = checkedSet
        let total = list.items.count
        let done = list.items.filter { checked.contains(key(for: $0)) }.count
        let ratio = total == 0 ? 0.0 : Double(done) / Double(total)
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(done) / \(total) 买好了")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkMuted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appBackground)
                            .frame(height: 6)
                        Capsule()
                            .fill(obsidian)
                            .frame(width: max(0, geo.size.width * ratio), height: 6)
                    }
                }
                .frame(height: 6)
                .animation(.spring(response: 0.30, dampingFraction: 0.85), value: done)
            }

            Divider().background(Color.dividerLine.opacity(0.6))

            ForEach(Array(list.items.enumerated()), id: \.element.id) { idx, item in
                row(item, isChecked: checked.contains(key(for: item)))
                if idx < list.items.count - 1 {
                    Divider().background(Color.dividerLine.opacity(0.5))
                }
            }
        }
    }

    private func row(_ item: ShoppingItem, isChecked: Bool) -> some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return Button {
            Haptics.light()
            toggle(item)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(isChecked ? obsidian : Color.inkMuted)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(AppFont.body(15))
                            .foregroundStyle(isChecked ? Color.inkMuted : Color.inkPrimary)
                            .strikethrough(isChecked, color: Color.inkMuted)
                        Spacer()
                        if let amounts = item.amounts, !amounts.isEmpty {
                            Text(amounts.joined(separator: " + "))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    if let from = item.from, !from.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(from, id: \.self) { dishName in
                                Text(dishName)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.inkMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.appBackground, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.6)
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bottomBar(_ list: ShoppingList) -> some View {
        PrimaryButton(title: "复制清单发给 Ta", icon: "doc.on.doc") {
            let lines = list.items.map { item -> String in
                let box = checkedSet.contains(key(for: item)) ? "☑" : "☐"
                let amt = (item.amounts ?? []).joined(separator: " + ")
                return amt.isEmpty ? "\(box) \(item.name)" : "\(box) \(item.name)  \(amt)"
            }
            let text = (["🛒 买菜清单（共 \(list.items.count) 项）"] + lines).joined(separator: "\n")
            UIPasteboard.general.string = text
            Haptics.success()
            tipMessage = "清单已复制，可直接发给 Ta"
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private var emptyHint: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "cart")
                .font(.system(size: 32))
                .foregroundStyle(Color.inkMuted)
            Text("没什么要买的")
                .font(AppFont.headline(16))
                .foregroundStyle(Color.inkPrimary)
            Text("只有写了食材的菜才会出现")
                .font(AppFont.body(13))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Text("去菜单里给菜补上食材就行")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("好 我去补")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 12)
                    .background(Color.brandGreen.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxxl)
        .padding(.horizontal, AppSpacing.md)
    }

    private func key(for item: ShoppingItem) -> String {
        item.name
    }

    private func toggle(_ item: ShoppingItem) {
        let name = item.name
        if checkedNames.contains(name) {
            checkedNames.remove(name)
        } else {
            checkedNames.insert(name)
        }
        persistCheckedState()
    }

    private func clearChecked() {
        guard !checkedNames.isEmpty else { return }
        checkedNames.removeAll()
        persistCheckedState()
    }

    private func persistCheckedState() {
        checkSyncVersion += 1
        let version = checkSyncVersion
        let payload = checkedNames.sorted()
        Task {
            do {
                let serverChecked = try await MealService.shared.updateShoppingChecked(
                    mealId: mealId,
                    checkedItems: payload
                )
                guard version == checkSyncVersion else { return }
                checkedNames = Set(serverChecked)
            } catch {
                guard version == checkSyncVersion else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let versionBeforeFetch = checkSyncVersion
        do {
            let loaded = try await MealService.shared.shoppingList(mealId: mealId)
            list = loaded
            if versionBeforeFetch == checkSyncVersion {
                checkedNames = Set(loaded.checkedItems ?? [])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
