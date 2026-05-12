import SwiftUI

// 创建/编辑菜谱表单
struct RecipeEditView: View {
    enum Mode {
        case create
        case edit(Recipe)
    }

    let mode: Mode
    var onSaved: (Recipe) -> Void = { _ in }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var coverImage: String = ""
    @State private var cookingTime: String = ""
    @State private var servings: Int = 2
    @State private var difficulty: Difficulty = .easy
    @State private var tips: String = ""

    @State private var ingredients: [Ingredient] = []
    @State private var steps: [CookingStep] = []
    @State private var flavorTags: Set<String> = []
    @State private var moodTags: Set<Mood> = []
    @State private var sceneTags: Set<MealScene> = []

    @State private var categories: [RecipeCategory] = []
    @State private var categoryId: UInt?

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

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
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                await loadCategories()
                primeFromMode()
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
                }
            }
        }
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
            FieldLabel("封面图链接", required: false)
            TextField("https://...（可留空）", text: $coverImage)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            if !coverImage.isEmpty {
                AsyncImageView(url: coverImage, name: name)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
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

    @ViewBuilder
    private var categorySection: some View {
        if !categories.isEmpty {
            SectionCard {
                FieldLabel("分类", required: false)
                FlowLayout(spacing: AppSpacing.sm) {
                    chipButton(title: "未分类", isSelected: categoryId == nil) {
                        categoryId = nil
                    }
                    ForEach(categories) { c in
                        chipButton(title: c.name, isSelected: categoryId == c.id) {
                            categoryId = c.id
                        }
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        SectionCard {
            FieldLabel("适合心情 / 场景 / 风味", required: false)

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

            Text("适合场景")
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
                .padding(.top, AppSpacing.xs)
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(MealScene.allCases) { s in
                    chipButton(title: s.label, isSelected: sceneTags.contains(s)) {
                        toggleSet(&sceneTags, value: s)
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
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Text("\(step.index)")
                            .font(AppFont.headline(14))
                            .frame(width: 26, height: 26)
                            .foregroundStyle(.white)
                            .background(Color.brandGreen)
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
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(13))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                .background(isSelected ? Color.brandGreen : Color.appBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
        do {
            categories = try await CategoryService.shared.list()
        } catch {}
    }

    private func primeFromMode() {
        guard case let .edit(r) = mode else { return }
        name = r.name
        description = r.description ?? ""
        coverImage = r.coverImage ?? ""
        cookingTime = r.cookingTime.map { String($0) } ?? ""
        servings = r.servings ?? 2
        difficulty = r.difficulty ?? .easy
        tips = r.tips ?? ""
        ingredients = r.ingredients ?? []
        steps = r.steps ?? []
        flavorTags = Set(r.tags ?? [])
        moodTags = Set(r.moodTags ?? [])
        sceneTags = Set(r.sceneTags ?? [])
        categoryId = r.categoryId
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "请先填写菜名"
            return
        }
        isSaving = true
        defer { isSaving = false }

        var input = RecipeInput(name: trimmedName)
        input.description = description.isEmpty ? nil : description
        input.coverImage = coverImage.isEmpty ? nil : coverImage
        input.categoryId = categoryId
        input.cookingTime = Int(cookingTime)
        input.difficulty = difficulty
        input.servings = servings
        input.tips = tips.isEmpty ? nil : tips
        input.tags = flavorTags.isEmpty ? [] : Array(flavorTags)
        input.moodTags = moodTags.isEmpty ? [] : Array(moodTags)
        input.sceneTags = sceneTags.isEmpty ? [] : Array(sceneTags)
        input.ingredients = ingredients.filter { !$0.name.isEmpty }
        input.steps = steps.filter { !$0.text.isEmpty }

        do {
            let saved: Recipe
            switch mode {
            case .create:
                saved = try await RecipeService.shared.create(input)
            case .edit(let original):
                saved = try await RecipeService.shared.update(id: original.id, req: input)
            }
            onSaved(saved)
            dismiss()
        } catch {
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
                    .foregroundStyle(.red)
            }
            Spacer()
        }
    }
}

// 风味预设
enum FlavorPresets {
    static let all = ["麻辣", "酸辣", "清淡", "咸鲜", "甜口", "下饭", "汤水", "凉拌", "蒸煮", "煎炸", "烤", "炖"]
}
