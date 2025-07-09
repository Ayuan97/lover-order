package main

import (
	"fmt"
	"log"

	"love-order-backend/internal/config"
	"love-order-backend/internal/model"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
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
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	log.Println("开始强制迁移数据库表结构...")

	// 删除所有表（谨慎操作）
	log.Println("删除现有表...")
	db.Exec("SET FOREIGN_KEY_CHECKS = 0")
	
	tables := []string{
		"family_invitations",
		"recipe_reviews", 
		"favorites",
		"order_items",
		"orders",
		"recipes",
		"recipe_categories",
		"users",
		"families",
	}
	
	for _, table := range tables {
		if err := db.Exec(fmt.Sprintf("DROP TABLE IF EXISTS %s", table)).Error; err != nil {
			log.Printf("删除表 %s 失败: %v", table, err)
		} else {
			log.Printf("删除表 %s 成功", table)
		}
	}
	
	db.Exec("SET FOREIGN_KEY_CHECKS = 1")

	// 重新创建所有表
	log.Println("重新创建表结构...")
	
	// 按依赖关系顺序迁移表
	migrationTables := []interface{}{
		&model.Family{},           // 1. 家庭表（无外键依赖）
		&model.User{},             // 2. 用户表（依赖families）
		&model.RecipeCategory{},   // 3. 菜谱分类表（依赖families）
		&model.Recipe{},           // 4. 菜谱表（依赖families, recipe_categories, users）
		&model.Order{},            // 5. 订单表（依赖users, families）
		&model.OrderItem{},        // 6. 订单详情表（依赖orders, recipes）
		&model.Favorite{},         // 7. 收藏表（依赖users, recipes）
		&model.RecipeReview{},     // 8. 评价表（依赖users, recipes, orders）
		&model.FamilyInvitation{}, // 9. 家庭邀请表（依赖families, users）
	}

	for _, table := range migrationTables {
		if err := db.AutoMigrate(table); err != nil {
			log.Fatalf("迁移表 %T 失败: %v", table, err)
		} else {
			log.Printf("迁移表 %T 成功", table)
		}
	}

	log.Println("数据库表结构强制迁移完成！")
	
	// 验证用户表结构
	log.Println("验证用户表结构...")
	var columns []struct {
		Field string `gorm:"column:Field"`
		Type  string `gorm:"column:Type"`
	}
	
	if err := db.Raw("SHOW COLUMNS FROM users").Scan(&columns).Error; err != nil {
		log.Printf("查询用户表结构失败: %v", err)
	} else {
		log.Println("用户表字段:")
		for _, col := range columns {
			log.Printf("  %s: %s", col.Field, col.Type)
		}
	}
}
