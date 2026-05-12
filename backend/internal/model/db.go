package model

import (
	"fmt"
	"log"
	"time"

	"lover-order-backend/internal/config"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB 全局数据库句柄
var DB *gorm.DB

// InitDB 初始化 GORM 与连接池
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
		return nil, fmt.Errorf("连接数据库失败：%w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("获取底层 sql.DB 失败：%w", err)
	}

	sqlDB.SetMaxIdleConns(cfg.Database.MaxIdleConns)
	sqlDB.SetMaxOpenConns(cfg.Database.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.Database.ConnMaxLifetime) * time.Second)

	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("数据库 ping 失败：%w", err)
	}

	DB = db
	log.Println("数据库连接成功")
	return db, nil
}

// AutoMigrate 迁移所有表 按依赖顺序
func AutoMigrate() error {
	if DB == nil {
		return fmt.Errorf("数据库未初始化")
	}

	tables := []any{
		&Household{},
		&User{},
		&HouseholdInvite{},
		&RecipeCategory{},
		&Recipe{},
		&Favorite{},
		&MealSession{},
		&MealDish{},
		&MealReview{},
	}

	for _, t := range tables {
		if err := DB.AutoMigrate(t); err != nil {
			return fmt.Errorf("迁移 %T 失败：%w", t, err)
		}
	}

	log.Println("数据库迁移完成")
	return nil
}

// CloseDB 关闭连接
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
