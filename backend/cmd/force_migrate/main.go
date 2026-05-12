package main

import (
	"log"

	"lover-order-backend/internal/config"
	"lover-order-backend/internal/model"
)

// 强制重建所有业务表 会清空已有数据 仅供开发期使用
func main() {
	cfg := config.LoadConfig("config.yaml")
	if _, err := model.InitDB(cfg); err != nil {
		log.Fatalf("数据库初始化失败：%v", err)
	}
	defer model.CloseDB()

	tables := []any{
		&model.MealReview{},
		&model.MealDish{},
		&model.MealSession{},
		&model.Favorite{},
		&model.Recipe{},
		&model.RecipeCategory{},
		&model.HouseholdInvite{},
		&model.User{},
		&model.Household{},
	}
	for _, t := range tables {
		if err := model.DB.Migrator().DropTable(t); err != nil {
			log.Printf("删除表 %T 失败：%v", t, err)
		}
	}
	log.Println("旧表已清空")

	if err := model.AutoMigrate(); err != nil {
		log.Fatalf("重建表失败：%v", err)
	}
	log.Println("重建完成")
}
