import SwiftUI

// 外食没有走首页点菜流程时，直接把这一顿补进记录。
struct ManualHistoryEntryView: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scene: MealScene = .pair
    @State private var title = ""
    @State private var dishesText = ""
    @State private var note = ""
    @State private var comment = ""
    @State private var photoLinks: [String] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var dishNames: [String] {
        dishesText
            .split(whereSeparator: { $0 == "\n" || $0 == "，" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    scenePicker
                    inputCard
                    photosCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.errorInk)
                    }
                    Color.clear.frame(height: 48)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isSaving ? "正在保存" : "记下这顿", isLoading: isSaving) {
                    Task { await save() }
                }
                .disabled(isSaving)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
            }
            .navigationTitle("记一顿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    private var scenePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("和谁一起")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            Picker("和谁一起", selection: $scene) {
                Text("家人一起吃").tag(MealScene.pair)
                Text("朋友聚餐").tag(MealScene.family)
            }
            .pickerStyle(.segmented)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldLabel("标题")
            TextField("比如：周五晚饭、生日聚餐", text: $title)
                .font(AppFont.body(15))
                .padding(12)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            FieldLabel("吃了什么")
            TextField("一道菜一行，也可以用逗号分开", text: $dishesText, axis: .vertical)
                .lineLimit(3...6)
                .font(AppFont.body(15))
                .padding(12)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            FieldLabel("备注")
            TextField("店名或其他备注", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(AppFont.body(15))
                .padding(12)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            FieldLabel("留言")
            TextField("写点这顿饭的事", text: $comment, axis: .vertical)
                .lineLimit(2...4)
                .font(AppFont.body(15))
                .padding(12)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这顿饭的照片")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            MultiPhotoPicker(urls: $photoLinks, maxCount: 9)
        }
    }

    private func save() async {
        guard !dishNames.isEmpty else {
            errorMessage = "至少填一道菜"
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let created = try await MealService.shared.create(
                MealInput(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title,
                    scene: scene,
                    mood: nil,
                    plannedAt: nil,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                )
            )
            for name in dishNames {
                _ = try await MealService.shared.addDish(mealId: created.id, dish: DishInput(name: name))
            }
            _ = try await MealService.shared.confirm(id: created.id)
            _ = try await MealService.shared.complete(id: created.id)
            if !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photoLinks.isEmpty {
                _ = try await MealService.shared.review(
                    mealId: created.id,
                    ReviewInput(
                        rating: 5,
                        comment: comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment,
                        photos: photoLinks.isEmpty ? nil : photoLinks
                    )
                )
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
