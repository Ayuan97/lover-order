package service

import (
	"errors"
	"fmt"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
)

// RecipeService 菜谱业务
type RecipeService struct{}

// NewRecipeService 构造
func NewRecipeService() *RecipeService {
	return &RecipeService{}
}

// RecipeInput 创建或更新菜谱入参
type RecipeInput struct {
	Name        string           `json:"name" binding:"required"`
	Description string           `json:"description"`
	CoverImage  string           `json:"cover_image"`
	Images      []string         `json:"images"`
	CategoryID  *uint            `json:"category_id"`
	CookingTime int              `json:"cooking_time"`
	Difficulty  string           `json:"difficulty"`
	Servings    int              `json:"servings"`
	Ingredients []map[string]any `json:"ingredients"`
	Steps       []map[string]any `json:"steps"`
	Tips        string           `json:"tips"`
	Tags        []string         `json:"tags"`
	MoodTags    []string         `json:"mood_tags"`
	SceneTags   []string         `json:"scene_tags"`
}

// ListQuery 列表筛选
type ListQuery struct {
	CategoryID *uint
	Mood       string
	Scene      string
	Keyword    string
	Favorite   bool
	UserID     uint
	Page       int
	PageSize   int
}

// ListResult 列表结果
type ListResult struct {
	Total int64          `json:"total"`
	Items []model.Recipe `json:"items"`
}

// List 列出菜谱
func (s *RecipeService) List(householdID uint, q ListQuery) (*ListResult, error) {
	if q.Page <= 0 {
		q.Page = 1
	}
	if q.PageSize <= 0 || q.PageSize > 100 {
		q.PageSize = 20
	}

	tx := model.DB.Model(&model.Recipe{}).
		Where("household_id = ? AND is_archived = ?", householdID, false)

	if q.CategoryID != nil {
		tx = tx.Where("category_id = ?", *q.CategoryID)
	}
	if q.Keyword != "" {
		kw := "%" + q.Keyword + "%"
		tx = tx.Where("name LIKE ? OR description LIKE ?", kw, kw)
	}
	if q.Mood != "" {
		tx = tx.Where("JSON_CONTAINS(mood_tags, JSON_QUOTE(?))", q.Mood)
	}
	if q.Scene != "" {
		tx = tx.Where("JSON_CONTAINS(scene_tags, JSON_QUOTE(?))", q.Scene)
	}
	if q.Favorite && q.UserID > 0 {
		tx = tx.Joins("JOIN favorites ON favorites.recipe_id = recipes.id AND favorites.user_id = ?", q.UserID)
	}

	var total int64
	if err := tx.Count(&total).Error; err != nil {
		return nil, err
	}

	var items []model.Recipe
	if err := tx.Preload("Category").
		Order("last_used_at DESC, id DESC").
		Offset((q.Page - 1) * q.PageSize).Limit(q.PageSize).
		Find(&items).Error; err != nil {
		return nil, err
	}
	return &ListResult{Total: total, Items: items}, nil
}

// Get 取菜谱详情并自增浏览数
func (s *RecipeService) Get(householdID, id uint) (*model.Recipe, error) {
	var r model.Recipe
	if err := model.DB.Where("id = ? AND household_id = ?", id, householdID).
		Preload("Category").First(&r).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("菜谱不存在")
		}
		return nil, err
	}
	_ = r.IncrViewCount()
	return &r, nil
}

// Create 新建菜谱
func (s *RecipeService) Create(householdID, userID uint, in RecipeInput) (*model.Recipe, error) {
	if in.Difficulty == "" {
		in.Difficulty = "easy"
	}
	if in.Servings == 0 {
		in.Servings = 2
	}
	r := &model.Recipe{
		Name:        in.Name,
		Description: in.Description,
		CoverImage:  in.CoverImage,
		CategoryID:  in.CategoryID,
		CookingTime: in.CookingTime,
		Difficulty:  in.Difficulty,
		Servings:    in.Servings,
		Tips:        in.Tips,
		HouseholdID: householdID,
		CreatedBy:   userID,
	}
	if err := applyRecipeJSON(r, in); err != nil {
		return nil, err
	}
	if err := model.DB.Create(r).Error; err != nil {
		return nil, fmt.Errorf("创建菜谱失败：%w", err)
	}
	return r, nil
}

// Update 更新菜谱
func (s *RecipeService) Update(householdID, id uint, in RecipeInput) (*model.Recipe, error) {
	var r model.Recipe
	if err := model.DB.Where("id = ? AND household_id = ?", id, householdID).First(&r).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("菜谱不存在")
		}
		return nil, err
	}
	r.Name = in.Name
	r.Description = in.Description
	r.CoverImage = in.CoverImage
	r.CategoryID = in.CategoryID
	r.CookingTime = in.CookingTime
	if in.Difficulty != "" {
		r.Difficulty = in.Difficulty
	}
	if in.Servings > 0 {
		r.Servings = in.Servings
	}
	r.Tips = in.Tips
	if err := applyRecipeJSON(&r, in); err != nil {
		return nil, err
	}
	if err := model.DB.Save(&r).Error; err != nil {
		return nil, err
	}
	return &r, nil
}

// Delete 软删
func (s *RecipeService) Delete(householdID, id uint) error {
	res := model.DB.Where("id = ? AND household_id = ?", id, householdID).Delete(&model.Recipe{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("菜谱不存在")
	}
	return nil
}

// ToggleFavorite 切换收藏
func (s *RecipeService) ToggleFavorite(userID, householdID, recipeID uint) (bool, error) {
	var r model.Recipe
	if err := model.DB.Where("id = ? AND household_id = ?", recipeID, householdID).First(&r).Error; err != nil {
		return false, errors.New("菜谱不存在")
	}
	var existing model.Favorite
	err := model.DB.Where("user_id = ? AND recipe_id = ?", userID, recipeID).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		if err := model.DB.Create(&model.Favorite{UserID: userID, RecipeID: recipeID}).Error; err != nil {
			return false, err
		}
		return true, nil
	}
	if err != nil {
		return false, err
	}
	if err := model.DB.Unscoped().Delete(&existing).Error; err != nil {
		return false, err
	}
	return false, nil
}

func applyRecipeJSON(r *model.Recipe, in RecipeInput) error {
	if in.Images != nil {
		if err := r.SetImages(in.Images); err != nil {
			return err
		}
	}
	if in.Tags != nil {
		if err := r.SetTags(in.Tags); err != nil {
			return err
		}
	}
	if in.MoodTags != nil {
		for _, m := range in.MoodTags {
			if !isValidMood(m) {
				return fmt.Errorf("mood_tags 含非法值：%s", m)
			}
		}
		if err := r.SetMoodTags(in.MoodTags); err != nil {
			return err
		}
	}
	if in.SceneTags != nil {
		for _, sc := range in.SceneTags {
			if !isValidScene(sc) {
				return fmt.Errorf("scene_tags 含非法值：%s", sc)
			}
		}
		if err := r.SetSceneTags(in.SceneTags); err != nil {
			return err
		}
	}
	if in.Ingredients != nil {
		if err := r.SetIngredients(in.Ingredients); err != nil {
			return err
		}
	}
	if in.Steps != nil {
		if err := r.SetSteps(in.Steps); err != nil {
			return err
		}
	}
	return nil
}
