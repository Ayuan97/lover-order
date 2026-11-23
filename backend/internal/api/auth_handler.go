package api

import (
	"errors"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// AuthHandler 登录/资料相关 HTTP 入口
type AuthHandler struct {
	svc *service.UserService
}

// NewAuthHandler 构造
func NewAuthHandler() *AuthHandler {
	return &AuthHandler{svc: service.NewUserService()}
}

// DeviceLogin 基于设备唯一 ID 直接用昵称进入
func (h *AuthHandler) DeviceLogin(c *gin.Context) {
	var in service.DeviceLoginInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "请填写昵称")
		return
	}
	result, err := h.svc.LoginWithDevice(in)
	if err != nil {
		if errors.Is(err, service.ErrDevicePasswordRequired) {
			Fail(c, CodeConflict, err.Error())
			return
		}
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, result)
}

// PasswordLogin 昵称与密码登录
func (h *AuthHandler) PasswordLogin(c *gin.Context) {
	var in service.PasswordLoginInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "请填写昵称和密码")
		return
	}
	result, err := h.svc.LoginWithPassword(in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, result)
}

// SetPassword 设置或修改当前账号密码
func (h *AuthHandler) SetPassword(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.SetPasswordInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "请填写新密码")
		return
	}
	user, err := h.svc.SetPassword(uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, user)
}

// AppleLogin Apple Sign In 登录
func (h *AuthHandler) AppleLogin(c *gin.Context) {
	var in service.AppleLoginInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	result, err := h.svc.LoginWithApple(in)
	if err != nil {
		Fail(c, CodeUnauthorized, err.Error())
		return
	}
	OK(c, result)
}

// Refresh 刷新访问令牌
func (h *AuthHandler) Refresh(c *gin.Context) {
	var in struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	access, err := h.svc.Refresh(in.RefreshToken)
	if err != nil {
		Fail(c, CodeUnauthorized, "刷新失败")
		return
	}
	OK(c, gin.H{"access_token": access})
}

// Logout 登出 客户端清掉本地令牌即可 服务端无状态
func (h *AuthHandler) Logout(c *gin.Context) {
	OK(c, nil)
}

// Profile 取当前用户资料
func (h *AuthHandler) Profile(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	user, err := h.svc.GetUser(uid)
	if err != nil {
		Fail(c, CodeNotFound, "用户不存在")
		return
	}
	OK(c, user)
}

// UpdateProfile 更新当前用户资料
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.UpdateProfileInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	user, err := h.svc.UpdateProfile(uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, user)
}
