package service

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"love-order-backend/internal/model"
)

// CategoryService 菜谱分类服务
type CategoryService struct{}

// NewCategoryService 创建菜谱分类服务
func NewCategoryService() *CategoryService {
	return &CategoryService{}
}

// CreateCategoryRequest 创建分类请求
type CreateCategoryRequest struct {
	Name      string `json:"name" binding:"required"`
	Icon      string `json:"icon"`
	Color     string `json:"color"`
	SortOrder int    `json:"sort_order"`
}

// UpdateCategoryRequest 更新分类请求
type UpdateCategoryRequest struct {
	Name      *string `json:"name"`
	Icon      *string `json:"icon"`
	Color     *string `json:"color"`
	SortOrder *int    `json:"sort_order"`
	IsActive  *bool   `json:"is_active"`
}

// CreateCategory 创建菜谱分类
func (s *CategoryService) CreateCategory(req *CreateCategoryRequest, familyID uint) (*model.RecipeCategory, error) {
	// 检查分类名称是否已存在
	var existingCategory model.RecipeCategory
	err := model.DB.Where("name = ? AND family_id = ?", req.Name, familyID).First(&existingCategory).Error
	if err == nil {
		return nil, errors.New("分类名称已存在")
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("检查分类名称失败: %v", err)
	}

	category := &model.RecipeCategory{
		Name:      req.Name,
		Icon:      req.Icon,
		Color:     req.Color,
		SortOrder: req.SortOrder,
		FamilyID:  familyID,
		IsActive:  true,
	}

	// 设置默认颜色
	if category.Color == "" {
		category.Color = "#FF8A65"
	}

	// 如果没有指定排序，设置为最大值+1
	if category.SortOrder == 0 {
		var maxOrder int
		model.DB.Model(&model.RecipeCategory{}).
			Where("family_id = ?", familyID).
			Select("COALESCE(MAX(sort_order), 0)").
			Scan(&maxOrder)
		category.SortOrder = maxOrder + 1
	}

	if err := model.DB.Create(category).Error; err != nil {
		return nil, fmt.Errorf("创建分类失败: %v", err)
	}

	return category, nil
}

// GetCategoryList 获取分类列表
func (s *CategoryService) GetCategoryList(familyID uint, includeInactive bool) ([]model.RecipeCategory, error) {
	var categories []model.RecipeCategory
	query := model.DB.Where("family_id = ?", familyID)

	if !includeInactive {
		query = query.Where("is_active = ?", true)
	}

	err := query.Order("sort_order ASC, created_at ASC").Find(&categories).Error
	if err != nil {
		return nil, fmt.Errorf("查询分类列表失败: %v", err)
	}

	return categories, nil
}

// GetCategoryByID 根据ID获取分类
func (s *CategoryService) GetCategoryByID(categoryID, familyID uint) (*model.RecipeCategory, error) {
	var category model.RecipeCategory
	err := model.DB.Where("id = ? AND family_id = ?", categoryID, familyID).First(&category).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("分类不存在")
		}
		return nil, fmt.Errorf("查询分类失败: %v", err)
	}

	return &category, nil
}

// UpdateCategory 更新分类
func (s *CategoryService) UpdateCategory(categoryID uint, req *UpdateCategoryRequest, familyID uint) error {
	// 查找分类
	var category model.RecipeCategory
	if err := model.DB.Where("id = ? AND family_id = ?", categoryID, familyID).First(&category).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("分类不存在")
		}
		return fmt.Errorf("查询分类失败: %v", err)
	}

	// 检查名称是否重复
	if req.Name != nil && *req.Name != category.Name {
		var existingCategory model.RecipeCategory
		err := model.DB.Where("name = ? AND family_id = ? AND id != ?", *req.Name, familyID, categoryID).First(&existingCategory).Error
		if err == nil {
			return errors.New("分类名称已存在")
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("检查分类名称失败: %v", err)
		}
	}

	// 准备更新数据
	updates := make(map[string]interface{})

	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.Icon != nil {
		updates["icon"] = *req.Icon
	}
	if req.Color != nil {
		updates["color"] = *req.Color
	}
	if req.SortOrder != nil {
		updates["sort_order"] = *req.SortOrder
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	if len(updates) == 0 {
		return errors.New("没有可更新的字段")
	}

	updates["updated_at"] = time.Now()

	// 更新分类
	if err := model.DB.Model(&category).Updates(updates).Error; err != nil {
		return fmt.Errorf("更新分类失败: %v", err)
	}

	return nil
}

// DeleteCategory 删除分类
func (s *CategoryService) DeleteCategory(categoryID, familyID uint) error {
	// 查找分类
	var category model.RecipeCategory
	if err := model.DB.Where("id = ? AND family_id = ?", categoryID, familyID).First(&category).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("分类不存在")
		}
		return fmt.Errorf("查询分类失败: %v", err)
	}

	// 检查是否有关联的菜谱
	var recipeCount int64
	if err := model.DB.Model(&model.Recipe{}).Where("category_id = ?", categoryID).Count(&recipeCount).Error; err != nil {
		return fmt.Errorf("检查菜谱关联失败: %v", err)
	}

	if recipeCount > 0 {
		return errors.New("该分类下还有菜谱，无法删除")
	}

	// 删除分类
	if err := model.DB.Delete(&category).Error; err != nil {
		return fmt.Errorf("删除分类失败: %v", err)
	}

	return nil
}

// UpdateCategorySortOrder 更新分类排序
func (s *CategoryService) UpdateCategorySortOrder(familyID uint, categoryOrders []map[string]interface{}) error {
	// 开始事务
	tx := model.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	for _, order := range categoryOrders {
		categoryID, ok1 := order["id"].(float64)
		sortOrder, ok2 := order["sort_order"].(float64)

		if !ok1 || !ok2 {
			tx.Rollback()
			return errors.New("无效的排序数据")
		}

		// 验证分类是否属于该家庭
		var category model.RecipeCategory
		if err := tx.Where("id = ? AND family_id = ?", uint(categoryID), familyID).First(&category).Error; err != nil {
			tx.Rollback()
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("分类不存在")
			}
			return fmt.Errorf("查询分类失败: %v", err)
		}

		// 更新排序
		if err := tx.Model(&category).Update("sort_order", int(sortOrder)).Error; err != nil {
			tx.Rollback()
			return fmt.Errorf("更新排序失败: %v", err)
		}
	}

	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("提交事务失败: %v", err)
	}

	return nil
}

// GetCategoryStats 获取分类统计信息
func (s *CategoryService) GetCategoryStats(familyID uint) ([]map[string]interface{}, error) {
	var stats []map[string]interface{}

	rows, err := model.DB.Raw(`
		SELECT 
			c.id,
			c.name,
			c.color,
			c.icon,
			COUNT(r.id) as recipe_count,
			COALESCE(SUM(r.view_count), 0) as total_views,
			COALESCE(SUM(r.order_count), 0) as total_orders
		FROM recipe_categories c
		LEFT JOIN recipes r ON c.id = r.category_id AND r.deleted_at IS NULL
		WHERE c.family_id = ? AND c.is_active = true
		GROUP BY c.id, c.name, c.color, c.icon
		ORDER BY c.sort_order ASC
	`, familyID).Rows()

	if err != nil {
		return nil, fmt.Errorf("查询分类统计失败: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var id uint
		var name, color, icon string
		var recipeCount, totalViews, totalOrders int64

		if err := rows.Scan(&id, &name, &color, &icon, &recipeCount, &totalViews, &totalOrders); err != nil {
			return nil, fmt.Errorf("扫描统计数据失败: %v", err)
		}

		stats = append(stats, map[string]interface{}{
			"id":           id,
			"name":         name,
			"color":        color,
			"icon":         icon,
			"recipe_count": recipeCount,
			"total_views":  totalViews,
			"total_orders": totalOrders,
		})
	}

	return stats, nil
}
