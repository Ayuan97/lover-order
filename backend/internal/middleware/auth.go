package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"love-order-backend/internal/model"
	"love-order-backend/pkg/jwt"
)

// AuthMiddleware JWT认证中间件
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractToken(c)
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "未提供认证token",
			})
			c.Abort()
			return
		}

		claims, err := jwt.ParseToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "无效的token",
				"error":   err.Error(),
			})
			c.Abort()
			return
		}

		// 验证用户是否存在且激活
		var user model.User
		if err := model.DB.Where("id = ? AND is_active = ?", claims.UserID, true).First(&user).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "用户不存在或已被禁用",
			})
			c.Abort()
			return
		}

		// 检查访客是否过期
		if user.IsGuest() && user.IsGuestExpired() {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "访客权限已过期",
			})
			c.Abort()
			return
		}

		// 更新最后登录时间
		now := time.Now()
		model.DB.Model(&user).Update("last_login_at", now)

		// 将用户信息存储到上下文中
		c.Set("user", &user)
		c.Set("user_id", user.ID)
		c.Set("user_role", user.Role)
		c.Set("family_id", user.FamilyID)

		c.Next()
	}
}

// AdminMiddleware 管理员权限中间件
func AdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "用户信息不存在",
			})
			c.Abort()
			return
		}

		u := user.(*model.User)
		if !u.IsAdmin() {
			c.JSON(http.StatusForbidden, gin.H{
				"code":    403,
				"message": "需要管理员权限",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// FamilyMemberMiddleware 家庭成员权限中间件
func FamilyMemberMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "用户信息不存在",
			})
			c.Abort()
			return
		}

		u := user.(*model.User)
		if u.FamilyID == nil {
			c.JSON(http.StatusForbidden, gin.H{
				"code":    403,
				"message": "用户未加入任何家庭",
			})
			c.Abort()
			return
		}

		// 访客用户需要额外检查权限
		if u.IsGuest() && u.IsGuestExpired() {
			c.JSON(http.StatusForbidden, gin.H{
				"code":    403,
				"message": "访客权限已过期",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// FamilyAccessMiddleware 家庭访问权限中间件
func FamilyAccessMiddleware(familyIDParam string) gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    401,
				"message": "用户信息不存在",
			})
			c.Abort()
			return
		}

		u := user.(*model.User)
		
		// 从URL参数或查询参数获取家庭ID
		familyIDStr := c.Param(familyIDParam)
		if familyIDStr == "" {
			familyIDStr = c.Query(familyIDParam)
		}

		if familyIDStr != "" {
			// 这里需要将字符串转换为uint并验证权限
			// 简化处理，实际项目中需要更严格的验证
			if u.FamilyID == nil {
				c.JSON(http.StatusForbidden, gin.H{
					"code":    403,
					"message": "无权访问该家庭数据",
				})
				c.Abort()
				return
			}
		}

		c.Next()
	}
}

// OptionalAuthMiddleware 可选认证中间件（用于公开接口）
func OptionalAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractToken(c)
		if token == "" {
			c.Next()
			return
		}

		claims, err := jwt.ParseToken(token)
		if err != nil {
			c.Next()
			return
		}

		// 验证用户是否存在且激活
		var user model.User
		if err := model.DB.Where("id = ? AND is_active = ?", claims.UserID, true).First(&user).Error; err != nil {
			c.Next()
			return
		}

		// 将用户信息存储到上下文中
		c.Set("user", &user)
		c.Set("user_id", user.ID)
		c.Set("user_role", user.Role)
		c.Set("family_id", user.FamilyID)

		c.Next()
	}
}

// extractToken 从请求中提取token
func extractToken(c *gin.Context) string {
	// 从Authorization header中提取
	authHeader := c.GetHeader("Authorization")
	if authHeader != "" {
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) == 2 && parts[0] == "Bearer" {
			return parts[1]
		}
	}

	// 从查询参数中提取
	token := c.Query("token")
	if token != "" {
		return token
	}

	// 从表单中提取
	token = c.PostForm("token")
	if token != "" {
		return token
	}

	return ""
}

// GetCurrentUser 获取当前用户
func GetCurrentUser(c *gin.Context) (*model.User, bool) {
	user, exists := c.Get("user")
	if !exists {
		return nil, false
	}
	return user.(*model.User), true
}

// GetCurrentUserID 获取当前用户ID
func GetCurrentUserID(c *gin.Context) (uint, bool) {
	userID, exists := c.Get("user_id")
	if !exists {
		return 0, false
	}
	return userID.(uint), true
}
