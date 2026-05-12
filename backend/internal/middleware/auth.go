package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/model"
	"lover-order-backend/pkg/jwt"
)

// 上下文键
const (
	ctxUser        = "user"
	ctxUserID      = "user_id"
	ctxHouseholdID = "household_id"
)

// AuthRequired 强制登录中间件
func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractToken(c)
		if token == "" {
			abort(c, http.StatusUnauthorized, "请先登录")
			return
		}
		claims, err := jwt.Parse(token)
		if err != nil {
			abort(c, http.StatusUnauthorized, "登录已失效")
			return
		}
		if claims.Type != jwt.TokenTypeAccess {
			abort(c, http.StatusUnauthorized, "令牌类型错误")
			return
		}

		var user model.User
		if err := model.DB.Where("id = ? AND is_active = ?", claims.UserID, true).First(&user).Error; err != nil {
			abort(c, http.StatusUnauthorized, "用户不存在或已停用")
			return
		}

		c.Set(ctxUser, &user)
		c.Set(ctxUserID, user.ID)
		c.Set(ctxHouseholdID, user.HouseholdID)
		c.Next()
	}
}

// HouseholdRequired 要求用户已加入某个家
func HouseholdRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		u, ok := CurrentUser(c)
		if !ok {
			abort(c, http.StatusUnauthorized, "请先登录")
			return
		}
		if !u.InHousehold() {
			abort(c, http.StatusForbidden, "请先创建或加入一个家")
			return
		}
		c.Next()
	}
}

// CurrentUser 取当前登录用户
func CurrentUser(c *gin.Context) (*model.User, bool) {
	v, ok := c.Get(ctxUser)
	if !ok {
		return nil, false
	}
	u, ok := v.(*model.User)
	return u, ok
}

// CurrentUserID 取当前用户 ID
func CurrentUserID(c *gin.Context) (uint, bool) {
	v, ok := c.Get(ctxUserID)
	if !ok {
		return 0, false
	}
	id, ok := v.(uint)
	return id, ok
}

// CurrentHouseholdID 取当前用户所在家的 ID
func CurrentHouseholdID(c *gin.Context) (uint, bool) {
	u, ok := CurrentUser(c)
	if !ok || u.HouseholdID == nil {
		return 0, false
	}
	return *u.HouseholdID, true
}

func extractToken(c *gin.Context) string {
	header := c.GetHeader("Authorization")
	if header != "" {
		parts := strings.SplitN(header, " ", 2)
		if len(parts) == 2 && parts[0] == "Bearer" {
			return parts[1]
		}
	}
	return ""
}

func abort(c *gin.Context, code int, msg string) {
	c.JSON(code, gin.H{"code": code, "message": msg})
	c.Abort()
}
