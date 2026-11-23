package api

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/model"
	"lover-order-backend/internal/service"
	"lover-order-backend/pkg/jwt"
)

// CanvasHandler 餐次实时自由画布 REST 与 WebSocket 入口
type CanvasHandler struct {
	svc *service.CanvasService
}

// NewCanvasHandler 构造
func NewCanvasHandler() *CanvasHandler {
	return &CanvasHandler{svc: service.NewCanvasService()}
}

var canvasWSUpgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// Get 获取餐次画布当前快照与版本号
func (h *CanvasHandler) Get(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	snap, err := h.svc.Get(uid, uint(id))
	if err != nil {
		if strings.Contains(err.Error(), "无权") {
			Fail(c, CodeForbidden, err.Error())
			return
		}
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, snap)
}

// Save 保存完整画布并广播快照
func (h *CanvasHandler) Save(c *gin.Context) {
	uid, _ := middleware.CurrentUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}
	var in struct {
		Document *service.CanvasDocPayload `json:"document"`
		ClientID string                    `json:"client_id"`
	}
	if err := c.ShouldBindJSON(&in); err != nil || in.Document == nil {
		Fail(c, CodeBadRequest, "参数有误")
		return
	}
	snap, err := h.svc.Save(uid, uint(id), in.Document, in.ClientID)
	if err != nil {
		if strings.Contains(err.Error(), "无权") {
			Fail(c, CodeForbidden, err.Error())
			return
		}
		Fail(c, CodeBadRequest, err.Error())
		return
	}
	OK(c, snap)
}

// WebSocket 建立实时画布协作长连接
func (h *CanvasHandler) WebSocket(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, CodeBadRequest, "id 不合法")
		return
	}

	token := extractWSToken(c)
	if token == "" {
		Fail(c, CodeUnauthorized, "请先登录")
		return
	}
	claims, err := jwt.Parse(token)
	if err != nil || claims.Type != jwt.TokenTypeAccess {
		Fail(c, CodeUnauthorized, "登录已失效")
		return
	}

	var user model.User
	if err := model.DB.Where("id = ? AND is_active = ?", claims.UserID, true).First(&user).Error; err != nil {
		Fail(c, CodeUnauthorized, "用户不存在或已停用")
		return
	}

	canRead, canEdit, role, err := h.svc.CheckAccess(user.ID, uint(id))
	if err != nil || !canRead {
		msg := "无权访问这顿画布"
		if err != nil {
			msg = err.Error()
		}
		Fail(c, CodeForbidden, msg)
		return
	}

	conn, err := canvasWSUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	clientID := strings.TrimSpace(c.Query("client_id"))
	service.GlobalCanvasHub().ServeClient(conn, uint(id), user.ID, role, canEdit, clientID)
}

func extractWSToken(c *gin.Context) string {
	header := c.GetHeader("Authorization")
	if header != "" {
		parts := strings.SplitN(header, " ", 2)
		if len(parts) == 2 && parts[0] == "Bearer" {
			return strings.TrimSpace(parts[1])
		}
	}
	return strings.TrimSpace(c.Query("token"))
}
