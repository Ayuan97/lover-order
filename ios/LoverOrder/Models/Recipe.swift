import Foundation

// 难度
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "进阶"
        }
    }
}

// 食材项
struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var note: String?

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case note
    }
}

// 做法步骤
struct CookingStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var index: Int
    var text: String
    var image: String?

    enum CodingKeys: String, CodingKey {
        case index
        case text
        case image
    }
}

// 菜谱分类
struct RecipeCategory: Codable, Identifiable, Hashable {
    let id: UInt
    var name: String
    var icon: String?
    var color: String?
    var sortOrder: Int
    var recipeCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case sortOrder = "sort_order"
        case recipeCount = "recipe_count"
    }
}

// 菜谱
struct RecipePhotoItem: Codable, Hashable, Identifiable {
    var image: String
    var cutoutImage: String?
    var createdAt: String?

    var id: String { image }

    enum CodingKeys: String, CodingKey {
        case image
        case cutoutImage = "cutout_image"
        case createdAt = "created_at"
    }
}

struct RecipePhotoChoice: Hashable, Identifiable {
    let image: String
    let cutoutImage: String?
    let createdAt: String?
    let isDefaultCover: Bool

    var id: String { image }
}

struct Recipe: Codable, Identifiable, Hashable {
    let id: UInt
    var name: String
    var description: String?
    var coverImage: String?
    var cutoutImage: String?
    var images: [String]?
    var photoGallery: [RecipePhotoItem]?
    var categoryId: UInt?
    var category: RecipeCategory?
    var cookingTime: Int?
    var difficulty: Difficulty?
    var servings: Int?
    var ingredients: [Ingredient]?
    var steps: [CookingStep]?
    var tips: String?
    var tags: [String]?
    var moodTags: [Mood]?
    // 保留旧菜谱中的原始标签，未知值不应导致整张菜谱解析失败。
    var sceneTags: [String]?
    var viewCount: Int?
    var useCount: Int?
    var lastUsedAt: Date?
    var createdAt: Date?
    var updatedAt: String
    var creator: AppUser?
    var isFavored: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case coverImage = "cover_image"
        case cutoutImage = "cutout_image"
        case images
        case photoGallery = "photo_gallery"
        case categoryId = "category_id"
        case category
        case cookingTime = "cooking_time"
        case difficulty
        case servings
        case ingredients
        case steps
        case tips
        case tags
        case moodTags = "mood_tags"
        case sceneTags = "scene_tags"
        case viewCount = "view_count"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case creator
        case isFavored = "is_favored"
    }

    init(
        id: UInt,
        name: String,
        description: String? = nil,
        coverImage: String? = nil,
        cutoutImage: String? = nil,
        images: [String]? = nil,
        photoGallery: [RecipePhotoItem]? = nil,
        categoryId: UInt? = nil,
        category: RecipeCategory? = nil,
        cookingTime: Int? = nil,
        difficulty: Difficulty? = nil,
        servings: Int? = nil,
        ingredients: [Ingredient]? = nil,
        steps: [CookingStep]? = nil,
        tips: String? = nil,
        tags: [String]? = nil,
        moodTags: [Mood]? = nil,
        sceneTags: [String]? = nil,
        viewCount: Int? = nil,
        useCount: Int? = nil,
        lastUsedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: String = "",
        creator: AppUser? = nil,
        isFavored: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverImage = coverImage
        self.cutoutImage = cutoutImage
        self.images = images
        self.photoGallery = photoGallery
        self.categoryId = categoryId
        self.category = category
        self.cookingTime = cookingTime
        self.difficulty = difficulty
        self.servings = servings
        self.ingredients = ingredients
        self.steps = steps
        self.tips = tips
        self.tags = tags
        self.moodTags = moodTags
        self.sceneTags = sceneTags
        self.viewCount = viewCount
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creator = creator
        self.isFavored = isFavored
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UInt.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        coverImage = try? c.decodeIfPresent(String.self, forKey: .coverImage)
        cutoutImage = try? c.decodeIfPresent(String.self, forKey: .cutoutImage)
        images = try? c.decodeIfPresent([String].self, forKey: .images)
        photoGallery = try? c.decodeIfPresent([RecipePhotoItem].self, forKey: .photoGallery)
        categoryId = try? c.decodeIfPresent(UInt.self, forKey: .categoryId)
        category = try? c.decodeIfPresent(RecipeCategory.self, forKey: .category)
        cookingTime = try? c.decodeIfPresent(Int.self, forKey: .cookingTime)
        if let rawDiff = try? c.decodeIfPresent(String.self, forKey: .difficulty) {
            difficulty = Difficulty(rawValue: rawDiff)
        } else {
            difficulty = nil
        }
        servings = try? c.decodeIfPresent(Int.self, forKey: .servings)
        ingredients = try? c.decodeIfPresent([Ingredient].self, forKey: .ingredients)
        steps = try? c.decodeIfPresent([CookingStep].self, forKey: .steps)
        tips = try? c.decodeIfPresent(String.self, forKey: .tips)
        tags = try? c.decodeIfPresent([String].self, forKey: .tags)
        if let rawMoods = try? c.decodeIfPresent([String].self, forKey: .moodTags) {
            moodTags = rawMoods.compactMap(Mood.init(rawValue:))
        } else {
            moodTags = nil
        }
        sceneTags = try? c.decodeIfPresent([String].self, forKey: .sceneTags)
        viewCount = try? c.decodeIfPresent(Int.self, forKey: .viewCount)
        useCount = try? c.decodeIfPresent(Int.self, forKey: .useCount)
        lastUsedAt = try? c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = (try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? ""
        creator = try? c.decodeIfPresent(AppUser.self, forKey: .creator)
        isFavored = try? c.decodeIfPresent(Bool.self, forKey: .isFavored)
    }
}

extension Recipe {
    // 合并默认封面、历次实拍图库与旧图集字段，保证第一张默认封面永远可切回
    var photoChoices: [RecipePhotoChoice] {
        var result: [RecipePhotoChoice] = []
        var seen: Set<String> = []
        let galleryMap = Dictionary(
            (photoGallery ?? []).compactMap { item -> (String, RecipePhotoItem)? in
                let trimmed = item.image.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : (trimmed, item)
            },
            uniquingKeysWith: { first, _ in first }
        )

        if let cover = coverImage?.trimmingCharacters(in: .whitespacesAndNewlines), !cover.isEmpty {
            let match = galleryMap[cover]
            let fallbackCutout = (match?.cutoutImage?.isEmpty == false) ? match?.cutoutImage : nil
            let resolvedCutout = (cutoutImage?.isEmpty == false) ? cutoutImage : fallbackCutout
            result.append(RecipePhotoChoice(
                image: cover,
                cutoutImage: resolvedCutout,
                createdAt: match?.createdAt,
                isDefaultCover: true
            ))
            seen.insert(cover)
        }

        for item in photoGallery ?? [] {
            let img = item.image.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !img.isEmpty, seen.insert(img).inserted else { continue }
            result.append(RecipePhotoChoice(
                image: img,
                cutoutImage: item.cutoutImage?.isEmpty == false ? item.cutoutImage : nil,
                createdAt: item.createdAt,
                isDefaultCover: false
            ))
        }

        for raw in images ?? [] {
            let img = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !img.isEmpty, seen.insert(img).inserted else { continue }
            result.append(RecipePhotoChoice(
                image: img,
                cutoutImage: nil,
                createdAt: nil,
                isDefaultCover: false
            ))
        }
        return result
    }
}

// 列表分页结果
struct RecipeListResult: Codable {
    let total: Int
    let items: [Recipe]
}
