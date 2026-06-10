package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

// RecipeHandler 菜谱 HTTP 入口
type RecipeHandler struct {
	svc *service.RecipeService
}

// NewRecipeHandler 构造
func NewRecipeHandler() *RecipeHandler {
	return &RecipeHandler{svc: service.NewRecipeService()}
}

// List 列表
func (h *RecipeHandler) List(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)

	q := service.ListQuery{
		Mood:    c.Query("mood"),
		Scene:   c.Query("scene"),
		Keyword: c.Query("keyword"),
		UserID:  uid,
	}
	if v := c.Query("category_id"); v != "" {
		if id, err := strconv.ParseUint(v, 10, 64); err == nil {
			cid := uint(id)
			q.CategoryID = &cid
		}
	}
	if c.Query("favorite") == "1" || c.Query("favorite") == "true" {
		q.Favorite = true
	}
	q.Page, _ = strconv.Atoi(c.DefaultQuery("page", "1"))
	q.PageSize, _ = strconv.Atoi(c.DefaultQuery("page_size", "20"))

	result, err := h.svc.List(hid, q)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, result)
}

// Detail 详情
func (h *RecipeHandler) Detail(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	r, err := h.svc.Get(hid, uid, uint(id))
	if err != nil {
		Fail(c, CodeNotFound, err.Error())
		return
	}
	OK(c, r)
}

// Create 新建菜谱
func (h *RecipeHandler) Create(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)
	var in service.RecipeInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	r, err := h.svc.Create(hid, uid, in)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, r)
}

// Update 更新
func (h *RecipeHandler) Update(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	var in service.RecipeInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	r, err := h.svc.Update(hid, uint(id), in)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, r)
}

// Delete 删除
func (h *RecipeHandler) Delete(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	if err := h.svc.Delete(hid, uint(id)); err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, nil)
}

// ToggleFavorite 切换收藏
func (h *RecipeHandler) ToggleFavorite(c *gin.Context) {
	hid, _ := middleware.CurrentHouseholdID(c)
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	favored, err := h.svc.ToggleFavorite(uid, hid, uint(id))
	if err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, gin.H{"favored": favored})
}
