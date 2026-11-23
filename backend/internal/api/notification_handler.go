package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// NotificationHandler 消息提醒与设备推送入口
type NotificationHandler struct {
	svc *service.NotificationService
}

// NewNotificationHandler 构造
func NewNotificationHandler() *NotificationHandler {
	return &NotificationHandler{svc: service.NewNotificationService()}
}

// RegisterDevice 注册设备 APNs 推送令牌
func (h *NotificationHandler) RegisterDevice(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.DeviceRegisterInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	if err := h.svc.RegisterDevice(uid, in); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, gin.H{"ok": true})
}

// UnregisterDevice 停用设备推送令牌
func (h *NotificationHandler) UnregisterDevice(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in struct {
		Token string `json:"token"`
	}
	_ = c.ShouldBindJSON(&in)
	if err := h.svc.UnregisterDevice(uid, in.Token); err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, gin.H{"ok": true})
}

// List 获取通知事件与未读统计
func (h *NotificationHandler) List(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	afterID, _ := strconv.ParseUint(c.DefaultQuery("after_id", "0"), 10, 64)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "30"))
	res, err := h.svc.ListEvents(uid, uint(afterID), limit)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, res)
}

// MarkRead 标记单条或全部通知已读
func (h *NotificationHandler) MarkRead(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in struct {
		EventID uint `json:"event_id"`
	}
	_ = c.ShouldBindJSON(&in)
	if err := h.svc.MarkRead(uid, in.EventID); err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, gin.H{"ok": true})
}

// SendTest 生成一条测试通知以便体验横幅与点击跳转
func (h *NotificationHandler) SendTest(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	ev, err := h.svc.SendTest(uid)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, ev)
}
