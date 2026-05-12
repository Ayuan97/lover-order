package api

import (
	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// HouseholdHandler 一个家相关入口
type HouseholdHandler struct {
	svc *service.HouseholdService
}

// NewHouseholdHandler 构造
func NewHouseholdHandler() *HouseholdHandler {
	return &HouseholdHandler{svc: service.NewHouseholdService()}
}

// Create 创建一个家
func (h *HouseholdHandler) Create(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.CreateInput
	_ = c.ShouldBindJSON(&in)
	item, err := h.svc.Create(uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Info 取当前家详情
func (h *HouseholdHandler) Info(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	item, err := h.svc.Get(hid)
	if err != nil {
		Fail(c, CodeNotFound, "家不存在")
		return
	}
	OK(c, item)
}

// Join 通过邀请码加入
func (h *HouseholdHandler) Join(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.JoinInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	item, err := h.svc.Join(uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Leave 退出当前家
func (h *HouseholdHandler) Leave(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	if err := h.svc.Leave(uid); err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, nil)
}

// Invite 生成临时邀请
func (h *HouseholdHandler) Invite(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	hid, _ := middleware.CurrentHouseholdID(c)
	var in service.InviteInput
	_ = c.ShouldBindJSON(&in)
	item, err := h.svc.CreateInvite(uid, hid, in)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, item)
}

// Invitations 列出邀请
func (h *HouseholdHandler) Invitations(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	items, err := h.svc.ListInvites(hid)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, items)
}
