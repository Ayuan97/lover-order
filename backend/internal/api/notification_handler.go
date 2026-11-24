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
	var afterID *uint
	if raw, ok := c.GetQuery("after_id"); ok {
		id, err := strconv.ParseUint(raw, 10, 64)
		if err != nil {
			Fail(c, CodeBadRequest, "通知 id 不合法")
			return
		}
		value := uint(id)
		afterID = &value
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "30"))
	res, err := h.svc.ListEvents(uid, c.GetHeader("X-Notification-Device-ID"), afterID, limit)
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

// Nudge 向家里同伴发送阶段化餐桌传呼/提醒（仅家庭日常成员间互发）
func (h *NotificationHandler) Nudge(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.NudgeInput
	if c.Request.ContentLength > 0 {
		if err := c.ShouldBindJSON(&in); err != nil {
			Fail(c, CodeBadRequest, "参数有误")
			return
		}
	}
	res, err := h.svc.SendNudge(uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, res)
}

// Reply 一键轻回应通知或传呼（如锁屏下拉快捷按钮与站内回戳）
func (h *NotificationHandler) Reply(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.NudgeReplyInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	res, err := h.svc.SendNudgeReply(uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, res)
}
