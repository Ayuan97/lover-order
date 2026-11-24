import SwiftUI

// 创建/编辑菜谱表单
struct RecipeEditView: View {
    enum Mode {
        case create
        case edit(Recipe)
    }

    let mode: Mode
    var onSaved: (Recipe) -> Void = { _ in }
    var onDeleted: (() -> Void)? = nil

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var coverImage: String = ""
    @State private var cutoutImage: String = ""
    @State private var existingPhotoChoices: [RecipePhotoChoice] = []
    @State private var expectedUpdatedAt: String = ""
    @State private var hasPrimed = false
    @State private var isProcessingPhoto = false
    @State private var cookingTime: String = ""
    @State private var servings: Int = 2
    @State private var difficulty: Difficulty = .easy
    @State private var tips: String = ""

    @State private var ingredients: [Ingredient] = []
    @State private var steps: [CookingStep] = []
    @State private var flavorTags: Set<String> = []
    @State private var moodTags: Set<Mood> = []
    @State private var sceneTags: Set<String> = []

    @State private var categories: [RecipeCategory] = []
    @State private var categoriesLoadID = 0
    @State private var categoryId: UInt?
    @State private var showNewCategory: Bool = false
    @State private var showCategoryManagement: Bool = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryIcon: String = ""
    @State private var isCreatingCategory: Bool = false

    @State private var isSaving: Bool = false
    @State private var hasEditConflict: Bool = false
    @State private var confirmDelete: Bool = false
    @State private var errorMessage: String?

    private var allowedSceneTags: Set<String> {
        Set(MealScene.productCases.map(\.rawValue))
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    nameSection
                    descSection
                    coverSection
                    basicsSection
                    categorySection
                    tagsSection
                    ingredientsSection
                    stepsSection
                    tipsSection
                    if isEdit {
                        deleteSection
                    }
                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(AppFont.caption())
                                .foregroundStyle(Color.errorInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if hasEditConflict {
                                Button {
                                    Task { await save(force: true) }
                                } label: {
                                    Text("仍按当前表单覆盖保存")
                                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .frame(height: 32)
                                        .background(Color.actionInk, in: Capsule())
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task {
                if !hasPrimed {
                    primeFromMode()
                    hasPrimed = true
                    await refreshEditableRecipeIfNeeded()
                }
                await loadCategories()
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoriesChanged)) { _ in
                Task { await loadCategories() }
            }
            .navigationTitle(isEdit ? "编辑菜谱" : "新建菜谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消").foregroundStyle(Color.inkSecondary)
                    }
                    .disabled(isSaving || isProcessingPhoto)
                }
            }
            .sheet(isPresented: $showCategoryManagement) {
                CategoryManagementView()
                    .preferredColorScheme(.light)
            }
            .confirmationDialog("删除这道菜谱？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除菜谱", role: .destructive) {
                    Task { await performDelete() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后这道菜不会再出现在菜谱列表里，但已经记下的历史不受影响。")
            }
        }
        .interactiveDismissDisabled(isSaving || isProcessingPhoto)
    }

    // 标题
    private var nameSection: some View {
        SectionCard {
            FieldLabel("菜名", required: true)
            TextField("比如 香煎三文鱼", text: $name)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var descSection: some View {
        SectionCard {
            FieldLabel("一句话描述", required: false)
            TextField("外焦里嫩 鱼肉鲜美多汁", text: $description, axis: .vertical)
                .lineLimit(2...3)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var coverSection: some View {
        SectionCard {
            FieldLabel("菜品主图与画布贴图", required: false)
            Text("主图支持裁剪旋转；抠图贴图支持涂抹擦除/恢复、重抠或单独上传替换。")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
            PhotoPickerField(
                imageURL: $coverImage,
                label: "选张这道菜的成品照",
                cutoutImageURL: $cutoutImage,
                isProcessing: $isProcessingPhoto,
                galleryChoices: existingPhotoChoices
            )
            .disabled(isSaving)
        }
    }

    private var basicsSection: some View {
        SectionCard {
            FieldLabel("基础信息", required: false)
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("用时（分钟）")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                    TextField("20", text: $cookingTime)
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.md)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("人份")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                    Stepper(value: $servings, in: 1...12) {
                        Text("\(servings) 人份")
                            .font(AppFont.body(14))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 6)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("难度")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
                Picker("", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { d in
                        Text(d.label).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var categorySection: some View {
        SectionCard {
            HStack(spacing: 14) {
                FieldLabel("分类", required: false)
                Spacer()
                Button {
                    showCategoryManagement = true
                } label: {
                    Label("管理", systemImage: "slider.horizontal.3")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkSecondary)
                }
                Button {
                    showNewCategory = true
                } label: {
                    Label("新建", systemImage: "plus.circle")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            FlowLayout(spacing: AppSpacing.sm) {
                chipButton(title: "未分类", isSelected: categoryId == nil) {
                    categoryId = nil
                }
                ForEach(categories) { c in
                    let title = (c.icon?.isEmpty == false ? "\(c.icon!) " : "") + c.name
                    chipButton(title: title, isSelected: categoryId == c.id) {
                        categoryId = c.id
                    }
                }
            }
            if showNewCategory {
                Divider().background(Color.dividerLine)
                HStack(spacing: AppSpacing.sm) {
                    TextField("图标", text: $newCategoryIcon)
                        .frame(width: 56)
                        .padding(AppSpacing.sm)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    TextField("分类名 比如 早餐", text: $newCategoryName)
                        .padding(AppSpacing.sm)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    Button {
                        Task { await addNewCategory() }
                    } label: {
                        if isCreatingCategory {
                            ProgressView().tint(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.actionInk)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.white)
                                .background(Color.actionInk)
                                .clipShape(Circle())
                        }
                    }
                    Button {
                        showNewCategory = false
                        newCategoryName = ""
                        newCategoryIcon = ""
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 36, height: 36)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        SectionCard {
            FieldLabel("适合心情 / 什么时候吃 / 风味", required: false)

            Text("适合心情")
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(Mood.allCases) { m in
                    chipButton(title: m.label, isSelected: moodTags.contains(m)) {
                        toggleSet(&moodTags, value: m)
                    }
                }
            }

            Text("什么时候吃")
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
                .padding(.top, AppSpacing.xs)
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(MealScene.productCases, id: \.self) { s in
                    chipButton(title: s.label, isSelected: sceneTags.contains(s.rawValue)) {
                        toggleSet(&sceneTags, value: s.rawValue)
                    }
                }
            }

            Text("风味")
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
                .padding(.top, AppSpacing.xs)
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(FlavorPresets.all, id: \.self) { f in
                    chipButton(title: f, isSelected: flavorTags.contains(f)) {
                        if flavorTags.contains(f) {
                            flavorTags.remove(f)
                        } else {
                            flavorTags.insert(f)
                        }
                    }
                }
            }
        }
    }

    private var ingredientsSection: some View {
        SectionCard {
            HStack {
                FieldLabel("准备食材", required: false)
                Spacer()
                Button {
                    ingredients.append(Ingredient(name: "", amount: ""))
                } label: {
                    Label("加一条", systemImage: "plus.circle")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            if ingredients.isEmpty {
                Text("还没加食材")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach($ingredients) { $ing in
                    HStack(spacing: AppSpacing.sm) {
                        TextField("食材名 比如 三文鱼", text: $ing.name)
                            .padding(AppSpacing.sm)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                        TextField("量 比如 200g", text: $ing.amount)
                            .padding(AppSpacing.sm)
                            .frame(width: 100)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                        Button {
                            ingredients.removeAll { $0.id == ing.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
        }
    }

    private var stepsSection: some View {
        SectionCard {
            HStack {
                FieldLabel("做法步骤", required: false)
                Spacer()
                Button {
                    steps.append(CookingStep(index: steps.count + 1, text: ""))
                } label: {
                    Label("加一步", systemImage: "plus.circle")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            if steps.isEmpty {
                Text("还没补充步骤")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach($steps) { $step in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Text("\(step.index)")
                                .font(AppFont.headline(14))
                                .frame(width: 26, height: 26)
                                .foregroundStyle(.white)
                                .background(Color.actionInk)
                                .clipShape(Circle())
                            TextField("这一步要做啥", text: $step.text, axis: .vertical)
                                .lineLimit(1...3)
                                .padding(AppSpacing.sm)
                                .background(Color.appBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                            Button {
                                removeStep(step)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                        Text("步骤 \(step.index) 的照片")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.inkSecondary)
                        PhotoPickerField(
                            imageURL: Binding(
                                get: { step.image ?? "" },
                                set: { step.image = $0.isEmpty ? nil : $0 }
                            ),
                            label: "添加这一步的图片",
                            height: 104
                        )
                    }
                }
            }
        }
    }

    private var tipsSection: some View {
        SectionCard {
            FieldLabel("小贴士", required: false)
            TextField("可填可不填", text: $tips, axis: .vertical)
                .lineLimit(2...4)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var bottomBar: some View {
        PrimaryButton(title: isEdit ? "保存修改" : "创建菜谱", isLoading: isSaving) {
            Task { await save() }
        }
        .disabled(isProcessingPhoto)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                .background(isSelected ? obsidian : Color.appBackground, in: Capsule())
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(Color.dividerLine.opacity(0.8), lineWidth: 0.7)
                    }
                }
        }
        .buttonStyle(SoftPressStyle())
    }

    private func toggleSet<T: Hashable>(_ set: inout Set<T>, value: T) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func removeStep(_ step: CookingStep) {
        steps.removeAll { $0.id == step.id }
        for i in steps.indices {
            steps[i].index = i + 1
        }
    }

    private func loadCategories() async {
        categoriesLoadID += 1
        let loadID = categoriesLoadID
        do {
            let latest = try await CategoryService.shared.list()
            guard loadID == categoriesLoadID else { return }
            categories = latest
            if let categoryId, !categories.contains(where: { $0.id == categoryId }) {
                self.categoryId = nil
            }
        } catch {}
    }

    private func addNewCategory() async {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return }
        isCreatingCategory = true
        defer { isCreatingCategory = false }
        do {
            let created = try await CategoryService.shared.create(
                CategoryInput(name: name, icon: newCategoryIcon.isEmpty ? nil : newCategoryIcon, color: nil, sortOrder: categories.count)
            )
            categoriesLoadID += 1
            categoryId = created.id
            AppNotifications.categoriesChanged()
            newCategoryName = ""
            newCategoryIcon = ""
            showNewCategory = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var deleteSection: some View {
        Button {
            Haptics.light()
            confirmDelete = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 13.5, weight: .semibold))
                Text("删除这道菜谱")
                    .font(AppFont.body(14))
            }
            .foregroundStyle(Color.errorInk)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.errorInk.opacity(0.22), lineWidth: 0.8)
            }
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isSaving || isProcessingPhoto)
    }

    private func primeFromMode() {
        guard case let .edit(r) = mode else { return }
        applyRecipeToState(r)
    }

    private func applyRecipeToState(_ r: Recipe) {
        name = r.name
        description = r.description ?? ""
        coverImage = r.coverImage ?? ""
        cutoutImage = r.cutoutImage ?? ""
        existingPhotoChoices = r.photoChoices
        expectedUpdatedAt = r.updatedAt
        cookingTime = r.cookingTime.map { String($0) } ?? ""
        servings = r.servings ?? 2
        difficulty = r.difficulty ?? .easy
        tips = r.tips ?? ""
        ingredients = r.ingredients ?? []
        steps = r.steps ?? []
        flavorTags = Set(r.tags ?? [])
        moodTags = Set(r.moodTags ?? [])
        sceneTags = Set((r.sceneTags ?? []).filter { allowedSceneTags.contains($0) })
        categoryId = r.categoryId
    }

    private func refreshEditableRecipeIfNeeded() async {
        guard case let .edit(r) = mode else { return }
        if let latest = try? await RecipeService.shared.detail(id: r.id) {
            if latest.updatedAt != r.updatedAt {
                if !isFormModified(from: r) {
                    applyRecipeToState(latest)
                }
            } else {
                expectedUpdatedAt = latest.updatedAt
                existingPhotoChoices = latest.photoChoices
            }
        }
    }

    private func isFormModified(from r: Recipe) -> Bool {
        name != r.name
            || description != (r.description ?? "")
            || coverImage != (r.coverImage ?? "")
            || cutoutImage != (r.cutoutImage ?? "")
            || categoryId != r.categoryId
    }

    private func performDelete() async {
        guard case let .edit(original) = mode, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await RecipeService.shared.delete(id: original.id)
            AppNotifications.recipesChanged()
            AppNotifications.categoriesChanged()
            onDeleted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(force: Bool = false) async {
        guard !isSaving, !isProcessingPhoto else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "请先填写菜名"
            return
        }
        isSaving = true
        hasEditConflict = false
        defer { isSaving = false }

        var input = RecipeInput(name: trimmedName)
        input.description = description.isEmpty ? nil : description
        input.coverImage = coverImage.isEmpty ? nil : coverImage
        input.cutoutImage = cutoutImage
        input.categoryId = categoryId
        input.cookingTime = Int(cookingTime)
        input.difficulty = difficulty
        input.servings = servings
        input.tips = tips.isEmpty ? nil : tips
        input.tags = flavorTags.isEmpty ? [] : Array(flavorTags)
        input.moodTags = moodTags.isEmpty ? [] : Array(moodTags)
        let validSceneTags = sceneTags.filter { allowedSceneTags.contains($0) }
        input.sceneTags = validSceneTags.isEmpty ? [] : Array(validSceneTags)
        input.ingredients = ingredients.filter { !$0.name.isEmpty }
        input.steps = steps.filter { !$0.text.isEmpty }

        do {
            let saved: Recipe
            switch mode {
            case .create:
                saved = try await RecipeService.shared.create(input)
            case .edit(let original):
                if !expectedUpdatedAt.isEmpty {
                    input.expectedUpdatedAt = expectedUpdatedAt
                }
                if force {
                    input.force = true
                }
                saved = try await RecipeService.shared.update(id: original.id, req: input)
            }
            AppNotifications.recipesChanged()
            AppNotifications.categoriesChanged()
            AppNotifications.mealChanged()
            onSaved(saved)
            dismiss()
        } catch {
            if let apiErr = error as? APIError, case .server(409, _) = apiErr {
                hasEditConflict = true
            }
            errorMessage = error.localizedDescription
        }
    }
}

// 字段标签 通用
struct FieldLabel: View {
    let title: String
    let required: Bool

    init(_ title: String, required: Bool = false) {
        self.title = title
        self.required = required
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            if required {
                Text("*")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.errorInk)
            }
            Spacer()
        }
    }
}

// 风味预设
enum FlavorPresets {
    static let all = ["麻辣", "酸辣", "清淡", "咸鲜", "甜口", "下饭", "汤水", "凉拌", "蒸煮", "煎炸", "烤", "炖"]
}
