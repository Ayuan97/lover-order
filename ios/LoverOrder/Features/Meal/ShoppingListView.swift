import SwiftUI

// 购物清单 按一顿聚合食材 支持勾选
struct ShoppingListView: View {
    let mealId: UInt
    var title: String = "购物清单"

    @Environment(\.dismiss) private var dismiss
    @AppStorage("shopping.checked") private var checkedRaw: String = ""

    @State private var list: ShoppingList?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private var checkedSet: Set<String> {
        get {
            Set(checkedRaw.split(separator: "|").map(String.init))
        }
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成").foregroundStyle(Color.brandGreen)
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
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("买买买")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.inkPrimary)
                Text("点一下完成 划掉的会暗一点")
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
        return SectionCard {
            HStack {
                Text("\(done) / \(total) 已搞定")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                Spacer()
                ProgressView(value: total == 0 ? 0 : Double(done) / Double(total))
                    .tint(Color.brandGreen)
                    .frame(width: 100)
            }
            ForEach(list.items) { item in
                row(item, isChecked: checked.contains(key(for: item)))
            }
        }
    }

    private func row(_ item: ShoppingItem, isChecked: Bool) -> some View {
        Button {
            toggle(item)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isChecked ? Color.brandGreen : Color.inkMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppFont.body(15))
                        .foregroundStyle(isChecked ? Color.inkMuted : Color.inkPrimary)
                        .strikethrough(isChecked, color: Color.inkMuted)
                    if let amounts = item.amounts, !amounts.isEmpty {
                        Text(amounts.joined(separator: " + "))
                            .font(AppFont.caption())
                            .foregroundStyle(Color.inkMuted)
                    }
                    if let from = item.from, !from.isEmpty {
                        Text("用于 " + from.joined(separator: " / "))
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var emptyHint: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "cart")
                .font(.system(size: 32))
                .foregroundStyle(Color.inkMuted)
            Text("这一顿的菜还没补食材")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            Text("在菜谱里加上食材清单 这里就能用了")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxxl)
    }

    private func key(for item: ShoppingItem) -> String {
        "\(mealId):\(item.name)"
    }

    private func toggle(_ item: ShoppingItem) {
        var set = checkedSet
        let k = key(for: item)
        if set.contains(k) {
            set.remove(k)
        } else {
            set.insert(k)
        }
        checkedRaw = set.joined(separator: "|")
    }

    private func clearChecked() {
        var set = checkedSet
        let prefix = "\(mealId):"
        set = set.filter { !$0.hasPrefix(prefix) }
        checkedRaw = set.joined(separator: "|")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            list = try await MealService.shared.shoppingList(mealId: mealId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
