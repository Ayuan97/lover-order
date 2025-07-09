package api

import (
	"net/http"
	"strconv"

	"love-order-backend/internal/middleware"
	"love-order-backend/internal/model"
	"love-order-backend/internal/service"

	"github.com/gin-gonic/gin"
)

// GuestHandler 访客处理器
type GuestHandler struct {
	guestService *service.GuestService
}

// NewGuestHandler 创建访客处理器
func NewGuestHandler() *GuestHandler {
	return &GuestHandler{
		guestService: service.NewGuestService(),
	}
}

// GenerateInviteCode 生成邀请码（管理员功能）
func (h *GuestHandler) GenerateInviteCode(c *gin.Context) {
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

	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	var req service.GenerateInviteCodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	// 设置默认值
	if req.ExpiresHours == 0 {
		req.ExpiresHours = 24 // 默认24小时
	}
	if req.MaxUses == 0 {
		req.MaxUses = 1 // 默认只能使用1次
	}

	invitation, err := h.guestService.GenerateInviteCode(&req, user.ID, *user.FamilyID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "生成邀请码失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "生成成功",
		"data":    invitation,
	})
}

// GuestRegister 访客注册
func (h *GuestHandler) GuestRegister(c *gin.Context) {
	var req service.GuestRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	resp, err := h.guestService.GuestRegister(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "访客注册失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "注册成功",
		"data":    resp,
	})
}

// GetGuestInfo 获取访客信息
func (h *GuestHandler) GetGuestInfo(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if !user.IsGuest() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "用户不是访客",
		})
		return
	}

	guestInfo, err := h.guestService.GetGuestInfo(user.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取访客信息失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    guestInfo,
	})
}

// ExtendGuestPermission 延长访客权限（管理员功能）
func (h *GuestHandler) ExtendGuestPermission(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	guestUserIDStr := c.Param("id")
	guestUserID, err := strconv.ParseUint(guestUserIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的用户ID",
		})
		return
	}

	var req struct {
		Hours int `json:"hours" binding:"required,min=1"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "请求参数错误",
			"error":   err.Error(),
		})
		return
	}

	err = h.guestService.ExtendGuestPermission(uint(guestUserID), user.ID, req.Hours)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "延长访客权限失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "延长成功",
	})
}

// RevokeGuestPermission 撤销访客权限（管理员功能）
func (h *GuestHandler) RevokeGuestPermission(c *gin.Context) {
	user, exists := middleware.GetCurrentUser(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    401,
			"message": "用户信息不存在",
		})
		return
	}

	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	guestUserIDStr := c.Param("id")
	guestUserID, err := strconv.ParseUint(guestUserIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "无效的用户ID",
		})
		return
	}

	err = h.guestService.RevokeGuestPermission(uint(guestUserID), user.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "撤销访客权限失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "撤销成功",
	})
}

// GetFamilyGuests 获取家庭访客列表（管理员功能）
func (h *GuestHandler) GetFamilyGuests(c *gin.Context) {
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

	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	includeExpired := c.Query("include_expired") == "true"

	guests, err := h.guestService.GetFamilyGuests(*user.FamilyID, includeExpired)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取家庭访客列表失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    guests,
	})
}

// GetInvitationList 获取邀请码列表（管理员功能）
func (h *GuestHandler) GetInvitationList(c *gin.Context) {
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

	if !user.IsAdmin() {
		c.JSON(http.StatusForbidden, gin.H{
			"code":    403,
			"message": "需要管理员权限",
		})
		return
	}

	includeInactive := c.Query("include_inactive") == "true"

	invitations, err := h.guestService.GetInvitationList(*user.FamilyID, includeInactive)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "获取邀请码列表失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "获取成功",
		"data":    invitations,
	})
}

// CheckInviteCode 检查邀请码有效性（公开接口）
func (h *GuestHandler) CheckInviteCode(c *gin.Context) {
	inviteCode := c.Query("code")
	if inviteCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "邀请码不能为空",
		})
		return
	}

	// 查询邀请码
	var invitation model.FamilyInvitation
	err := model.DB.Preload("Family").Where("invite_code = ?", inviteCode).First(&invitation).Error
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "邀请码不存在",
		})
		return
	}

	// 检查有效性
	isValid := invitation.IsAvailable()

	response := gin.H{
		"code":    200,
		"message": "查询成功",
		"data": gin.H{
			"is_valid":    isValid,
			"family_name": invitation.Family.Name,
			"invite_type": invitation.InviteType,
			"expires_at":  invitation.ExpiresAt,
			"max_uses":    invitation.MaxUses,
			"used_count":  invitation.UsedCount,
			"note":        invitation.Note,
		},
	}

	if !isValid {
		if invitation.IsExpired() {
			response["message"] = "邀请码已过期"
		} else if invitation.UsedCount >= invitation.MaxUses {
			response["message"] = "邀请码已达到使用上限"
		} else if !invitation.IsActive {
			response["message"] = "邀请码已被禁用"
		}
	}

	c.JSON(http.StatusOK, response)
}
