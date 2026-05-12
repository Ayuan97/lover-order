package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// CategoryHandler 菜谱分类 HTTP 入口
type CategoryHandler struct {
	svc *service.CategoryService
}

// NewCategoryHandler 构造
func NewCategoryHandler() *CategoryHandler {
	return &CategoryHandler{svc: service.NewCategoryService()}
}

// List 分类列表
func (h *CategoryHandler) List(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	items, err := h.svc.List(hid)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, items)
}

// Create 创建分类
func (h *CategoryHandler) Create(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	var in service.CategoryInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	item, err := h.svc.Create(hid, in)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, item)
}

// Update 修改分类
func (h *CategoryHandler) Update(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	var in service.CategoryInput
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

// Delete 删除分类
func (h *CategoryHandler) Delete(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	if err := h.svc.Delete(hid, uint(id)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, nil)
}
