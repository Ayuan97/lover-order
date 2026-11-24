import SwiftUI

// 菜谱分类管理 列表 + 增删改（菜谱页与「我的」共用）
struct CategoryManagementView: View {
    var initialEditingCategory: RecipeCategory? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var categories: [RecipeCategory] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var loadID = 0

    @State private var newName: String = ""
    @State private var newIcon: String = ""

    @State private var editingId: UInt?
    @State private var editingName: String = ""
    @State private var editingIcon: String = ""
    @State private var pendingDeleteCategory: RecipeCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    addCard
                    listCard
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
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成").foregroundStyle(Color.inkPrimary)
                    }
                }
            }
            .task {
                if let target = initialEditingCategory {
                    startEdit(target)
                }
                await load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoriesChanged)) { _ in
                Task { await load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await load() }
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: Binding(
                    get: { pendingDeleteCategory != nil },
                    set: { if !$0 { pendingDeleteCategory = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除分类", role: .destructive) {
                    if let target = pendingDeleteCategory {
                        pendingDeleteCategory = nil
                        Task { await deleteCategory(target) }
                    }
                }
                Button("取消", role: .cancel) {
                    pendingDeleteCategory = nil
                }
            } message: {
                Text(deleteDialogMessage)
            }
        }
    }

    private var deleteDialogTitle: String {
        guard let c = pendingDeleteCategory else { return "删除分类？" }
        return "删除分类「\(c.name)」？"
    }

    private var deleteDialogMessage: String {
        guard let c = pendingDeleteCategory else { return "" }
        let count = c.recipeCount ?? 0
        if count > 0 {
            return "该分类下的 \(count) 道菜谱不会被删除，将自动归为「未分类」。"
        }
        return "删除后该分类将从菜谱筛选栏移除，不会影响已有菜谱。"
    }

    private var addCard: some View {
        SectionCard {
            FieldLabel("新建一个分类")
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("图标").font(AppFont.caption(12)).foregroundStyle(Color.inkMuted)
                    TextField("🍲", text: $newIcon)
                        .multilineTextAlignment(.center)
                        .frame(width: 52, height: 44)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("分类图标")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("分类名").font(AppFont.caption(12)).foregroundStyle(Color.inkMuted)
                    TextField("如：家常菜", text: $newName)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("分类名称")
                }
                Button { Task { await addCategory() } } label: {
                    ProductIcon(kind: .add)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.actionInk, in: Circle())
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                .accessibilityLabel("添加分类")
            }
        }
    }

    @ViewBuilder
    private var listCard: some View {
        if isLoading && categories.isEmpty {
            ProgressView().tint(Color.brandGreen).padding(.top, 40)
        } else if categories.isEmpty {
            Text("还没有分类")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxl)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        } else {
            VStack(spacing: AppSpacing.sm) {
                ForEach(categories) { c in
                    row(c)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ c: RecipeCategory) -> some View {
        let isEditing = editingId == c.id
        HStack(spacing: AppSpacing.md) {
            if isEditing {
                TextField("图标", text: $editingIcon)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(AppSpacing.sm)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                TextField("分类名", text: $editingName)
                    .padding(AppSpacing.sm)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                Button {
                    Task { await saveEdit(c) }
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandGreen)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("保存修改")
                Button {
                    cancelEdit()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("取消编辑")
            } else {
                Text(c.icon?.isEmpty == false ? c.icon! : "🍽")
                    .font(.system(size: 20))
                    .frame(width: 38, height: 38)
                    .background(Color.appBackground, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name)
                        .font(AppFont.body(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("\(c.recipeCount ?? 0) 道菜")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Button {
                    startEdit(c)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("编辑分类\(c.name)")
                Button {
                    Haptics.light()
                    pendingDeleteCategory = c
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.errorInk.opacity(0.85))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("删除分类\(c.name)")
            }
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.6), lineWidth: 0.7)
        }
    }

    private func load() async {
        loadID += 1
        let requestID = loadID
        isLoading = true
        defer {
            if requestID == loadID { isLoading = false }
        }
        do {
            let latest = try await CategoryService.shared.list()
            guard requestID == loadID else { return }
            categories = latest
        } catch {
            guard requestID == loadID else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func addCategory() async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await CategoryService.shared.create(
                CategoryInput(name: trimmed, icon: newIcon.isEmpty ? nil : newIcon, color: nil, sortOrder: categories.count)
            )
            AppNotifications.categoriesChanged()
            newName = ""
            newIcon = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startEdit(_ c: RecipeCategory) {
        editingId = c.id
        editingName = c.name
        editingIcon = c.icon ?? ""
    }

    private func cancelEdit() {
        editingId = nil
        editingName = ""
        editingIcon = ""
    }

    private func saveEdit(_ c: RecipeCategory) async {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await CategoryService.shared.update(
                id: c.id,
                req: CategoryInput(name: trimmed, icon: editingIcon.isEmpty ? nil : editingIcon, color: c.color, sortOrder: c.sortOrder)
            )
            AppNotifications.categoriesChanged()
            AppNotifications.recipesChanged()
            cancelEdit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCategory(_ c: RecipeCategory) async {
        do {
            try await CategoryService.shared.delete(id: c.id)
            AppNotifications.categoriesChanged()
            AppNotifications.recipesChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
