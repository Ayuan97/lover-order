package model

import (
	"fmt"
	"log"
	"time"

	"love-order-backend/internal/config"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// InitDB 初始化数据库连接
func InitDB(cfg *config.Config) (*gorm.DB, error) {
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

	// 配置GORM日志
	var logLevel logger.LogLevel
	switch cfg.Log.Level {
	case "debug":
		logLevel = logger.Info
	case "info":
		logLevel = logger.Warn
	default:
		logLevel = logger.Error
	}

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
		NowFunc: func() time.Time {
			return time.Now().Local()
		},
	})

	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %v", err)
	}

	// 获取底层的sql.DB对象进行连接池配置
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get underlying sql.DB: %v", err)
	}

	// 设置连接池参数
	sqlDB.SetMaxIdleConns(cfg.Database.MaxIdleConns)
	sqlDB.SetMaxOpenConns(cfg.Database.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.Database.ConnMaxLifetime) * time.Second)

	// 测试连接
	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}

	DB = db
	log.Println("Database connected successfully")
	return db, nil
}

// AutoMigrate 自动迁移数据库表结构
func AutoMigrate() error {
	if DB == nil {
		return fmt.Errorf("database not initialized")
	}

	// 按依赖关系顺序迁移表
	tables := []interface{}{
		&Family{},           // 1. 家庭表（无外键依赖）
		&User{},             // 2. 用户表（依赖families）
		&RecipeCategory{},   // 3. 菜谱分类表（依赖families）
		&Recipe{},           // 4. 菜谱表（依赖families, recipe_categories, users）
		&Order{},            // 5. 订单表（依赖users, families）
		&OrderItem{},        // 6. 订单详情表（依赖orders, recipes）
		&Favorite{},         // 7. 收藏表（依赖users, recipes）
		&RecipeReview{},     // 8. 评价表（依赖users, recipes, orders）
		&FamilyInvitation{}, // 9. 家庭邀请表（依赖families, users）
	}

	for _, table := range tables {
		if err := DB.AutoMigrate(table); err != nil {
			return fmt.Errorf("failed to migrate table %T: %v", table, err)
		}
	}

	log.Println("Database migration completed successfully")
	return nil
}

// CloseDB 关闭数据库连接
func CloseDB() error {
	if DB == nil {
		return nil
	}

	sqlDB, err := DB.DB()
	if err != nil {
		return err
	}

	return sqlDB.Close()
}
