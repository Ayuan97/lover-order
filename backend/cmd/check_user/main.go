package main

import (
	"fmt"
	"log"

	"love-order-backend/internal/config"
	"love-order-backend/internal/model"
)

func main() {
	// 加载配置
	cfg := config.LoadConfig("config.yaml")
	if cfg == nil {
		log.Fatal("Failed to load config")
	}

	// 连接数据库
	db, err := model.InitDB(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	model.DB = db

	// 查询所有用户
	var users []model.User
	err = model.DB.Find(&users).Error
	if err != nil {
		log.Fatalf("Failed to query users: %v", err)
	}

	fmt.Printf("Found %d users in database:\n", len(users))
	fmt.Println("=====================================")

	for i, user := range users {
		fmt.Printf("User %d:\n", i+1)
		fmt.Printf("  ID: %d\n", user.ID)
		fmt.Printf("  OpenID: %s\n", user.OpenID)
		fmt.Printf("  UnionID: %s\n", user.UnionID)
		fmt.Printf("  Nickname: %s\n", user.Nickname)
		fmt.Printf("  Avatar: %s\n", user.Avatar)
		fmt.Printf("  Gender: %d\n", user.Gender)
		fmt.Printf("  Role: %s\n", user.Role)
		fmt.Printf("  FamilyID: %v\n", user.FamilyID)
		fmt.Printf("  IsActive: %t\n", user.IsActive)
		fmt.Printf("  CreatedAt: %s\n", user.CreatedAt)
		fmt.Printf("  UpdatedAt: %s\n", user.UpdatedAt)
		fmt.Println("-------------------------------------")
	}
}
