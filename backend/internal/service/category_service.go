package service

import (
	"errors"
	"fmt"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
)

// CategoryService 菜谱分类业务
type CategoryService struct{}

// NewCategoryService 构造
func NewCategoryService() *CategoryService {
	return &CategoryService{}
}

// CategoryInput 分类入参
type CategoryInput struct {
	Name      string `json:"name" binding:"required"`
	Icon      string `json:"icon"`
	Color     string `json:"color"`
	SortOrder int    `json:"sort_order"`
}

// List 列出一个家的分类
func (s *CategoryService) List(householdID uint) ([]model.RecipeCategory, error) {
	var items []model.RecipeCategory
	if err := model.DB.Where("household_id = ? AND is_active = ?", householdID, true).
		Order("sort_order ASC, id ASC").Find(&items).Error; err != nil {
		return nil, err
	}
	return items, nil
}

// Create 新建分类
func (s *CategoryService) Create(householdID uint, in CategoryInput) (*model.RecipeCategory, error) {
	c := &model.RecipeCategory{
		Name:        in.Name,
		Icon:        in.Icon,
		Color:       in.Color,
		SortOrder:   in.SortOrder,
		HouseholdID: householdID,
		IsActive:    true,
	}
	if err := model.DB.Create(c).Error; err != nil {
		return nil, fmt.Errorf("创建分类失败：%w", err)
	}
	return c, nil
}

// Update 修改分类
func (s *CategoryService) Update(householdID, id uint, in CategoryInput) (*model.RecipeCategory, error) {
	var c model.RecipeCategory
	if err := model.DB.Where("id = ? AND household_id = ?", id, householdID).First(&c).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("分类不存在")
		}
		return nil, err
	}
	updates := map[string]any{
		"name":       in.Name,
		"icon":       in.Icon,
		"color":      in.Color,
		"sort_order": in.SortOrder,
	}
	if err := model.DB.Model(&c).Updates(updates).Error; err != nil {
		return nil, err
	}
	return &c, nil
}

// Delete 软删
func (s *CategoryService) Delete(householdID, id uint) error {
	res := model.DB.Where("id = ? AND household_id = ?", id, householdID).Delete(&model.RecipeCategory{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("分类不存在")
	}
	return nil
}
