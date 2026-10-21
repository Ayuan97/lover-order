package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/service"
)

type StickerFavoriteHandler struct {
	svc *service.StickerFavoriteService
}

func NewStickerFavoriteHandler() *StickerFavoriteHandler {
	return &StickerFavoriteHandler{svc: service.NewStickerFavoriteService()}
}

func (h *StickerFavoriteHandler) List(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	items, err := h.svc.List(uid)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, items)
}

func (h *StickerFavoriteHandler) Create(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	var in service.StickerFavoriteInput
	if err := c.ShouldBindJSON(&in); err != nil {
		Fail(c, CodeBadRequest, "请选择要收藏的贴图")
		return
	}
	item, err := h.svc.Create(uid, in)
	if err != nil {
		Fail(c, CodeInternalError, err.Error())
		return
	}
	OK(c, item)
}

func (h *StickerFavoriteHandler) Delete(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	if err := h.svc.Delete(uid, uint(id)); err != nil {
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, nil)
}
