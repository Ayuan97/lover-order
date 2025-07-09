package api

import (
	"net/http"

	"love-order-backend/internal/middleware"
	"love-order-backend/internal/service"

	"github.com/gin-gonic/gin"
)

// AuthHandler 认证处理器
type AuthHandler struct {
	userService *service.UserService
}

// NewAuthHandler 创建认证处理器
func NewAuthHandler() *AuthHandler {
	return &AuthHandler{
		userService: service.NewUserService(),
	}
}

// WechatLogin 微信登录
func (h *AuthHandler) WechatLogin(c *gin.Context) {
	var req service.WechatLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	resp, err := h.userService.WechatLogin(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "登录失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "登录成功",
		"data":    resp,
	})
}

// RefreshToken 刷新token
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		Token string `json:"token" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	newToken, err := h.userService.RefreshToken(req.Token)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "刷新token失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "刷新成功",
		"data": gin.H{
			"token": newToken,
		},
	})
}

// GetProfile 获取用户资料
func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID, exists := middleware.GetCurrentUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	user, err := h.userService.GetUserProfile(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取用户资料失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    user,
	})
}

// UpdateProfile 更新用户资料
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userID, exists := middleware.GetCurrentUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err := h.userService.UpdateUserProfile(userID, updates)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "更新用户资料失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "更新成功",
	})
}

// GetFamilyMembers 获取家庭成员列表
func (h *AuthHandler) GetFamilyMembers(c *gin.Context) {
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

	// 检查是否包含访客
	includeGuests := c.Query("include_guests") == "true"

	members, err := h.userService.GetFamilyMembers(*user.FamilyID, includeGuests)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取家庭成员失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    members,
	})
}

// UpdateMemberRole 更新成员角色（管理员功能）
func (h *AuthHandler) UpdateMemberRole(c *gin.Context) {
	adminUser, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if !adminUser.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	var req struct {
		UserID  uint   `json:"user_id" binding:"required"`
		NewRole string `json:"new_role" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err := h.userService.UpdateUserRole(adminUser.ID, req.UserID, req.NewRole)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "更新角色失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "更新成功",
	})
}

// DeactivateMember 停用成员（管理员功能）
func (h *AuthHandler) DeactivateMember(c *gin.Context) {
	adminUser, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if !adminUser.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	var req struct {
		UserID uint `json:"user_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err := h.userService.DeactivateUser(adminUser.ID, req.UserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "停用用户失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "停用成功",
	})
}

// Logout 登出（可选实现）
func (h *AuthHandler) Logout(c *gin.Context) {
	// JWT是无状态的，登出通常在客户端删除token即可
	// 如果需要服务端登出，可以维护一个黑名单
	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "登出成功",
	})
}
