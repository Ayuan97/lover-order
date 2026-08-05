package main

import (
	"log"

	"gorm.io/gorm"
	"lover-order-backend/internal/config"
	"lover-order-backend/internal/model"
)

// 清理历史脏数据：跨家/失效 recipe_id、空菜名 dish、孤儿 planning 会话
func main() {
	cfg := config.LoadConfig("config.yaml")
	if _, err := model.InitDB(cfg); err != nil {
		log.Fatalf("数据库初始化失败：%v", err)
	}
	defer model.CloseDB()

	if err := cleanupForeignRecipeIDs(); err != nil {
		log.Fatalf("清理跨家 recipe_id 失败：%v", err)
	}
	if err := cleanupMissingRecipeIDs(); err != nil {
		log.Fatalf("清理缺失 recipe_id 失败：%v", err)
	}
	if err := cleanupEmptyNameDishes(); err != nil {
		log.Fatalf("清理空菜名 dish 失败：%v", err)
	}
	if err := cleanupOrphanPlanning(); err != nil {
		log.Fatalf("清理孤儿 planning 失败：%v", err)
	}
	log.Println("脏数据清理完成")
}

// 菜谱属于别的家：断开 recipe_id，保留菜名快照
func cleanupForeignRecipeIDs() error {
	res := model.DB.Exec(`
UPDATE meal_dishes md
INNER JOIN meal_sessions ms ON ms.id = md.meal_session_id AND ms.deleted_at IS NULL
INNER JOIN recipes r ON r.id = md.recipe_id AND r.deleted_at IS NULL
SET md.recipe_id = NULL
WHERE md.recipe_id IS NOT NULL
  AND r.household_id <> ms.household_id
`)
	if res.Error != nil {
		return res.Error
	}
	log.Printf("跨家 recipe_id 已清空：%d 行", res.RowsAffected)
	return nil
}

// 菜谱已删或不存在：断开 recipe_id
func cleanupMissingRecipeIDs() error {
	res := model.DB.Exec(`
UPDATE meal_dishes md
SET md.recipe_id = NULL
WHERE md.recipe_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM recipes r
    WHERE r.id = md.recipe_id AND r.deleted_at IS NULL
  )
`)
	if res.Error != nil {
		return res.Error
	}
	log.Printf("缺失 recipe_id 已清空：%d 行", res.RowsAffected)
	return nil
}

// 无菜名的无效行：先删关联单菜评价，再删 dish
func cleanupEmptyNameDishes() error {
	var ids []uint
	if err := model.DB.Model(&model.MealDish{}).
		Where("recipe_name = ? OR recipe_name IS NULL", "").
		Pluck("id", &ids).Error; err != nil {
		return err
	}
	if len(ids) == 0 {
		log.Printf("空菜名 dish：0 行")
		return nil
	}
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Unscoped().Where("meal_dish_id IN ?", ids).
			Delete(&model.MealDishReview{}).Error; err != nil {
			return err
		}
		return tx.Where("id IN ?", ids).Delete(&model.MealDish{}).Error
	})
	if err != nil {
		return err
	}
	log.Printf("空菜名 dish 已删除：%d 行", len(ids))
	return nil
}

// 同一家同一场景下，非最新的 planning 取消掉，避免 Current 之外的孤儿行
func cleanupOrphanPlanning() error {
	// MySQL 禁止 UPDATE 目标表直接出现在子查询 FROM，外包一层派生表
	res := model.DB.Exec(`
UPDATE meal_sessions
SET status = ?, updated_at = NOW()
WHERE id IN (
  SELECT id FROM (
    SELECT m1.id AS id
    FROM meal_sessions m1
    WHERE m1.status = ?
      AND m1.deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM meal_sessions m2
        WHERE m2.household_id = m1.household_id
          AND m2.scene = m1.scene
          AND m2.status IN (?, ?)
          AND m2.deleted_at IS NULL
          AND m2.id > m1.id
      )
  ) AS orphans
)
`, model.MealStatusCancelled, model.MealStatusPlanning,
		model.MealStatusPlanning, model.MealStatusConfirmed)
	if res.Error != nil {
		return res.Error
	}
	log.Printf("孤儿 planning 已取消：%d 行", res.RowsAffected)
	return nil
}
