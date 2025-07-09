package api

import (
	"net/http"
	"strconv"

	"love-order-backend/internal/middleware"
	"love-order-backend/internal/service"

	"github.com/gin-gonic/gin"
)

// CategoryHandler 分类处理器
type CategoryHandler struct {
	categoryService *service.CategoryService
}

// NewCategoryHandler 创建分类处理器
func NewCategoryHandler() *CategoryHandler {
	return &CategoryHandler{
		categoryService: service.NewCategoryService(),
	}
}

// CreateCategory 创建分类
func (h *CategoryHandler) CreateCategory(c *gin.Context) {
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

	// 只有管理员可以创建分类
	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	var req service.CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	category, err := h.categoryService.CreateCategory(&req, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "创建分类失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "创建成功",
		"data":    category,
	})
}

// GetCategoryList 获取分类列表
func (h *CategoryHandler) GetCategoryList(c *gin.Context) {
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

	// 是否包含未激活的分类（仅管理员可见）
	includeInactive := c.Query("include_inactive") == "true" && user.IsAdmin()

	categories, err := h.categoryService.GetCategoryList(*user.FamilyID, includeInactive)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取分类列表失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    categories,
	})
}

// GetCategoryDetail 获取分类详情
func (h *CategoryHandler) GetCategoryDetail(c *gin.Context) {
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

	categoryIDStr := c.Param("id")
	categoryID, err := strconv.ParseUint(categoryIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的分类ID",
		})
		return
	}

	category, err := h.categoryService.GetCategoryByID(uint(categoryID), *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取分类详情失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    category,
	})
}

// UpdateCategory 更新分类
func (h *CategoryHandler) UpdateCategory(c *gin.Context) {
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

	// 只有管理员可以更新分类
	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	categoryIDStr := c.Param("id")
	categoryID, err := strconv.ParseUint(categoryIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的分类ID",
		})
		return
	}

	var req service.UpdateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err = h.categoryService.UpdateCategory(uint(categoryID), &req, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "更新分类失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "更新成功",
	})
}

// DeleteCategory 删除分类
func (h *CategoryHandler) DeleteCategory(c *gin.Context) {
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

	// 只有管理员可以删除分类
	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	categoryIDStr := c.Param("id")
	categoryID, err := strconv.ParseUint(categoryIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的分类ID",
		})
		return
	}

	err = h.categoryService.DeleteCategory(uint(categoryID), *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "删除分类失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "删除成功",
	})
}

// UpdateCategorySortOrder 更新分类排序
func (h *CategoryHandler) UpdateCategorySortOrder(c *gin.Context) {
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

	// 只有管理员可以更新排序
	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	var req []map[string]interface{}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err := h.categoryService.UpdateCategorySortOrder(*user.FamilyID, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "更新排序失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "更新成功",
	})
}

// GetCategoryStats 获取分类统计
func (h *CategoryHandler) GetCategoryStats(c *gin.Context) {
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

	stats, err := h.categoryService.GetCategoryStats(*user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取分类统计失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    stats,
	})
}

// CreateCategoryDev 创建分类（开发测试用，无需认证）
func (h *CategoryHandler) CreateCategoryDev(c *gin.Context) {
	var req struct {
		Name        string `json:"name" binding:"required"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "参数错误",
			"error":   err.Error(),
		})
		return
	}

	// 创建默认家庭ID为1（开发测试用）
	familyID := uint(1)

	createReq := &service.CreateCategoryRequest{
		Name: req.Name,
		Icon: req.Icon,
	}

	category, err := h.categoryService.CreateCategory(createReq, familyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "创建分类失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"code":    201,
		"message": "创建成功",
		"data":    category,
	})
}

// GetCategoryListDev 获取分类列表（开发测试用，无需认证）
func (h *CategoryHandler) GetCategoryListDev(c *gin.Context) {
	// 使用默认家庭ID（开发测试用）
	familyID := uint(1)
	includeInactive := false

	categories, err := h.categoryService.GetCategoryList(familyID, includeInactive)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取分类列表失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    categories,
	})
}
