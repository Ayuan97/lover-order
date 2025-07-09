package api

import (
	"net/http"
	"strconv"

	"love-order-backend/internal/middleware"
	"love-order-backend/internal/service"

	"github.com/gin-gonic/gin"
)

// RecipeHandler 菜谱处理器
type RecipeHandler struct {
	recipeService   *service.RecipeService
	categoryService *service.CategoryService
}

// NewRecipeHandler 创建菜谱处理器
func NewRecipeHandler() *RecipeHandler {
	return &RecipeHandler{
		recipeService:   service.NewRecipeService(),
		categoryService: service.NewCategoryService(),
	}
}

// CreateRecipe 创建菜谱
func (h *RecipeHandler) CreateRecipe(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if user.FamilyID == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "用户未加入任何家庭",
		})
		return
	}

	var req service.CreateRecipeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	recipe, err := h.recipeService.CreateRecipe(&req, user.ID, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "创建菜谱失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "创建成功",
		"data":    recipe,
	})
}

// GetRecipeList 获取菜谱列表
func (h *RecipeHandler) GetRecipeList(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if user.FamilyID == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "用户未加入任何家庭",
		})
		return
	}

	var req service.RecipeListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	// 设置默认值
	if req.Page == 0 {
		req.Page = 1
	}
	if req.Size == 0 {
		req.Size = 20
	}

	resp, err := h.recipeService.GetRecipeList(&req, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取菜谱列表失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    resp,
	})
}

// GetRecipeDetail 获取菜谱详情
func (h *RecipeHandler) GetRecipeDetail(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if user.FamilyID == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "用户未加入任何家庭",
		})
		return
	}

	recipeIDStr := c.Param("id")
	recipeID, err := strconv.ParseUint(recipeIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的菜谱ID",
		})
		return
	}

	recipe, err := h.recipeService.GetRecipeByID(uint(recipeID), *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取菜谱详情失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    recipe,
	})
}

// UpdateRecipe 更新菜谱
func (h *RecipeHandler) UpdateRecipe(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if user.FamilyID == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "用户未加入任何家庭",
		})
		return
	}

	recipeIDStr := c.Param("id")
	recipeID, err := strconv.ParseUint(recipeIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的菜谱ID",
		})
		return
	}

	var req service.UpdateRecipeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err = h.recipeService.UpdateRecipe(uint(recipeID), &req, user.ID, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "更新菜谱失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "更新成功",
	})
}

// DeleteRecipe 删除菜谱
func (h *RecipeHandler) DeleteRecipe(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if user.FamilyID == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "用户未加入任何家庭",
		})
		return
	}

	recipeIDStr := c.Param("id")
	recipeID, err := strconv.ParseUint(recipeIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的菜谱ID",
		})
		return
	}

	err = h.recipeService.DeleteRecipe(uint(recipeID), user.ID, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "删除菜谱失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "删除成功",
	})
}

// ToggleFavorite 切换收藏状态
func (h *RecipeHandler) ToggleFavorite(c *gin.Context) {
	userID, exists := middleware.GetCurrentUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	recipeIDStr := c.Param("id")
	recipeID, err := strconv.ParseUint(recipeIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的菜谱ID",
		})
		return
	}

	isFavorited, err := h.recipeService.ToggleFavorite(uint(recipeID), userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "操作失败",
			"error":   err.Error(),
		})
		return
	}

	message := "取消收藏成功"
	if isFavorited {
		message = "收藏成功"
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": message,
		"data": gin.H{
			"is_favorited": isFavorited,
		},
	})
}

// GetFavoriteRecipes 获取收藏的菜谱
func (h *RecipeHandler) GetFavoriteRecipes(c *gin.Context) {
	userID, exists := middleware.GetCurrentUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))

	resp, err := h.recipeService.GetFavoriteRecipes(userID, page, size)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取收藏菜谱失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    resp,
	})
}

// CreateRecipeDev 创建菜谱（开发测试用，无需认证）
func (h *RecipeHandler) CreateRecipeDev(c *gin.Context) {
	var req service.CreateRecipeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	// 使用默认家庭ID和用户ID（开发测试用）
	familyID := uint(1)
	userID := uint(1)

	recipe, err := h.recipeService.CreateRecipe(&req, familyID, userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "创建菜谱失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"code":    201,
		"message": "创建成功",
		"data":    recipe,
	})
}

// GetRecipeListDev 获取菜谱列表（开发测试用，无需认证）
func (h *RecipeHandler) GetRecipeListDev(c *gin.Context) {
	// 使用默认家庭ID（开发测试用）
	familyID := uint(1)

	// 解析查询参数
	var req service.RecipeListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	// 设置默认值
	if req.Page <= 0 {
		req.Page = 1
	}
	if req.Size <= 0 {
		req.Size = 20
	}

	resp, err := h.recipeService.GetRecipeList(&req, familyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取菜谱列表失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    resp,
	})
}
