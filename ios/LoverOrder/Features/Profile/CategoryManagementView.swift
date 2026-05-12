import SwiftUI

// 菜谱分类管理 列表 + 增删改
struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [RecipeCategory] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    @State private var newName: String = ""
    @State private var newIcon: String = ""

    @State private var editingId: UInt?
    @State private var editingName: String = ""
    @State private var editingIcon: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    addCard
                    listCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundStyle(.red)
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
                        Text("完成").foregroundStyle(Color.brandGreen)
                    }
                }
            }
            .task {
                await load()
            }
        }
    }

    private var addCard: some View {
        SectionCard {
            FieldLabel("新建一个分类")
            HStack(spacing: AppSpacing.sm) {
                TextField("图标 比如 🍲", text: $newIcon)
                    .frame(width: 60)
                    .padding(AppSpacing.sm)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                TextField("分类名 比如 家常菜", text: $newName)
                    .padding(AppSpacing.sm)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                Button {
                    Task { await addCategory() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
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
                        .frame(width: 32, height: 32)
                }
                Button {
                    cancelEdit()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 32, height: 32)
                }
            } else {
                Text(c.icon?.isEmpty == false ? c.icon! : "🍽")
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
                    .background(Color.brandGreen.opacity(0.1))
                    .clipShape(Circle())
                Text(c.name)
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button {
                    startEdit(c)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.inkSecondary)
                }
                Button {
                    Task { await deleteCategory(c) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            categories = try await CategoryService.shared.list()
        } catch {
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
            await load()
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
            cancelEdit()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCategory(_ c: RecipeCategory) async {
        do {
            try await CategoryService.shared.delete(id: c.id)
            AppNotifications.categoriesChanged()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
