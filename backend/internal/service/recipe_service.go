package service

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"love-order-backend/internal/model"

	"gorm.io/gorm"
)

// RecipeService 菜谱服务
type RecipeService struct{}

// NewRecipeService 创建菜谱服务
func NewRecipeService() *RecipeService {
	return &RecipeService{}
}

// CreateRecipeRequest 创建菜谱请求
type CreateRecipeRequest struct {
	Name          string                   `json:"name" binding:"required"`
	Description   string                   `json:"description"`
	Image         string                   `json:"image"`
	Images        []string                 `json:"images"`
	Price         float64                  `json:"price"`
	CategoryID    *uint                    `json:"category_id"`
	CookingTime   int                      `json:"cooking_time"`
	Difficulty    string                   `json:"difficulty"`
	Servings      int                      `json:"servings"`
	Ingredients   []map[string]interface{} `json:"ingredients"`
	Steps         []map[string]interface{} `json:"steps"`
	NutritionInfo map[string]interface{}   `json:"nutrition_info"`
	Tags          string                   `json:"tags"`
	IsAvailable   bool                     `json:"is_available"`
	IsFeatured    bool                     `json:"is_featured"`
}

// UpdateRecipeRequest 更新菜谱请求
type UpdateRecipeRequest struct {
	Name          *string                  `json:"name"`
	Description   *string                  `json:"description"`
	Image         *string                  `json:"image"`
	Images        []string                 `json:"images"`
	Price         *float64                 `json:"price"`
	CategoryID    *uint                    `json:"category_id"`
	CookingTime   *int                     `json:"cooking_time"`
	Difficulty    *string                  `json:"difficulty"`
	Servings      *int                     `json:"servings"`
	Ingredients   []map[string]interface{} `json:"ingredients"`
	Steps         []map[string]interface{} `json:"steps"`
	NutritionInfo map[string]interface{}   `json:"nutrition_info"`
	Tags          *string                  `json:"tags"`
	IsAvailable   *bool                    `json:"is_available"`
	IsFeatured    *bool                    `json:"is_featured"`
}

// RecipeListRequest 菜谱列表请求
type RecipeListRequest struct {
	Page       int    `form:"page"`
	Size       int    `form:"size"`
	CategoryID *uint  `form:"category_id"`
	Keyword    string `form:"keyword"`
	Difficulty string `form:"difficulty"`
	Tags       string `form:"tags"`
	Available  *bool  `form:"available"`
	Featured   *bool  `form:"featured"`
	SortBy     string `form:"sort_by"`    // name, created_at, view_count, like_count, order_count
	SortOrder  string `form:"sort_order"` // asc, desc
}

// RecipeListResponse 菜谱列表响应
type RecipeListResponse struct {
	List  []model.Recipe `json:"list"`
	Total int64          `json:"total"`
	Page  int            `json:"page"`
	Size  int            `json:"size"`
}

// CreateRecipe 创建菜谱
func (s *RecipeService) CreateRecipe(req *CreateRecipeRequest, userID, familyID uint) (*model.Recipe, error) {
	// 验证分类是否存在且属于同一家庭
	if req.CategoryID != nil {
		var category model.RecipeCategory
		if err := model.DB.Where("id = ? AND family_id = ?", *req.CategoryID, familyID).First(&category).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, errors.New("菜谱分类不存在")
			}
			return nil, fmt.Errorf("查询菜谱分类失败: %v", err)
		}
	}

	// 验证难度值
	validDifficulties := map[string]bool{"easy": true, "medium": true, "hard": true}
	if req.Difficulty != "" && !validDifficulties[req.Difficulty] {
		return nil, errors.New("无效的难度等级")
	}

	recipe := &model.Recipe{
		Name:        req.Name,
		Description: req.Description,
		Image:       req.Image,
		Price:       req.Price,
		CategoryID:  req.CategoryID,
		CookingTime: req.CookingTime,
		Difficulty:  req.Difficulty,
		Servings:    req.Servings,
		Tags:        req.Tags,
		FamilyID:    familyID,
		CreatedBy:   userID,
		IsAvailable: req.IsAvailable,
		IsFeatured:  req.IsFeatured,
	}

	// 设置默认值
	if recipe.Difficulty == "" {
		recipe.Difficulty = "easy"
	}
	if recipe.Servings == 0 {
		recipe.Servings = 1
	}

	// 设置图片数组
	if len(req.Images) > 0 {
		if err := recipe.SetImagesSlice(req.Images); err != nil {
			return nil, fmt.Errorf("设置图片数组失败: %v", err)
		}
	}

	// 设置食材数组
	if len(req.Ingredients) > 0 {
		if err := recipe.SetIngredientsSlice(req.Ingredients); err != nil {
			return nil, fmt.Errorf("设置食材数组失败: %v", err)
		}
	}

	// 设置步骤数组
	if len(req.Steps) > 0 {
		if err := recipe.SetStepsSlice(req.Steps); err != nil {
			return nil, fmt.Errorf("设置步骤数组失败: %v", err)
		}
	}

	// 设置营养信息
	if req.NutritionInfo != nil {
		nutritionData, err := json.Marshal(req.NutritionInfo)
		if err != nil {
			return nil, fmt.Errorf("设置营养信息失败: %v", err)
		}
		recipe.NutritionInfo = model.JSON(nutritionData)
	}

	// 创建菜谱
	if err := model.DB.Create(recipe).Error; err != nil {
		return nil, fmt.Errorf("创建菜谱失败: %v", err)
	}

	// 预加载关联数据
	model.DB.Preload("Category").Preload("Creator").First(recipe, recipe.ID)

	return recipe, nil
}

// GetRecipeList 获取菜谱列表
func (s *RecipeService) GetRecipeList(req *RecipeListRequest, familyID uint) (*RecipeListResponse, error) {
	// 设置默认值
	if req.Page == 0 {
		req.Page = 1
	}
	if req.Size == 0 {
		req.Size = 20
	}

	query := model.DB.Where("family_id = ?", familyID)

	// 添加过滤条件
	if req.CategoryID != nil {
		query = query.Where("category_id = ?", *req.CategoryID)
	}

	if req.Keyword != "" {
		keyword := "%" + req.Keyword + "%"
		query = query.Where("name LIKE ? OR description LIKE ? OR tags LIKE ?", keyword, keyword, keyword)
	}

	if req.Difficulty != "" {
		query = query.Where("difficulty = ?", req.Difficulty)
	}

	if req.Tags != "" {
		tags := strings.Split(req.Tags, ",")
		for _, tag := range tags {
			tag = strings.TrimSpace(tag)
			if tag != "" {
				query = query.Where("tags LIKE ?", "%"+tag+"%")
			}
		}
	}

	if req.Available != nil {
		query = query.Where("is_available = ?", *req.Available)
	}

	if req.Featured != nil {
		query = query.Where("is_featured = ?", *req.Featured)
	}

	// 排序
	orderBy := "created_at DESC"
	if req.SortBy != "" {
		validSortFields := map[string]bool{
			"name":        true,
			"created_at":  true,
			"view_count":  true,
			"like_count":  true,
			"order_count": true,
			"price":       true,
		}

		if validSortFields[req.SortBy] {
			sortOrder := "DESC"
			if req.SortOrder == "asc" {
				sortOrder = "ASC"
			}
			orderBy = req.SortBy + " " + sortOrder
		}
	}

	// 获取总数
	var total int64
	if err := query.Model(&model.Recipe{}).Count(&total).Error; err != nil {
		return nil, fmt.Errorf("查询菜谱总数失败: %v", err)
	}

	// 获取列表
	var recipes []model.Recipe
	offset := (req.Page - 1) * req.Size
	err := query.Preload("Category").Preload("Creator").
		Order(orderBy).
		Offset(offset).
		Limit(req.Size).
		Find(&recipes).Error

	if err != nil {
		return nil, fmt.Errorf("查询菜谱列表失败: %v", err)
	}

	return &RecipeListResponse{
		List:  recipes,
		Total: total,
		Page:  req.Page,
		Size:  req.Size,
	}, nil
}

// GetRecipeByID 根据ID获取菜谱详情
func (s *RecipeService) GetRecipeByID(recipeID, familyID uint) (*model.Recipe, error) {
	var recipe model.Recipe
	err := model.DB.Preload("Category").Preload("Creator").
		Where("id = ? AND family_id = ?", recipeID, familyID).
		First(&recipe).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("菜谱不存在")
		}
		return nil, fmt.Errorf("查询菜谱失败: %v", err)
	}

	// 增加浏览次数
	go func() {
		recipe.IncrementViewCount()
	}()

	return &recipe, nil
}

// UpdateRecipe 更新菜谱
func (s *RecipeService) UpdateRecipe(recipeID uint, req *UpdateRecipeRequest, userID, familyID uint) error {
	// 查找菜谱
	var recipe model.Recipe
	if err := model.DB.Where("id = ? AND family_id = ?", recipeID, familyID).First(&recipe).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("菜谱不存在")
		}
		return fmt.Errorf("查询菜谱失败: %v", err)
	}

	// 检查权限（只有创建者或管理员可以修改）
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return errors.New("用户不存在")
	}

	if recipe.CreatedBy != userID && !user.IsAdmin() {
		return errors.New("权限不足")
	}

	// 准备更新数据
	updates := make(map[string]interface{})

	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.Description != nil {
		updates["description"] = *req.Description
	}
	if req.Image != nil {
		updates["image"] = *req.Image
	}
	if req.Price != nil {
		updates["price"] = *req.Price
	}
	if req.CategoryID != nil {
		// 验证分类是否存在且属于同一家庭
		var category model.RecipeCategory
		if err := model.DB.Where("id = ? AND family_id = ?", *req.CategoryID, familyID).First(&category).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("菜谱分类不存在")
			}
			return fmt.Errorf("查询菜谱分类失败: %v", err)
		}
		updates["category_id"] = *req.CategoryID
	}
	if req.CookingTime != nil {
		updates["cooking_time"] = *req.CookingTime
	}
	if req.Difficulty != nil {
		validDifficulties := map[string]bool{"easy": true, "medium": true, "hard": true}
		if !validDifficulties[*req.Difficulty] {
			return errors.New("无效的难度等级")
		}
		updates["difficulty"] = *req.Difficulty
	}
	if req.Servings != nil {
		updates["servings"] = *req.Servings
	}
	if req.Tags != nil {
		updates["tags"] = *req.Tags
	}
	if req.IsAvailable != nil {
		updates["is_available"] = *req.IsAvailable
	}
	if req.IsFeatured != nil {
		updates["is_featured"] = *req.IsFeatured
	}

	updates["updated_at"] = time.Now()

	// 更新菜谱
	if err := model.DB.Model(&recipe).Updates(updates).Error; err != nil {
		return fmt.Errorf("更新菜谱失败: %v", err)
	}

	// 处理复杂字段的更新
	if len(req.Images) > 0 {
		if err := recipe.SetImagesSlice(req.Images); err != nil {
			return fmt.Errorf("更新图片数组失败: %v", err)
		}
		model.DB.Model(&recipe).Update("images", recipe.Images)
	}

	if len(req.Ingredients) > 0 {
		if err := recipe.SetIngredientsSlice(req.Ingredients); err != nil {
			return fmt.Errorf("更新食材数组失败: %v", err)
		}
		model.DB.Model(&recipe).Update("ingredients", recipe.Ingredients)
	}

	if len(req.Steps) > 0 {
		if err := recipe.SetStepsSlice(req.Steps); err != nil {
			return fmt.Errorf("更新步骤数组失败: %v", err)
		}
		model.DB.Model(&recipe).Update("steps", recipe.Steps)
	}

	if req.NutritionInfo != nil {
		nutritionData, err := json.Marshal(req.NutritionInfo)
		if err != nil {
			return fmt.Errorf("更新营养信息失败: %v", err)
		}
		model.DB.Model(&recipe).Update("nutrition_info", model.JSON(nutritionData))
	}

	return nil
}

// DeleteRecipe 删除菜谱
func (s *RecipeService) DeleteRecipe(recipeID uint, userID, familyID uint) error {
	// 查找菜谱
	var recipe model.Recipe
	if err := model.DB.Where("id = ? AND family_id = ?", recipeID, familyID).First(&recipe).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("菜谱不存在")
		}
		return fmt.Errorf("查询菜谱失败: %v", err)
	}

	// 检查权限（只有创建者或管理员可以删除）
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return errors.New("用户不存在")
	}

	if recipe.CreatedBy != userID && !user.IsAdmin() {
		return errors.New("权限不足")
	}

	// 检查是否有关联的订单项
	var orderItemCount int64
	if err := model.DB.Model(&model.OrderItem{}).Where("recipe_id = ?", recipeID).Count(&orderItemCount).Error; err != nil {
		return fmt.Errorf("检查订单关联失败: %v", err)
	}

	if orderItemCount > 0 {
		return errors.New("该菜谱已有订单记录，无法删除")
	}

	// 软删除菜谱
	if err := model.DB.Delete(&recipe).Error; err != nil {
		return fmt.Errorf("删除菜谱失败: %v", err)
	}

	return nil
}

// ToggleFavorite 切换收藏状态
func (s *RecipeService) ToggleFavorite(recipeID, userID uint) (bool, error) {
	// 检查菜谱是否存在
	var recipe model.Recipe
	if err := model.DB.First(&recipe, recipeID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, errors.New("菜谱不存在")
		}
		return false, fmt.Errorf("查询菜谱失败: %v", err)
	}

	// 检查是否已收藏
	var favorite model.Favorite
	err := model.DB.Where("user_id = ? AND recipe_id = ?", userID, recipeID).First(&favorite).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			// 未收藏，添加收藏
			favorite = model.Favorite{
				UserID:   userID,
				RecipeID: recipeID,
			}
			if err := model.DB.Create(&favorite).Error; err != nil {
				return false, fmt.Errorf("添加收藏失败: %v", err)
			}
			return true, nil
		}
		return false, fmt.Errorf("查询收藏状态失败: %v", err)
	}

	// 已收藏，取消收藏
	if err := model.DB.Delete(&favorite).Error; err != nil {
		return false, fmt.Errorf("取消收藏失败: %v", err)
	}

	return false, nil
}

// GetFavoriteRecipes 获取用户收藏的菜谱
func (s *RecipeService) GetFavoriteRecipes(userID uint, page, size int) (*RecipeListResponse, error) {
	if page == 0 {
		page = 1
	}
	if size == 0 {
		size = 20
	}

	// 获取总数
	var total int64
	if err := model.DB.Model(&model.Favorite{}).Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, fmt.Errorf("查询收藏总数失败: %v", err)
	}

	// 获取收藏的菜谱列表
	var recipes []model.Recipe
	offset := (page - 1) * size
	err := model.DB.Table("recipes").
		Select("recipes.*").
		Joins("INNER JOIN favorites ON recipes.id = favorites.recipe_id").
		Where("favorites.user_id = ?", userID).
		Preload("Category").
		Preload("Creator").
		Order("favorites.created_at DESC").
		Offset(offset).
		Limit(size).
		Find(&recipes).Error

	if err != nil {
		return nil, fmt.Errorf("查询收藏菜谱失败: %v", err)
	}

	return &RecipeListResponse{
		List:  recipes,
		Total: total,
		Page:  page,
		Size:  size,
	}, nil
}
