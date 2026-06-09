package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// DiningHandler 聚餐模式入口
type DiningHandler struct {
	svc *service.DiningService
}

// NewDiningHandler 构造
func NewDiningHandler() *DiningHandler {
	return &DiningHandler{svc: service.NewDiningService()}
}

// Open host 在自己家的某一顿上开聚餐
func (h *DiningHandler) Open(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	item, err := h.svc.Open(hid, uint(id))
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Close host 关闭聚餐
func (h *DiningHandler) Close(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	if err := h.svc.Close(hid, uint(id)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, gin.H{"ok": true})
}

// Join 访客按房间号加入聚餐
func (h *DiningHandler) Join(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in struct {
		RoomCode string `json:"room_code"`
	}
	if err := c.ShouldBindJSON(&in); err != nil || in.RoomCode == "" {
		Fail(c, CodeBadRequest, "请输入房间号")
		return
	}
	item, err := h.svc.Join(uid, in.RoomCode)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Current 访客当前参与中的聚餐
func (h *DiningHandler) Current(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	item, err := h.svc.Current(uid)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Leave 访客离开聚餐
func (h *DiningHandler) Leave(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	if err := h.svc.Leave(uid, uint(id)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, gin.H{"ok": true})
}

// AddDish 聚餐里点菜
func (h *DiningHandler) AddDish(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	var in service.DishInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	item, err := h.svc.AddDish(uid, uint(id), in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// RemoveDish 聚餐里移除自己点的菜
func (h *DiningHandler) RemoveDish(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	mealID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	dishID, err := strconv.ParseUint(c.Param("dish_id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "dish_id 不合法")
		return
	}
	if err := h.svc.RemoveDish(uid, uint(mealID), uint(dishID)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, gin.H{"ok": true})
}

// Recipes 聚餐里可点的菜 召集者家的菜单
func (h *DiningHandler) Recipes(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	items, err := h.svc.Recipes(uid, uint(id), c.Query("keyword"))
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, items)
}
