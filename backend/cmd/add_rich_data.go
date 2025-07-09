package main

import (
	"fmt"
	"log"
	"love-order-backend/internal/config"
	"love-order-backend/internal/model"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	// 加载配置
	cfg := config.LoadConfig("config.yaml")

	// 构建数据库连接字符串
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=%s&parseTime=%t&loc=%s",
		cfg.Database.Username,
		cfg.Database.Password,
		cfg.Database.Host,
		cfg.Database.Port,
		cfg.Database.Database,
		cfg.Database.Charset,
		cfg.Database.ParseTime,
		cfg.Database.Loc,
	)

	// 连接数据库
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	log.Println("开始添加丰富的测试数据...")

	// 获取现有的家庭ID
	var family model.Family
	if err := db.First(&family).Error; err != nil {
		log.Fatal("未找到家庭数据，请先运行 init_data.go")
	}

	// 获取现有的用户ID
	var user model.User
	if err := db.First(&user).Error; err != nil {
		log.Fatal("未找到用户数据，请先运行 init_data.go")
	}

	// 添加更多分类
	additionalCategories := []model.RecipeCategory{
		{
			ID:        11,
			FamilyID:  family.ID,
			Name:      "湘菜",
			Icon:      "🌶️",
			Color:     "#E91E63",
			SortOrder: 11,
			IsActive:  true,
		},
		{
			ID:        12,
			FamilyID:  family.ID,
			Name:      "鲁菜",
			Icon:      "🐟",
			Color:     "#3F51B5",
			SortOrder: 12,
			IsActive:  true,
		},
	}

	for _, category := range additionalCategories {
		result := db.Where("id = ?", category.ID).FirstOrCreate(&category)
		if result.Error != nil {
			log.Printf("Failed to create category %s: %v", category.Name, result.Error)
		} else {
			log.Printf("Category created/found: %s (ID: %d)", category.Name, category.ID)
		}
	}

	// 添加丰富的菜谱数据
	categoryID1 := uint(1) // 热门推荐
	categoryID2 := uint(2) // 汤品
	categoryID3 := uint(3) // 素食
	categoryID4 := uint(4) // 甜品
	categoryID5 := uint(5) // 川菜
	categoryID6 := uint(6) // 粤菜
	categoryID9 := uint(9) // 早餐

	richRecipes := []model.Recipe{
		// 热门推荐
		{
			ID:          21,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID1,
			Name:        "糖醋里脊",
			Description: "酸甜可口，外酥内嫩的经典菜品",
			Ingredients: model.JSON(`["猪里脊300g", "番茄酱3勺", "白醋2勺", "白糖2勺", "生抽1勺", "淀粉", "鸡蛋1个", "面粉"]`),
			Steps:       model.JSON(`["里脊切条腌制", "裹蛋液和淀粉炸至金黄", "调糖醋汁", "热锅炒糖醋汁", "倒入里脊炒匀即可"]`),
			CookingTime: 35,
			Servings:    3,
			Difficulty:  "medium",
			Tags:        "酸甜,家常菜",
			Price:       24.80,
			IsAvailable: true,
			IsFeatured:  false,
			ViewCount:   98,
			LikeCount:   65,
			OrderCount:  32,
		},
		{
			ID:          22,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID1,
			Name:        "可乐鸡翅",
			Description: "甜香可口，老少皆宜的家常菜",
			Ingredients: model.JSON(`["鸡翅8个", "可乐1罐", "生抽2勺", "老抽1勺", "料酒1勺", "姜片", "葱段"]`),
			Steps:       model.JSON(`["鸡翅划刀焯水", "热锅煎鸡翅至两面金黄", "倒入可乐没过鸡翅", "加调料大火烧开", "转小火炖20分钟", "大火收汁即可"]`),
			CookingTime: 40,
			Servings:    3,
			Difficulty:  "easy",
			Tags:        "家常菜,甜味",
			Price:       18.80,
			IsAvailable: true,
			IsFeatured:  true,
			ViewCount:   187,
			LikeCount:   112,
			OrderCount:  67,
		},
		// 汤品
		{
			ID:          23,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID2,
			Name:        "冬瓜排骨汤",
			Description: "清香甘甜，滋补养颜的营养汤品",
			Ingredients: model.JSON(`["排骨500g", "冬瓜300g", "姜片", "葱段", "料酒", "盐", "胡椒粉"]`),
			Steps:       model.JSON(`["排骨焯水洗净", "砂锅加水放入排骨和姜片", "大火烧开转小火炖1小时", "加入冬瓜块", "继续炖20分钟", "调味即可"]`),
			CookingTime: 90,
			Servings:    4,
			Difficulty:  "easy",
			Tags:        "清汤,滋补",
			Price:       16.80,
			IsAvailable: true,
			IsFeatured:  true,
			ViewCount:   76,
			LikeCount:   42,
			OrderCount:  28,
		},
		{
			ID:          24,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID2,
			Name:        "紫菜蛋花汤",
			Description: "清淡鲜美，简单快手的家常汤",
			Ingredients: model.JSON(`["紫菜20g", "鸡蛋2个", "虾皮10g", "香菜", "盐", "香油", "胡椒粉"]`),
			Steps:       model.JSON(`["紫菜洗净撕成小片", "鸡蛋打散", "锅内加水烧开", "放入紫菜和虾皮", "倒入蛋液搅拌", "调味撒香菜即可"]`),
			CookingTime: 10,
			Servings:    2,
			Difficulty:  "easy",
			Tags:        "清淡,快手",
			Price:       6.80,
			IsAvailable: true,
			IsFeatured:  false,
			ViewCount:   54,
			LikeCount:   28,
			OrderCount:  15,
		},
		// 素食
		{
			ID:          25,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID3,
			Name:        "地三鲜",
			Description: "东北经典素菜，软糯香甜",
			Ingredients: model.JSON(`["茄子2个", "土豆2个", "青椒2个", "生抽", "老抽", "糖", "蒜末", "淀粉"]`),
			Steps:       model.JSON(`["茄子土豆切块过油", "青椒切块", "热锅爆香蒜末", "下茄子土豆翻炒", "加调料和青椒", "炒匀即可"]`),
			CookingTime: 25,
			Servings:    3,
			Difficulty:  "medium",
			Tags:        "东北菜,素食",
			Price:       14.80,
			IsAvailable: true,
			IsFeatured:  false,
			ViewCount:   87,
			LikeCount:   43,
			OrderCount:  26,
		},
		// 甜品
		{
			ID:          26,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID4,
			Name:        "银耳莲子汤",
			Description: "滋阴润燥，美容养颜的甜品",
			Ingredients: model.JSON(`["银耳1朵", "莲子50g", "红枣6个", "冰糖30g", "枸杞10g"]`),
			Steps:       model.JSON(`["银耳提前泡发撕小朵", "莲子去芯", "砂锅加水放入银耳莲子", "大火烧开转小火炖1小时", "加红枣冰糖", "炖30分钟加枸杞即可"]`),
			CookingTime: 120,
			Servings:    3,
			Difficulty:  "easy",
			Tags:        "甜品,滋补",
			Price:       12.80,
			IsAvailable: true,
			IsFeatured:  true,
			ViewCount:   89,
			LikeCount:   56,
			OrderCount:  29,
		},
		// 川菜
		{
			ID:          27,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID5,
			Name:        "水煮鱼",
			Description: "麻辣鲜香，嫩滑爽口的川菜经典",
			Ingredients: model.JSON(`["草鱼1条", "豆芽菜200g", "白菜100g", "豆瓣酱3勺", "干辣椒20个", "花椒2勺", "蒜瓣", "姜片", "葱段"]`),
			Steps:       model.JSON(`["鱼片成片腌制", "豆芽白菜焯水垫底", "炒豆瓣酱出红油", "加水烧开下鱼片", "煮2分钟盛起", "撒辣椒花椒", "浇热油即可"]`),
			CookingTime: 45,
			Servings:    4,
			Difficulty:  "hard",
			Tags:        "川菜,麻辣",
			Price:       32.80,
			IsAvailable: true,
			IsFeatured:  true,
			ViewCount:   145,
			LikeCount:   78,
			OrderCount:  42,
		},
		// 粤菜
		{
			ID:          28,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID6,
			Name:        "白切鸡",
			Description: "清淡鲜美，原汁原味的粤菜经典",
			Ingredients: model.JSON(`["土鸡1只", "姜片", "葱段", "料酒", "盐", "生抽", "香油", "蒜蓉", "姜蓉"]`),
			Steps:       model.JSON(`["整鸡洗净", "锅内加水放姜葱料酒", "水开下鸡煮15分钟", "关火焖10分钟", "捞起过冰水", "切块装盘", "调蘸料即可"]`),
			CookingTime: 40,
			Servings:    4,
			Difficulty:  "medium",
			Tags:        "粤菜,清淡",
			Price:       28.80,
			IsAvailable: true,
			IsFeatured:  true,
			ViewCount:   98,
			LikeCount:   54,
			OrderCount:  31,
		},
		// 早餐
		{
			ID:          29,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID9,
			Name:        "小笼包",
			Description: "皮薄馅大，汤汁丰富的经典早餐",
			Ingredients: model.JSON(`["面粉300g", "猪肉馅200g", "皮冻100g", "韭菜", "生抽", "老抽", "料酒", "盐", "糖", "香油"]`),
			Steps:       model.JSON(`["和面醒发", "调肉馅加皮冻", "擀皮包馅", "蒸笼刷油", "包子上锅蒸15分钟", "关火焖3分钟即可"]`),
			CookingTime: 60,
			Servings:    4,
			Difficulty:  "hard",
			Tags:        "早餐,包子",
			Price:       2.50,
			IsAvailable: true,
			IsFeatured:  true,
			ViewCount:   156,
			LikeCount:   89,
			OrderCount:  78,
		},
		{
			ID:          30,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID9,
			Name:        "豆浆油条",
			Description: "经典搭配，温暖的早餐回忆",
			Ingredients: model.JSON(`["黄豆100g", "面粉300g", "酵母3g", "盐", "糖", "小苏打", "油"]`),
			Steps:       model.JSON(`["黄豆提前泡发", "豆浆机打豆浆", "面粉和成油条面", "醒发2小时", "搓条下锅炸至金黄", "配豆浆享用"]`),
			CookingTime: 45,
			Servings:    3,
			Difficulty:  "medium",
			Tags:        "早餐,传统",
			Price:       8.80,
			IsAvailable: true,
			IsFeatured:  false,
			ViewCount:   134,
			LikeCount:   76,
			OrderCount:  45,
		},
	}

	for _, recipe := range richRecipes {
		result := db.Where("id = ?", recipe.ID).FirstOrCreate(&recipe)
		if result.Error != nil {
			log.Printf("Failed to create recipe %s: %v", recipe.Name, result.Error)
		} else {
			log.Printf("Recipe created/found: %s (ID: %d)", recipe.Name, recipe.ID)
		}
	}

	log.Println("丰富的测试数据添加完成！")
	log.Printf("总共添加了 %d 道菜谱", len(richRecipes))
}
