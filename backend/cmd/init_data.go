package main

import (
	"fmt"
	"log"
	"love-order-backend/internal/config"
	"love-order-backend/internal/model"
	"time"

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

	// 创建默认家庭
	family := &model.Family{
		ID:          1,
		Name:        "Love Order 测试家庭",
		InviteCode:  "TEST001",
		Avatar:      "",
		Description: "用于开发测试的默认家庭",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// 使用FirstOrCreate确保不重复创建
	result := db.Where("id = ?", 1).FirstOrCreate(family)
	if result.Error != nil {
		log.Fatal("Failed to create family:", result.Error)
	}
	log.Printf("Family created/found: %s (ID: %d)", family.Name, family.ID)

	// 创建默认用户
	user := &model.User{
		ID:        1,
		OpenID:    "test_openid_001",
		UnionID:   "",
		Nickname:  "测试用户",
		Avatar:    "",
		Gender:    1,
		Role:      "admin",
		FamilyID:  &family.ID,
		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	result = db.Where("id = ?", 1).FirstOrCreate(user)
	if result.Error != nil {
		log.Fatal("Failed to create user:", result.Error)
	}
	log.Printf("User created/found: %s (ID: %d)", user.Nickname, user.ID)

	// 创建默认分类
	categories := []model.RecipeCategory{
		{
			ID:        1,
			FamilyID:  family.ID,
			Name:      "热门推荐",
			Icon:      "🔥",
			Color:     "#FF8A65",
			SortOrder: 1,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        2,
			FamilyID:  family.ID,
			Name:      "汤品",
			Icon:      "🍲",
			Color:     "#81C784",
			SortOrder: 2,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        3,
			FamilyID:  family.ID,
			Name:      "素食",
			Icon:      "🥬",
			Color:     "#4CAF50",
			SortOrder: 3,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        4,
			FamilyID:  family.ID,
			Name:      "甜品",
			Icon:      "🍰",
			Color:     "#F8BBD9",
			SortOrder: 4,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        5,
			FamilyID:  family.ID,
			Name:      "川菜",
			Icon:      "🌶️",
			Color:     "#FF5722",
			SortOrder: 5,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        6,
			FamilyID:  family.ID,
			Name:      "粤菜",
			Icon:      "🦐",
			Color:     "#00BCD4",
			SortOrder: 6,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        7,
			FamilyID:  family.ID,
			Name:      "湘菜",
			Icon:      "🌶️",
			Color:     "#E91E63",
			SortOrder: 7,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        8,
			FamilyID:  family.ID,
			Name:      "鲁菜",
			Icon:      "🐟",
			Color:     "#3F51B5",
			SortOrder: 8,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        9,
			FamilyID:  family.ID,
			Name:      "早餐",
			Icon:      "🥞",
			Color:     "#FFC107",
			SortOrder: 9,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:        10,
			FamilyID:  family.ID,
			Name:      "夜宵",
			Icon:      "🌙",
			Color:     "#9C27B0",
			SortOrder: 10,
			IsActive:  true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
	}

	for _, category := range categories {
		result = db.Where("id = ?", category.ID).FirstOrCreate(&category)
		if result.Error != nil {
			log.Printf("Failed to create category %s: %v", category.Name, result.Error)
		} else {
			log.Printf("Category created/found: %s (ID: %d)", category.Name, category.ID)
		}
	}

	// 创建默认菜谱
	categoryID1 := uint(1)
	categoryID2 := uint(2)

	recipes := []model.Recipe{
		{
			ID:          1,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID1,
			Name:        "红烧肉",
			Description: "肥瘦相间，入口即化的经典红烧肉",
			Ingredients: model.JSON(`["五花肉500g", "生抽3勺", "老抽1勺", "冰糖30g", "料酒2勺", "葱段", "姜片", "八角2个"]`),
			Steps:       model.JSON(`["五花肉切块，冷水下锅焯水", "热锅下肉块煸炒出油", "加入冰糖炒糖色", "加入生抽老抽料酒", "加水没过肉块", "大火烧开转小火炖1小时", "大火收汁即可"]`),
			CookingTime: 60,
			Servings:    4,
			Difficulty:  "hard",
			Tags:        "下饭菜,经典菜",
			Image:       "",
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
		{
			ID:          2,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID1,
			Name:        "宫保鸡丁",
			Description: "酸甜微辣，嫩滑爽口的川菜经典",
			Ingredients: model.JSON(`["鸡胸肉300g", "花生米100g", "干辣椒10个", "花椒1勺", "葱白", "蒜瓣", "生抽", "老抽", "醋", "糖", "淀粉"]`),
			Steps:       model.JSON(`["鸡肉切丁腌制", "花生米炸熟", "热锅爆香干辣椒花椒", "下鸡丁炒至变色", "调味炒匀", "最后加入花生米即可"]`),
			CookingTime: 30,
			Servings:    3,
			Difficulty:  "medium",
			Tags:        "川菜,下饭菜",
			Image:       "",
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
		{
			ID:          3,
			FamilyID:    family.ID,
			CreatedBy:   user.ID,
			CategoryID:  &categoryID2,
			Name:        "番茄鸡蛋汤",
			Description: "酸甜开胃，营养丰富的家常汤",
			Ingredients: model.JSON(`["番茄2个", "鸡蛋2个", "葱花", "盐", "糖", "香油"]`),
			Steps:       model.JSON(`["番茄去皮切块", "鸡蛋打散", "热锅炒番茄出汁", "加水烧开", "倒入蛋液", "调味即可"]`),
			CookingTime: 15,
			Servings:    2,
			Difficulty:  "easy",
			Tags:        "清淡,开胃",
			Image:       "",
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
	}

	for _, recipe := range recipes {
		result = db.Where("id = ?", recipe.ID).FirstOrCreate(&recipe)
		if result.Error != nil {
			log.Printf("Failed to create recipe %s: %v", recipe.Name, result.Error)
		} else {
			log.Printf("Recipe created/found: %s (ID: %d)", recipe.Name, recipe.ID)
		}
	}

	log.Println("数据初始化完成！")
}
