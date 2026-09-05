package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// MealHandler 一顿相关入口
type MealHandler struct {
	svc *service.MealService
}

// NewMealHandler 构造
func NewMealHandler() *MealHandler {
	return &MealHandler{svc: service.NewMealService()}
}

// Current 取或创建当前规划中的一顿
func (h *MealHandler) Current(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)
	scene := c.Query("scene")
	mood := c.Query("mood")
	item, err := h.svc.Current(hid, uid, scene, mood)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Create 显式新建一顿
func (h *MealHandler) Create(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)
	var in service.MealInput
	_ = c.ShouldBindJSON(&in)
	item, err := h.svc.Create(hid, uid, in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Update 更新一顿
func (h *MealHandler) Update(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	var in service.MealInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	item, err := h.svc.Update(hid, uint(id), in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Detail 一顿详情
func (h *MealHandler) Detail(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	item, err := h.svc.Get(hid, uint(id))
	if err != nil {
		Fail(c, CodeNotFound, err.Error())
		return
	}
	OK(c, item)
}

// List 历史/筛选列表
func (h *MealHandler) List(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	q := service.MealListQuery{
		Scene:  c.Query("scene"),
		Status: c.Query("status"),
	}
	q.Page, _ = strconv.Atoi(c.DefaultQuery("page", "1"))
	q.PageSize, _ = strconv.Atoi(c.DefaultQuery("page_size", "20"))
	items, err := h.svc.List(hid, q)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, items)
}

// AddDish 加入一道菜
func (h *MealHandler) AddDish(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
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
	item, err := h.svc.AddDish(hid, uid, uint(id), in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// RemoveDish 移除一道菜
func (h *MealHandler) RemoveDish(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
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
	if err := h.svc.RemoveDish(hid, uint(mealID), uint(dishID)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, nil)
}

// Confirm 定下这一顿
func (h *MealHandler) Confirm(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	item, err := h.svc.Confirm(hid, uint(id))
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Complete 标记吃完
func (h *MealHandler) Complete(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	item, err := h.svc.Complete(hid, uint(id))
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}

// Cancel 取消
func (h *MealHandler) Cancel(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	if err := h.svc.Cancel(hid, uint(id)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, nil)
}

// ShoppingList 当前一顿的食材清单
func (h *MealHandler) ShoppingList(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	list, err := h.svc.ShoppingList(hid, uint(id))
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, list)
}

// Stats 一个家的累积统计
func (h *MealHandler) Stats(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	stats, err := h.svc.Stats(hid)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, stats)
}

// Review 留下评价
func (h *MealHandler) Review(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	var in service.ReviewInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	item, err := h.svc.AddReview(hid, uid, uint(id), in)
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, item)
}
