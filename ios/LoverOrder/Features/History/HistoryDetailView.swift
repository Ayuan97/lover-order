import SwiftUI
import UIKit
import Photos

// 一顿的历史详情：头 + 菜列表 + 评价 + 补评 / 再来一次
struct HistoryDetailView: View {
    let mealId: UInt

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var meal: MealSession?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showReview: Bool = false
    @State private var showShoppingList: Bool = false
    @State private var showSharePoster: Bool = false
    @State private var isRepeating: Bool = false
    @State private var repeatedToast: String?
    @State private var tabBarToken = UUID()
    @State private var viewingGallery: HistoryPhotoGalleryItem?
    @State private var canvasSyncTick: Int = 0
    @State private var detailLoadID = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let meal {
                    titleBlock(meal)
                    if canvasSyncTick >= 0, mealCanvasDocumentExists(mealID: meal.id) {
                        MealCanvasSnapshotView(mealID: meal.id, allowLivePlayback: true)
                            .id("\(meal.id)-\(canvasSyncTick)")
                    }
                    dishesCard(meal)
                    reviewsCard(meal)
                    peopleCard(meal)
                    Color.clear.frame(height: 16)
                } else if isLoading {
                    ProgressView().tint(Color.brandGreen).padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(AppFont.body())
                        .foregroundStyle(Color.errorInk)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if let meal {
                bottomBar(meal)
            }
        }
        .onAppear {
            appState.setTabBarHidden(true, token: tabBarToken)
        }
        .onDisappear {
            appState.setTabBarHidden(false, token: tabBarToken)
        }
        .task {
            await NotificationManager.shared.markHistoryEventsRead(mealId: mealId)
            await load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyChanged)) { _ in
            Task { await load() }
        }
        .navigationTitle("这顿饭")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReview) {
            if let mid = meal?.id {
                MealReviewView(mealId: mid, currentUserId: appState.currentUser?.id) {
                    Task { await load() }
                }
            }
        }
        .sheet(isPresented: $showShoppingList) {
            if let mid = meal?.id {
                ShoppingListView(mealId: mid, allowNudgePartner: false)
            }
        }
        .sheet(isPresented: $showSharePoster) {
            if let meal {
                MealSharePosterSheet(
                    meal: meal,
                    householdName: appState.household?.name
                )
                .preferredColorScheme(.light)
            }
        }
        .fullScreenCover(item: $viewingGallery) { gallery in
            HistoryPhotoGalleryViewer(photos: gallery.photos, initialIndex: gallery.initialIndex)
        }
        .toast($errorMessage)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if meal != nil {
                    Button {
                        Haptics.light()
                        showSharePoster = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .accessibilityLabel("分享这顿饭")
                }
                Button {
                    showShoppingList = true
                } label: {
                    Image(systemName: "cart")
                        .foregroundStyle(Color.brandGreen)
                }
                .accessibilityLabel("买菜清单")
            }
        }
    }

    private func titleBlock(_ meal: MealSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.title?.isEmpty == false ? meal.title! : "这一顿")
                .font(AppFont.title(25))
                .foregroundStyle(Color.inkPrimary)
            HStack(spacing: 6) {
                if let when = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt {
                    Text(RelativeDateFormatter.format(when))
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cardBackground, in: Capsule())
                }
                Label(meal.scene.historyLabel, systemImage: meal.scene.historyIcon)
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cardBackground, in: Capsule())
                Text("\((meal.dishes ?? []).count) 道菜")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cardBackground, in: Capsule())
            }
            if let note = meal.note, !note.isEmpty {
                Text(note)
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
    }

    private func peopleCard(_ meal: MealSession) -> some View {
        let people = peopleFor(meal)
        return SectionCard {
            HStack(alignment: .center, spacing: 14) {
                avatarMosaic(people)
                VStack(alignment: .leading, spacing: 5) {
                    Text("一起吃饭的人")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    if people.isEmpty {
                        Text("还没记同行的人")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    } else {
                        Text(people.prefix(4).map(\.displayName).joined(separator: "、") + (people.count > 4 ? " 等" : ""))
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                        Text("共 \(people.count) 人")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func avatarMosaic(_ people: [AppUser]) -> some View {
        let positions: [(CGFloat, CGFloat)] = [(0, 0), (31, -13), (34, 20), (-27, 18), (-30, -15), (2, 31)]
        return ZStack {
            ForEach(Array(people.prefix(6).enumerated()), id: \.offset) { index, person in
                AvatarView(user: person, size: index == 0 ? 52 : 42, ring: true)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: positions[index].0, y: positions[index].1)
                    .zIndex(Double(people.count - index))
            }
            if people.count > 6 {
                Text("+\(people.count - 6)")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 42, height: 42)
                    .background(Color.appBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 28, y: 25)
            }
        }
        .frame(width: people.count <= 1 ? 58 : 112, height: people.count <= 1 ? 58 : 84)
    }

    private func peopleFor(_ meal: MealSession) -> [AppUser] {
        var seen: Set<UInt> = []
        var people: [AppUser] = []
        func appendUnique(_ user: AppUser?) {
            guard let user, seen.insert(user.id).inserted else { return }
            people.append(user)
        }
        appendUnique(meal.creator)
        for participant in meal.participants ?? [] {
            appendUnique(participant.user)
        }
        for dish in meal.dishes ?? [] {
            appendUnique(dish.adder)
        }
        if let members = appState.household?.members {
            for member in members {
                appendUnique(member)
            }
        }
        return people
    }

    private func dishesCard(_ meal: MealSession) -> some View {
        SectionCard {
            HStack {
                Text("吃了这些")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\((meal.dishes ?? []).count) 道")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            let dishes = meal.dishes ?? []
            if dishes.isEmpty {
                Text("还没记菜")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach(dishes) { dish in
                    if let recipeId = dish.recipeId {
                        NavigationLink {
                            RecipeDetailView(recipeId: recipeId)
                        } label: {
                            dishRowContent(dish, linked: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        dishRowContent(dish, linked: false)
                    }
                }
            }
        }
    }

    private func dishRowContent(_ dish: MealDish, linked: Bool) -> some View {
        HStack(spacing: AppSpacing.md) {
            DishThumb(name: dish.recipeName, image: dish.recipeImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(dish.recipeName)
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                if let note = dish.note, !note.isEmpty {
                    Text(note)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            if linked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkMuted.opacity(0.75))
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func reviewsCard(_ meal: MealSession) -> some View {
        let reviews = meal.reviews ?? []
        SectionCard {
            HStack {
                Text("备注和照片")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if meal.status == .completed {
                    let hasMyReview = reviews.contains { $0.userId == appState.currentUser?.id }
                    Button {
                        showReview = true
                    } label: {
                        Label(hasMyReview ? "编辑" : "添加", systemImage: hasMyReview ? "pencil" : "plus")
                            .font(AppFont.caption(13))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            if reviews.isEmpty {
                Text("留几句话，或放上这一顿的照片")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach(reviews) { review in
                    reviewRow(review)
                }
            }
        }
    }

    private func reviewRow(_ review: MealReview) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                AvatarView(user: review.user, size: 34)
                Text(review.user?.displayName ?? "我")
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(star <= review.rating ? Color.accentWarm : Color.dividerLine)
                    }
                }
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
            }
            if let photos = review.photos, !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                            Button {
                                Haptics.light()
                                viewingGallery = HistoryPhotoGalleryItem(photos: photos, initialIndex: index)
                            } label: {
                                AsyncImageView(url: url, name: "")
                                    .frame(width: 92, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.dividerLine.opacity(0.6), lineWidth: 0.6)
                                    }
                            }
                            .buttonStyle(SoftPressStyle())
                            .accessibilityLabel("查看大图 第 \(index + 1) 张")
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func bottomBar(_ meal: MealSession) -> some View {
        VStack(spacing: AppSpacing.sm) {
            if let repeatedToast {
                HStack(spacing: 10) {
                    Text(repeatedToast)
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Button {
                        Haptics.light()
                        dismiss()
                        appState.switchToMealTab()
                    } label: {
                        HStack(spacing: 3) {
                            Text("去画布")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.067, green: 0.067, blue: 0.075), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            HStack(spacing: AppSpacing.sm) {
                Button {
                    Haptics.light()
                    showSharePoster = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 50, height: 50)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.dividerLine, lineWidth: 0.8)
                        }
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("分享这顿饭")

                if meal.status == .completed && (meal.reviews ?? []).isEmpty {
                    Button {
                        showReview = true
                    } label: {
                        Label("补写记录", systemImage: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.dividerLine, lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(SoftPressStyle())
                }
                Button {
                    Task { await repeatMeal(meal) }
                } label: {
                    HStack(spacing: 7) {
                        if isRepeating {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isRepeating ? "正在添加…" : "把菜加到这一顿")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.067, green: 0.067, blue: 0.075), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isRepeating || (meal.dishes ?? []).isEmpty)
                .opacity((meal.dishes ?? []).isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private func load() async {
        detailLoadID += 1
        let loadID = detailLoadID
        isLoading = true
        defer {
            if loadID == detailLoadID { isLoading = false }
        }
        async let detailTask = MealService.shared.detail(id: mealId)
        async let canvasTask = syncRemoteMealCanvasIfNeeded(mealID: mealId, forceRefresh: true)
        do {
            let detail = try await detailTask
            guard loadID == detailLoadID else { return }
            meal = detail
        } catch {
            guard loadID == detailLoadID else { return }
            errorMessage = error.localizedDescription
        }
        if await canvasTask, loadID == detailLoadID {
            canvasSyncTick += 1
        }
    }

    // 把这一顿的菜复制到日常「我们这顿」
    private func repeatMeal(_ meal: MealSession) async {
        isRepeating = true
        defer { isRepeating = false }
        do {
            let current = try await MealService.shared.current(scene: .household, mood: appState.currentMood)
            let existingRecipeIds = Set((current.dishes ?? []).compactMap { $0.recipeId })
            let existingNames = Set((current.dishes ?? []).map { $0.recipeName })
            var added = 0
            for dish in meal.dishes ?? [] {
                if let rid = dish.recipeId {
                    if existingRecipeIds.contains(rid) { continue }
                    _ = try await MealService.shared.addDish(mealId: current.id, dish: DishInput(recipeId: rid, name: dish.recipeName, image: dish.recipeImage, note: dish.note))
                    added += 1
                } else if !dish.recipeName.isEmpty {
                    if existingNames.contains(dish.recipeName) { continue }
                    _ = try await MealService.shared.addDish(mealId: current.id, dish: DishInput(name: dish.recipeName, image: dish.recipeImage, note: dish.note))
                    added += 1
                }
            }
            // 再来一次始终打进日常我们这顿
            if added > 0 {
                AppNotifications.mealChanged()
            }
            Haptics.light()
            repeatedToast = added > 0 ? "已加 \(added) 道菜到这一顿" : "这些菜都在这一顿里啦"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct HistoryPhotoGalleryItem: Identifiable {
    let id = UUID()
    let photos: [String]
    let initialIndex: Int
}

private struct HistoryPhotoGalleryViewer: View {
    let photos: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(photos: [String], initialIndex: Int) {
        self.photos = photos
        let clamped = photos.isEmpty ? 0 : min(max(0, initialIndex), photos.count - 1)
        _currentIndex = State(initialValue: clamped)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                    ZoomableGalleryPhoto(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                if photos.count > 1 {
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                        }
                }
                Spacer()
                Button {
                    Haptics.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.48), in: Circle())
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.8)
                        }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityLabel("关闭大图")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ZoomableGalleryPhoto: View {
    let url: String
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            AsyncImageView(url: url, name: "记录照片", fitContent: true)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value, 1.0), 4.0)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                scale = min(max(scale, 1.0), 4.0)
                                lastScale = scale
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        if scale > 1.2 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.4
                            lastScale = 2.4
                        }
                    }
                }
        }
    }
}

// MARK: - 饭后分享海报工坊（电影画报 / 餐桌拼贴 / 胶片画册 / 私房菜单）

enum MealPosterTemplate: String, CaseIterable, Identifiable {
    case cinema = "电影画报"
    case collage = "餐桌拼贴"
    case gallery = "胶片画册"
    case menu = "私房菜单"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cinema: return "film"
        case .collage: return "sparkles.rectangle.stack"
        case .gallery: return "square.grid.2x2"
        case .menu: return "menucard"
        }
    }
}

private struct MealPosterCoverCandidate: Identifiable {
    let id = UUID()
    let label: String
    let image: UIImage
    let isCanvas: Bool
}

private struct MealPosterDishEntry: Identifiable {
    let id = UUID()
    let name: String
    let note: String?
    let rating: Int?
    let photo: UIImage?
    let cutoutSticker: UIImage?
}

private struct MealPosterGalleryItem: Identifiable {
    let id = UUID()
    let caption: String
    let image: UIImage
}

private struct MealPosterPayload {
    let title: String
    let mealNumber: String
    let dateText: String
    let cnDateText: String
    let monthEng: String
    let dayText: String
    let yearText: String
    let timeText: String
    let handwrittenDate: String
    let mealPeriodLabel: String
    let sceneLabel: String
    let householdName: String
    let dishes: [MealPosterDishEntry]
    let rating: Int?
    let comment: String?
    let participants: [String]
    let activeCover: UIImage?
    let hasCanvasCover: Bool
    let galleryItems: [MealPosterGalleryItem]
    let showDishes: Bool
    let showReview: Bool
    let showPeople: Bool
}

struct MealSharePosterSheet: View {
    let meal: MealSession
    var householdName: String? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var template: MealPosterTemplate = .cinema
    @State private var showDishes: Bool = true
    @State private var showReview: Bool = true
    @State private var showPeople: Bool = true

    @State private var covers: [MealPosterCoverCandidate] = []
    @State private var selectedCoverIndex: Int = 0
    @State private var dishPhotos: [UInt: UIImage] = [:]
    @State private var dishCutouts: [UInt: UIImage] = [:]
    @State private var reviewPhotos: [UIImage] = []
    @State private var isPreparingMedia: Bool = true

    @State private var isExportingPoster: Bool = false
    @State private var shareActivityItems: SharePosterActivityItem?
    @State private var liveExportProgress: Double?
    @State private var hasSyncedCanvas: Bool = false
    @State private var tipMessage: String?

    private var hasCanvas: Bool {
        hasSyncedCanvas || mealCanvasDocumentExists(mealID: meal.id)
    }

    private var activeCoverCandidate: MealPosterCoverCandidate? {
        guard !covers.isEmpty else { return nil }
        let safeIdx = min(max(0, selectedCoverIndex), covers.count - 1)
        return covers[safeIdx]
    }

    private var payload: MealPosterPayload {
        let dishRatingMap: [UInt: Int] = {
            var map: [UInt: Int] = [:]
            for review in meal.reviews ?? [] {
                for dr in review.dishReviews ?? [] {
                    map[dr.mealDishId] = dr.rating
                }
            }
            return map
        }()

        let dishItems: [MealPosterDishEntry] = (meal.dishes ?? []).map { d in
            MealPosterDishEntry(
                name: d.recipeName,
                note: d.note?.isEmpty == false ? d.note : nil,
                rating: dishRatingMap[d.id],
                photo: dishPhotos[d.id],
                cutoutSticker: dishCutouts[d.id]
            )
        }

        let when = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt ?? Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: when)
        let periodLabel: String = {
            switch hour {
            case 5..<10: return "早餐"
            case 10..<14: return "午餐"
            case 14..<17: return "下午茶"
            case 17..<21: return "晚餐"
            default: return "夜宵"
            }
        }()

        let mealTitle: String = {
            if let t = meal.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                return t
            }
            if meal.scene == .dining {
                return "好友欢聚食光"
            }
            switch hour {
            case 5..<10: return "早安小餐桌"
            case 10..<14: return "午间好食光"
            case 14..<17: return "午后惬意时刻"
            case 17..<21: return "今晚吃点好的"
            default: return "深夜小食堂"
            }
        }()

        let dotFmt = DateFormatter()
        dotFmt.locale = Locale(identifier: "en_US_POSIX")
        dotFmt.dateFormat = "yyyy.MM.dd"

        let cnFmt = DateFormatter()
        cnFmt.locale = Locale(identifier: "zh_CN")
        cnFmt.dateFormat = "yyyy年M月d日"

        let monthFmt = DateFormatter()
        monthFmt.locale = Locale(identifier: "en_US_POSIX")
        monthFmt.dateFormat = "MMM"

        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "en_US_POSIX")
        dayFmt.dateFormat = "dd"

        let yearFmt = DateFormatter()
        yearFmt.locale = Locale(identifier: "en_US_POSIX")
        yearFmt.dateFormat = "yyyy"

        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "en_US_POSIX")
        timeFmt.dateFormat = "HH:mm"

        let handFmt = DateFormatter()
        handFmt.locale = Locale(identifier: "en_US_POSIX")
        handFmt.dateFormat = "M.dd"

        let firstReview = meal.reviews?.first(where: { ($0.comment?.isEmpty == false) || $0.rating > 0 }) ?? meal.reviews?.first

        var seenNames: Set<String> = []
        var peopleNames: [String] = []
        func appendName(_ user: AppUser?) {
            guard let user else { return }
            let n = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty, seenNames.insert(n).inserted else { return }
            peopleNames.append(n)
        }
        appendName(meal.creator)
        for p in meal.participants ?? [] { appendName(p.user) }
        for d in meal.dishes ?? [] { appendName(d.adder) }
        for r in meal.reviews ?? [] { appendName(r.user) }

        var gallery: [MealPosterGalleryItem] = []
        if let canvas = covers.first(where: \.isCanvas) {
            gallery.append(MealPosterGalleryItem(caption: "自由画布", image: canvas.image))
        }
        for (idx, photo) in reviewPhotos.enumerated() where gallery.count < 4 {
            gallery.append(MealPosterGalleryItem(caption: "实拍 \(idx + 1)", image: photo))
        }
        for item in dishItems where gallery.count < 4 {
            if let photo = item.photo {
                gallery.append(MealPosterGalleryItem(caption: item.name, image: photo))
            }
        }

        return MealPosterPayload(
            title: mealTitle,
            mealNumber: String(format: "%03d", meal.id),
            dateText: dotFmt.string(from: when),
            cnDateText: cnFmt.string(from: when),
            monthEng: monthFmt.string(from: when).uppercased(),
            dayText: dayFmt.string(from: when),
            yearText: yearFmt.string(from: when),
            timeText: timeFmt.string(from: when),
            handwrittenDate: handFmt.string(from: when),
            mealPeriodLabel: periodLabel,
            sceneLabel: meal.scene.historyLabel,
            householdName: householdName?.isEmpty == false ? householdName! : "我们家",
            dishes: dishItems,
            rating: firstReview?.rating,
            comment: firstReview?.comment?.trimmingCharacters(in: .whitespacesAndNewlines),
            participants: peopleNames,
            activeCover: activeCoverCandidate?.image,
            hasCanvasCover: activeCoverCandidate?.isCanvas ?? false,
            galleryItems: gallery,
            showDishes: showDishes,
            showReview: showReview,
            showPeople: showPeople
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                previewStage
                controlsDeck
            }
            .background(Color(red: 0.945, green: 0.938, blue: 0.922).ignoresSafeArea())
            .navigationTitle("分享这顿饭")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                if covers.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.light()
                            selectedCoverIndex = (selectedCoverIndex + 1) % covers.count
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("换主图 · \(covers[min(selectedCoverIndex, covers.count - 1)].label)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.inkPrimary)
                        }
                    }
                }
            }
            .task {
                await prepareMedia()
            }
            .sheet(item: $shareActivityItems) { item in
                ShareSheet(items: item.items)
            }
            .tipToast($tipMessage)
        }
    }

    private var previewStage: some View {
        GeometryReader { proxy in
            let availW = max(240, proxy.size.width - 36)
            let availH = max(260, proxy.size.height - 20)
            let scale = min(availW / 360.0, availH / 560.0, 1.0)

            ZStack {
                posterView(for: payload)
                    .frame(width: 360, height: 560)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.6)
                    }
                    .shadow(color: Color.black.opacity(0.16), radius: 24, y: 12)
                    .scaleEffect(scale)
                    .frame(width: 360 * scale, height: 560 * scale)

                if isPreparingMedia {
                    ProgressView()
                        .tint(.white)
                        .padding(11)
                        .background(Color.black.opacity(0.45), in: Circle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.vertical, 8)
    }

    private var controlsDeck: some View {
        VStack(spacing: 11) {
            // 4 套风格模板切换
            HStack(spacing: 6) {
                ForEach(MealPosterTemplate.allCases) { item in
                    let active = template == item
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            template = item
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(active ? .white : Color.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            active ? Color.actionInk : Color.cardBackground,
                            in: Capsule()
                        )
                        .overlay {
                            if !active {
                                Capsule().strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                            }
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }

            // 展示开关
            HStack(spacing: 8) {
                toggleChip("菜品", isOn: $showDishes)
                toggleChip("评价与留言", isOn: $showReview)
                toggleChip("同行的人", isOn: $showPeople)
                Spacer(minLength: 0)
            }

            // 分享与存相册操作栏
            HStack(spacing: 10) {
                Button {
                    Task { await savePosterToPhotos() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text("存相册")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.dividerLine, lineWidth: 0.8)
                    }
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isExportingPoster)

                if hasCanvas {
                    Button {
                        exportLiveCanvas()
                    } label: {
                        HStack(spacing: 5) {
                            if let progress = liveExportProgress {
                                ProgressView(value: progress)
                                    .progressViewStyle(.circular)
                                    .tint(Color.inkPrimary)
                                    .controlSize(.mini)
                                Text("\(Int((progress * 100).rounded()))%")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            } else {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text("存实况")
                                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.dividerLine, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                    .disabled(liveExportProgress != nil)
                }

                Button {
                    Task { await sharePosterSystemSheet() }
                } label: {
                    HStack(spacing: 6) {
                        if isExportingPoster {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isExportingPoster ? "生成海报中…" : "分享给朋友")
                            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.actionInk, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isExportingPoster)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private func toggleChip(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            Haptics.light()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn.wrappedValue ? Color.inkPrimary : Color.inkMuted)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                isOn.wrappedValue ? Color.cardBackground : Color.appBackground,
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(
                    isOn.wrappedValue ? Color.inkPrimary.opacity(0.28) : Color.dividerLine.opacity(0.7),
                    lineWidth: 0.7
                )
            }
        }
        .buttonStyle(SoftPressStyle())
    }

    @ViewBuilder
    private func posterView(for data: MealPosterPayload) -> some View {
        switch template {
        case .cinema:
            CinemaEditorialPoster(payload: data)
        case .collage:
            TableCollagePoster(payload: data)
        case .gallery:
            FilmGalleryPoster(payload: data)
        case .menu:
            BistroMenuPoster(payload: data)
        }
    }

    private func renderPosterUIImage() -> UIImage? {
        let content = posterView(for: payload)
            .frame(width: 360, height: 560)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        renderer.proposedSize = ProposedViewSize(CGSize(width: 360, height: 560))
        return renderer.uiImage
    }

    private func buildShareCaption() -> String {
        let data = payload
        var lines: [String] = ["【\(data.title)】 · \(data.dateText)"]
        if !data.dishes.isEmpty {
            let names = data.dishes.prefix(6).map(\.name).joined(separator: "、")
            lines.append("吃了：\(names)\(data.dishes.count > 6 ? " 等 \(data.dishes.count) 道" : "")")
        }
        if let comment = data.comment, !comment.isEmpty {
            lines.append("“\(comment)”")
        }
        lines.append("来自「\(data.householdName)」的我们这顿")
        return lines.joined(separator: "\n")
    }

    private func sharePosterSystemSheet() async {
        isExportingPoster = true
        defer { isExportingPoster = false }
        try? await Task.sleep(for: .milliseconds(30))
        guard let image = renderPosterUIImage() else {
            tipMessage = "生成海报失败，请稍后重试"
            return
        }
        Haptics.light()
        shareActivityItems = SharePosterActivityItem(items: [image, buildShareCaption()])
    }

    private func savePosterToPhotos() async {
        isExportingPoster = true
        defer { isExportingPoster = false }
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else {
            tipMessage = "请在系统设置中允许保存照片"
            return
        }
        guard let image = renderPosterUIImage() else {
            tipMessage = "生成海报失败，请稍后重试"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            Haptics.success()
            tipMessage = "分享海报已保存到相册"
        } catch {
            tipMessage = "保存失败，请重试"
        }
    }

    private func exportLiveCanvas() {
        guard liveExportProgress == nil else { return }
        Task {
            liveExportProgress = 0.02
            defer { liveExportProgress = nil }
            do {
                try await exportMealCanvasLivePhoto(mealID: meal.id) { p in
                    liveExportProgress = p
                }
                Haptics.success()
                tipMessage = "实况画布已保存到相册"
            } catch {
                tipMessage = error.localizedDescription
            }
        }
    }

    private func prepareMedia() async {
        isPreparingMedia = true
        defer { isPreparingMedia = false }

        var candidateList: [MealPosterCoverCandidate] = []
        if await syncRemoteMealCanvasIfNeeded(mealID: meal.id) {
            hasSyncedCanvas = true
        }
        if let canvasImg = await renderMealCanvasStillImage(mealID: meal.id) {
            candidateList.append(MealPosterCoverCandidate(label: "自由画布", image: canvasImg, isCanvas: true))
        }

        let photoURLStrings = (meal.reviews ?? []).flatMap { $0.photos ?? [] }
        var loadedReviewImgs: [UIImage] = []
        for (idx, raw) in photoURLStrings.prefix(6).enumerated() {
            guard let url = APIConfig.imageURL(raw),
                  let img = await RemoteImageCache.shared.load(url: url) else { continue }
            loadedReviewImgs.append(img)
            candidateList.append(MealPosterCoverCandidate(label: "实拍 \(idx + 1)", image: img, isCanvas: false))
        }

        var loadedDishPhotos: [UInt: UIImage] = [:]
        var loadedCutouts: [UInt: UIImage] = [:]
        for (idx, dish) in (meal.dishes ?? []).prefix(6).enumerated() {
            if let imgUrl = APIConfig.imageURL(dish.recipeImage),
               let img = await RemoteImageCache.shared.load(url: imgUrl) {
                loadedDishPhotos[dish.id] = img
                candidateList.append(MealPosterCoverCandidate(label: dish.recipeName, image: img, isCanvas: false))

                if idx < 4 {
                    if let cutUrl = APIConfig.imageURL(dish.recipeCutoutImage),
                       let rawCut = await RemoteImageCache.shared.load(url: cutUrl) {
                        let dieCut = await StickerBorderRenderer.shared.makeDieCutSticker(
                            from: rawCut,
                            cacheKey: cutUrl.absoluteString
                        )
                        loadedCutouts[dish.id] = dieCut
                    } else if let autoCut = await DishCutoutCache.shared.cutout(for: imgUrl, sourceImage: img) {
                        let dieCut = await StickerBorderRenderer.shared.makeDieCutSticker(
                            from: autoCut,
                            cacheKey: imgUrl.absoluteString
                        )
                        loadedCutouts[dish.id] = dieCut
                    }
                }
            }
        }

        covers = candidateList
        reviewPhotos = loadedReviewImgs
        dishPhotos = loadedDishPhotos
        dishCutouts = loadedCutouts
    }
}

private struct SharePosterActivityItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

// 模板 1：电影画报（100% 全出血实景摄影 + 多段暗渐层 + 横排菜品胶片缩略条）
private struct CinemaEditorialPoster: View {
    let payload: MealPosterPayload

    private let champagne = Color(red: 0.945, green: 0.851, blue: 0.663)

    var body: some View {
        ZStack {
            heroBackdrop
                .frame(width: 360, height: 560)
                .clipped()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.52), Color.black.opacity(0.16), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 112)

                Spacer(minLength: 0)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.black.opacity(0.32), location: 0.25),
                        .init(color: Color.black.opacity(0.72), location: 0.58),
                        .init(color: Color(red: 0.06, green: 0.055, blue: 0.05).opacity(0.94), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 360)
            }
            .frame(width: 360, height: 560)

            VStack(alignment: .leading, spacing: 0) {
                // 顶部电影刊头
                VStack(spacing: 8) {
                    HStack {
                        Text("OUR TABLE  ·  NO.\(payload.mealNumber)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                        Spacer()
                        Text("\(payload.monthEng) \(payload.dayText)  ·  \(payload.timeText)")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.88))

                    Rectangle()
                        .fill(.white.opacity(0.24))
                        .frame(height: 0.6)
                }

                Spacer(minLength: 0)

                // 下部核心排布
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(payload.sceneLabel)  ·  \(payload.householdName)")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(champagne)

                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(payload.title)
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Spacer(minLength: 6)
                            Text(payload.handwrittenDate)
                                .font(.custom("Noteworthy-Bold", size: 22))
                                .foregroundStyle(champagne.opacity(0.95))
                        }
                    }

                    if payload.showDishes && !payload.dishes.isEmpty {
                        dishStrip
                    }

                    if payload.showReview && (payload.rating != nil || (payload.comment?.isEmpty == false)) {
                        reviewBlock
                    }

                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(height: 0.6)

                    HStack {
                        if payload.showPeople && !payload.participants.isEmpty {
                            Text("同桌 · \(payload.participants.prefix(4).joined(separator: "、"))")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineLimit(1)
                        } else {
                            Text("\(payload.dishes.count) 道记在今天")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.76))
                        }
                        Spacer()
                        Text("我们这顿 · LOVER ORDER")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
            }
            .padding(20)
            .frame(width: 360, height: 560)
        }
        .frame(width: 360, height: 560)
        .background(Color.black)
    }

    @ViewBuilder
    private var heroBackdrop: some View {
        if let img = payload.activeCover {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else if let fallback = UIImage(named: "ProfileHeroCover") ?? UIImage(named: "CanvasMeadow") {
            Image(uiImage: fallback)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.13, blue: 0.12), Color(red: 0.05, green: 0.05, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var dishStrip: some View {
        let visible = Array(payload.dishes.prefix(4))
        let hasAnyPhoto = visible.contains { $0.photo != nil }

        if hasAnyPhoto {
            HStack(spacing: 8) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { idx, dish in
                    let isOverflowTile = idx == 3 && payload.dishes.count > 4
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack {
                            if let photo = dish.photo {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.white.opacity(0.14)
                                    .overlay {
                                        Text(String(dish.name.prefix(1)))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.white.opacity(0.32), lineWidth: 0.7)
                        }
                        .overlay {
                            if isOverflowTile {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.45))
                                Text("+\(payload.dishes.count - 3)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(dish.name)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            Text(payload.dishes.prefix(6).map(\.name).joined(separator: "  /  "))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(2)
        }
    }

    private var reviewBlock: some View {
        HStack(alignment: .top, spacing: 9) {
            Rectangle()
                .fill(champagne)
                .frame(width: 2)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                if let r = payload.rating, r > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= r ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(star <= r ? champagne : .white.opacity(0.25))
                        }
                    }
                }
                if let c = payload.comment, !c.isEmpty {
                    Text("“\(c)”")
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(2)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// 模板 2：餐桌拼贴（复刻产品灵魂：全幅桌面氛围底 + 真实白边模切盘装菜品贴纸 + 磨砂信息悬浮卡）
private struct TableCollagePoster: View {
    let payload: MealPosterPayload

    private let ink = Color(red: 0.08, green: 0.08, blue: 0.095)

    var body: some View {
        if payload.hasCanvasCover, let canvasImg = payload.activeCover {
            canvasFirstPoster(canvasImg)
        } else {
            dishStickersTablePoster
        }
    }

    private func canvasFirstPoster(_ canvasImg: UIImage) -> some View {
        ZStack {
            Image(uiImage: canvasImg)
                .resizable()
                .scaledToFill()
                .frame(width: 360, height: 560)
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(payload.dateText)  ·  \(payload.sceneLabel)")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.40), in: Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 0.7) }
                    Spacer()
                }
                Spacer()
                frostedFooterCard
            }
            .padding(16)
        }
        .frame(width: 360, height: 560)
    }

    private var dishStickersTablePoster: some View {
        let layoutSlots = collageSlots(for: min(4, payload.dishes.count))
        let visibleDishes = Array(payload.dishes.prefix(4))

        return ZStack {
            Group {
                if let bg = UIImage(named: "CanvasMeadow") ?? UIImage(named: "ProfileHeroCover") {
                    Image(uiImage: bg)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 3)
                        .scaleEffect(1.06)
                } else {
                    Color(red: 0.24, green: 0.27, blue: 0.22)
                }
            }
            .frame(width: 360, height: 560)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.30), Color.black.opacity(0.08), Color.black.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // 顶部手账氛围头 + 干杯水粉贴纸
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(payload.householdName)  ·  \(payload.mealPeriodLabel)")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.36), in: Capsule())
                            .overlay { Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 0.7) }

                        Text(payload.dateText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.86))
                            .padding(.leading, 4)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(payload.handwrittenDate)
                            .font(.custom("Noteworthy-Bold", size: 22))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                        Image("StickerEmoji_food_cheers")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(8))
                            .shadow(color: .black.opacity(0.24), radius: 6, y: 3)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                // 中央桌面拼贴舞台
                ZStack {
                    ForEach(Array(visibleDishes.enumerated()), id: \.element.id) { idx, dish in
                        let slot = layoutSlots[idx]
                        dishStickerTile(dish: dish, side: slot.side, angle: slot.angle)
                            .position(x: slot.x, y: slot.y)
                            .zIndex(Double(visibleDishes.count - idx))
                    }
                }
                .frame(width: 360, height: 320)

                Spacer(minLength: 0)

                frostedFooterCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(width: 360, height: 560)
    }

    private struct CollageSlot {
        let x: CGFloat
        let y: CGFloat
        let side: CGFloat
        let angle: Double
    }

    private func collageSlots(for count: Int) -> [CollageSlot] {
        switch count {
        case 1:
            return [CollageSlot(x: 180, y: 156, side: 218, angle: -2.0)]
        case 2:
            return [
                CollageSlot(x: 116, y: 114, side: 152, angle: -5.5),
                CollageSlot(x: 244, y: 208, side: 152, angle: 4.5)
            ]
        case 3:
            return [
                CollageSlot(x: 180, y: 74, side: 138, angle: -2.0),
                CollageSlot(x: 102, y: 228, side: 132, angle: -5.5),
                CollageSlot(x: 258, y: 224, side: 132, angle: 5.0)
            ]
        default:
            return [
                CollageSlot(x: 102, y: 80, side: 124, angle: -5.0),
                CollageSlot(x: 256, y: 88, side: 122, angle: 5.5),
                CollageSlot(x: 108, y: 230, side: 122, angle: 3.5),
                CollageSlot(x: 254, y: 234, side: 124, angle: -4.5)
            ]
        }
    }

    private func dishStickerTile(dish: MealPosterDishEntry, side: CGFloat, angle: Double) -> some View {
        VStack(spacing: -8) {
            Group {
                if let cutout = dish.cutoutSticker {
                    Image(uiImage: cutout)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side, height: side)
                        .shadow(color: .black.opacity(0.32), radius: 14, y: 8)
                } else if let photo = dish.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side * 0.84, height: side * 0.84)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(5)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
                } else {
                    Text(dish.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.99, green: 0.985, blue: 0.968), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                }
            }

            if payload.showDishes && (dish.cutoutSticker != nil || dish.photo != nil) {
                Text(dish.name)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(red: 0.996, green: 0.99, blue: 0.975), in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.6) }
                    .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            }
        }
        .rotationEffect(.degrees(angle))
    }

    private var frostedFooterCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                Text(payload.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Spacer()
                Text("\(payload.dishes.count) 道菜")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.75))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.black.opacity(0.06), in: Capsule())
            }

            if payload.showDishes && !payload.dishes.isEmpty {
                Text(payload.dishes.prefix(6).map(\.name).joined(separator: "  ·  "))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.76))
                    .lineLimit(2)
            }

            if payload.showReview && (payload.rating != nil || (payload.comment?.isEmpty == false)) {
                HStack(spacing: 6) {
                    if let r = payload.rating, r > 0 {
                        HStack(spacing: 1.5) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= r ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(star <= r ? Color(red: 0.87, green: 0.62, blue: 0.24) : ink.opacity(0.2))
                            }
                        }
                    }
                    if let c = payload.comment, !c.isEmpty {
                        Text("“\(c)”")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(ink.opacity(0.84))
                            .lineLimit(1)
                    }
                }
            }

            HStack {
                if payload.showPeople && !payload.participants.isEmpty {
                    Text("同桌 · \(payload.participants.prefix(4).joined(separator: "、"))")
                } else {
                    Text(payload.householdName)
                }
                Spacer()
                Text("我们这顿 · OUR TABLE")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(ink.opacity(0.54))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.992, green: 0.986, blue: 0.975).opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}

// 模板 3：胶片画册（建筑感刊头 + 1~4 图 Bento 多菜画廊 + 博物馆留白页脚）
private struct FilmGalleryPoster: View {
    let payload: MealPosterPayload

    private let paper = Color(red: 0.965, green: 0.953, blue: 0.929)
    private let ink = Color(red: 0.10, green: 0.10, blue: 0.11)

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // 建筑感刊头
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THE TABLE ARCHIVE  ·  NO.\(payload.mealNumber)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(ink.opacity(0.50))
                    Text(payload.title)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(payload.dayText)
                        .font(.system(size: 25, weight: .bold, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Text("\(payload.monthEng) \(payload.yearText)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(ink.opacity(0.52))
                }
            }

            Rectangle().fill(ink.opacity(0.16)).frame(height: 0.7)

            // 自适应多图 Bento 画廊（把每一道美照都晒出来）
            bentoGallery
                .frame(width: 324, height: 356)

            Rectangle().fill(ink.opacity(0.16)).frame(height: 0.7)

            // 画册页脚
            VStack(alignment: .leading, spacing: 6) {
                if payload.showDishes && !payload.dishes.isEmpty {
                    Text(payload.dishes.prefix(6).map(\.name).joined(separator: "  ·  "))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.86))
                        .lineLimit(2)
                }

                if payload.showReview && (payload.rating != nil || (payload.comment?.isEmpty == false)) {
                    HStack(spacing: 6) {
                        if let r = payload.rating, r > 0 {
                            HStack(spacing: 1.5) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= r ? "star.fill" : "star")
                                        .font(.system(size: 9))
                                        .foregroundStyle(star <= r ? Color(red: 0.82, green: 0.58, blue: 0.22) : ink.opacity(0.18))
                                }
                            }
                        }
                        if let c = payload.comment, !c.isEmpty {
                            Text("“\(c)”")
                                .font(.system(size: 11, weight: .regular, design: .serif))
                                .foregroundStyle(ink.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    if payload.showPeople && !payload.participants.isEmpty {
                        Text("\(payload.householdName)  ·  同桌：\(payload.participants.prefix(3).joined(separator: "、"))")
                    } else {
                        Text("\(payload.householdName)  ·  \(payload.sceneLabel)")
                    }
                    Spacer()
                    Text("\(payload.dishes.count) DISHES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(ink.opacity(0.52))
            }
        }
        .padding(18)
        .frame(width: 360, height: 560)
        .background(paper)
    }

    @ViewBuilder
    private var bentoGallery: some View {
        let items = payload.galleryItems
        if items.isEmpty {
            let fallback = payload.activeCover ?? UIImage(named: "ProfileHeroCover")
            galleryTile(caption: payload.sceneLabel, image: fallback, width: 324, height: 356, index: 0)
        } else if items.count == 1 {
            galleryTile(caption: items[0].caption, image: items[0].image, width: 324, height: 356, index: 0)
        } else if items.count == 2 {
            VStack(spacing: 8) {
                galleryTile(caption: items[0].caption, image: items[0].image, width: 324, height: 196, index: 0)
                galleryTile(caption: items[1].caption, image: items[1].image, width: 324, height: 152, index: 1)
            }
        } else if items.count == 3 {
            VStack(spacing: 8) {
                galleryTile(caption: items[0].caption, image: items[0].image, width: 324, height: 202, index: 0)
                HStack(spacing: 8) {
                    galleryTile(caption: items[1].caption, image: items[1].image, width: 158, height: 146, index: 1)
                    galleryTile(caption: items[2].caption, image: items[2].image, width: 158, height: 146, index: 2)
                }
            }
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    galleryTile(caption: items[0].caption, image: items[0].image, width: 158, height: 174, index: 0)
                    galleryTile(caption: items[1].caption, image: items[1].image, width: 158, height: 174, index: 1)
                }
                HStack(spacing: 8) {
                    galleryTile(caption: items[2].caption, image: items[2].image, width: 158, height: 174, index: 2)
                    galleryTile(caption: items[3].caption, image: items[3].image, width: 158, height: 174, index: 3)
                }
            }
        }
    }

    private func galleryTile(caption: String, image: UIImage?, width: CGFloat, height: CGFloat, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Color(red: 0.90, green: 0.88, blue: 0.84)
                    .frame(width: width, height: height)
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)

            if payload.showDishes && !caption.isEmpty {
                Text(String(format: "%02d  %@", index + 1, caption))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 7)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 0.8)
        }
    }
}

// 模板 4：私房菜单（主厨印刷风卡片 + 重叠圆形瓷盘徽章 + 私房印章）
private struct BistroMenuPoster: View {
    let payload: MealPosterPayload

    private let frameWood = Color(red: 0.135, green: 0.125, blue: 0.118)
    private let paper = Color(red: 0.980, green: 0.969, blue: 0.945)
    private let ink = Color(red: 0.11, green: 0.105, blue: 0.10)
    private let sealRed = Color(red: 0.62, green: 0.24, blue: 0.19)

    private var medallionImages: [UIImage] {
        var list: [UIImage] = []
        for dish in payload.dishes {
            if let img = dish.photo {
                list.append(img)
                if list.count == 3 { break }
            }
        }
        if list.isEmpty, let cover = payload.activeCover {
            list.append(cover)
        }
        return list
    }

    private func romanNumeral(_ index: Int) -> String {
        let map = ["I", "II", "III", "IV", "V", "VI"]
        return index < map.count ? map[index] : "\(index + 1)"
    }

    var body: some View {
        ZStack {
            frameWood

            ZStack {
                paper

                // 经典双细线画框
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(ink.opacity(0.28), lineWidth: 0.9)
                    .padding(7)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(ink.opacity(0.14), lineWidth: 0.5)
                    .padding(11)

                VStack(spacing: 0) {
                    // 刊头
                    VStack(spacing: 5) {
                        Text("✦   MENU DU JOUR   ✦")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(ink.opacity(0.55))

                        Text(payload.householdName)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(ink)
                            .lineLimit(1)

                        Text("\(payload.cnDateText)  ·  \(payload.mealPeriodLabel)  ·  \(payload.sceneLabel)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(ink.opacity(0.58))
                    }

                    Spacer(minLength: 10)

                    // 圆形瓷盘菜品拼盘
                    plateMedallions

                    Spacer(minLength: 10)

                    Rectangle()
                        .fill(ink.opacity(0.20))
                        .frame(width: 96, height: 0.7)

                    Spacer(minLength: 10)

                    // 居中菜单正文
                    if payload.showDishes && !payload.dishes.isEmpty {
                        VStack(spacing: 9) {
                            ForEach(Array(payload.dishes.prefix(6).enumerated()), id: \.element.id) { idx, dish in
                                HStack(spacing: 6) {
                                    Text("\(romanNumeral(idx))  ·")
                                        .font(.system(size: 10.5, weight: .medium, design: .serif))
                                        .foregroundStyle(ink.opacity(0.45))

                                    Text(dish.name)
                                        .font(.system(size: 15.5, weight: .semibold, design: .serif))
                                        .foregroundStyle(ink)
                                        .lineLimit(1)

                                    if let dr = dish.rating, dr > 0 {
                                        Text("★\(dr)")
                                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.78, green: 0.54, blue: 0.20))
                                    }
                                }
                            }
                            if payload.dishes.count > 6 {
                                Text("— 余 \(payload.dishes.count - 6) 道菜 —")
                                    .font(.system(size: 10, weight: .medium, design: .serif))
                                    .foregroundStyle(ink.opacity(0.48))
                            }
                        }
                    }

                    Spacer(minLength: 10)

                    // 评语或私房寄语
                    if payload.showReview && (payload.rating != nil || (payload.comment?.isEmpty == false)) {
                        VStack(spacing: 4) {
                            if let r = payload.rating, r > 0 {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= r ? "star.fill" : "star")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(star <= r ? Color(red: 0.78, green: 0.54, blue: 0.20) : ink.opacity(0.18))
                                    }
                                }
                            }
                            if let c = payload.comment, !c.isEmpty {
                                Text("“\(c)”")
                                    .font(.system(size: 11.5, weight: .regular, design: .serif))
                                    .foregroundStyle(ink.opacity(0.80))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 12)
                    } else {
                        Text("—  好好吃饭，日日欢喜  —")
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .foregroundStyle(ink.opacity(0.46))
                    }

                    Spacer(minLength: 12)

                    Rectangle()
                        .fill(ink.opacity(0.16))
                        .frame(height: 0.6)
                        .padding(.bottom, 10)

                    // 页脚与红色私房印章
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payload.title)
                                .font(.system(size: 12, weight: .bold, design: .serif))
                                .foregroundStyle(ink)
                            if payload.showPeople && !payload.participants.isEmpty {
                                Text("同桌：\(payload.participants.prefix(4).joined(separator: " · "))")
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(ink.opacity(0.58))
                            } else {
                                Text("NO.\(payload.mealNumber)  ·  \(payload.timeText)")
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(ink.opacity(0.52))
                            }
                        }
                        Spacer()
                        tableSealStamp
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(8)
        }
        .frame(width: 360, height: 560)
    }

    @ViewBuilder
    private var plateMedallions: some View {
        let imgs = medallionImages
        if imgs.isEmpty {
            Image("StickerEmoji_food_cheers")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
        } else if imgs.count == 1 {
            circlePlate(imgs[0], diameter: 108)
        } else if imgs.count == 2 {
            HStack(spacing: -14) {
                circlePlate(imgs[0], diameter: 90)
                    .zIndex(2)
                circlePlate(imgs[1], diameter: 80)
                    .zIndex(1)
            }
        } else {
            HStack(spacing: -16) {
                circlePlate(imgs[1], diameter: 74)
                    .zIndex(1)
                circlePlate(imgs[0], diameter: 98)
                    .zIndex(3)
                circlePlate(imgs[2], diameter: 74)
                    .zIndex(2)
            }
        }
    }

    private func circlePlate(_ image: UIImage, diameter: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: diameter, height: diameter)
            .clipped()
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(paper, lineWidth: 3)
            }
            .overlay {
                Circle().strokeBorder(ink.opacity(0.14), lineWidth: 0.6)
            }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
    }

    private var tableSealStamp: some View {
        ZStack {
            Circle()
                .strokeBorder(sealRed.opacity(0.85), lineWidth: 1.4)
                .frame(width: 38, height: 38)
            Circle()
                .strokeBorder(sealRed.opacity(0.45), lineWidth: 0.6)
                .frame(width: 32, height: 32)
            Text("我们\n这顿")
                .font(.system(size: 8.5, weight: .bold, design: .serif))
                .foregroundStyle(sealRed.opacity(0.90))
                .multilineTextAlignment(.center)
                .lineSpacing(0)
        }
        .rotationEffect(.degrees(-8))
    }
}
