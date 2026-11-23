package service

import (
	"encoding/json"
	"errors"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"lover-order-backend/internal/model"
)

// CanvasActor 在线协作者或操作发起人信息
type CanvasActor struct {
	ID       uint   `json:"id"`
	Nickname string `json:"nickname"`
	Avatar   string `json:"avatar,omitempty"`
	Role     string `json:"role"`
}

// CanvasHub 管理按餐次划分的实时协作房间
type CanvasHub struct {
	mu    sync.Mutex
	rooms map[uint]*canvasRoom
}

var (
	sharedCanvasHub     *CanvasHub
	sharedCanvasHubOnce sync.Once
)

// GlobalCanvasHub 返回全局画布房间中心
func GlobalCanvasHub() *CanvasHub {
	sharedCanvasHubOnce.Do(func() {
		sharedCanvasHub = &CanvasHub{
			rooms: make(map[uint]*canvasRoom),
		}
	})
	return sharedCanvasHub
}

type canvasRoom struct {
	hub       *CanvasHub
	mealID    uint
	mu        sync.Mutex
	clients   map[*canvasClient]struct{}
	loaded    bool
	evicted   bool
	revision  int64
	doc       *CanvasDocPayload
	updatedAt *time.Time
}

type canvasClient struct {
	room     *canvasRoom
	conn     *websocket.Conn
	userID   uint
	clientID string
	actor    CanvasActor
	canEdit  bool

	revoked         atomic.Bool
	accessCheckMu   sync.Mutex
	lastAccessCheck time.Time

	sendMu sync.Mutex
	send   chan []byte
	closed bool
}

type inboundWSMessage struct {
	Type            string          `json:"type"`
	ClientID        string          `json:"client_id"`
	OpID            string          `json:"op_id"`
	Kind            string          `json:"kind"`
	Payload         CanvasOpPayload `json:"payload"`
	TargetKind      string          `json:"target_kind"`
	TargetID        string          `json:"target_id"`
	Position        json.RawMessage `json:"position,omitempty"`
	Scale           *float64        `json:"scale,omitempty"`
	RotationDegrees *float64        `json:"rotation_degrees,omitempty"`
	ActiveStroke    json.RawMessage `json:"active_stroke,omitempty"`
}

func (h *CanvasHub) getOrCreateRoom(mealID uint) *canvasRoom {
	h.mu.Lock()
	defer h.mu.Unlock()
	if r, ok := h.rooms[mealID]; ok {
		return r
	}
	r := &canvasRoom{
		hub:     h,
		mealID:  mealID,
		clients: make(map[*canvasClient]struct{}),
	}
	h.rooms[mealID] = r
	return r
}

func (h *CanvasHub) acquireLiveRoomLocked(mealID uint) *canvasRoom {
	for {
		r := h.getOrCreateRoom(mealID)
		r.mu.Lock()
		if !r.evicted {
			return r
		}
		r.mu.Unlock()
	}
}

func (h *CanvasHub) getActiveRoom(mealID uint) *canvasRoom {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.rooms[mealID]
}

func (h *CanvasHub) evictIfEmpty(r *canvasRoom) {
	h.mu.Lock()
	defer h.mu.Unlock()
	r.mu.Lock()
	if len(r.clients) == 0 {
		r.evicted = true
		if h.rooms[r.mealID] == r {
			delete(h.rooms, r.mealID)
		}
	}
	r.mu.Unlock()
}

// GetSnapshot 获取餐次画布当前版本与文档
func (h *CanvasHub) GetSnapshot(mealID uint) (*CanvasSnapshotResponse, error) {
	if r := h.getActiveRoom(mealID); r != nil {
		r.mu.Lock()
		if !r.evicted {
			if err := r.ensureLoadedLocked(); err != nil {
				r.mu.Unlock()
				return nil, err
			}
			resp := &CanvasSnapshotResponse{
				MealID:    mealID,
				Revision:  r.revision,
				Document:  cloneCanvasDoc(r.doc),
				UpdatedAt: r.updatedAt,
			}
			r.mu.Unlock()
			return resp, nil
		}
		r.mu.Unlock()
	}

	var rec model.MealCanvas
	err := model.DB.Where("meal_session_id = ?", mealID).First(&rec).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return &CanvasSnapshotResponse{
			MealID:   mealID,
			Revision: 0,
			Document: nil,
		}, nil
	}
	if err != nil {
		return nil, err
	}
	var doc CanvasDocPayload
	if len(rec.Document) > 0 {
		if err := json.Unmarshal(rec.Document, &doc); err != nil {
			return nil, err
		}
	}
	return &CanvasSnapshotResponse{
		MealID:    mealID,
		Revision:  rec.Revision,
		Document:  normalizeCanvasDoc(&doc),
		UpdatedAt: &rec.UpdatedAt,
	}, nil
}

// SaveDocument 保存完整画布并向在线房间成员广播 snapshot
func (h *CanvasHub) SaveDocument(mealID uint, doc *CanvasDocPayload, actor CanvasActor, clientID string) (*CanvasSnapshotResponse, error) {
	r := h.acquireLiveRoomLocked(mealID)
	defer h.evictIfEmpty(r)

	normalized := normalizeCanvasDoc(doc)
	if err := r.ensureLoadedLocked(); err != nil {
		r.mu.Unlock()
		return nil, err
	}
	rev, updatedAt, err := r.persistLocked(normalized, actor.ID)
	if err != nil {
		r.mu.Unlock()
		return nil, err
	}
	targets := r.snapshotClientsLocked(nil)
	r.mu.Unlock()

	if len(targets) > 0 {
		msg, _ := json.Marshal(map[string]any{
			"type":      "snapshot",
			"meal_id":   mealID,
			"revision":  rev,
			"actor":     actor,
			"client_id": clientID,
			"document":  normalized,
		})
		sendToClients(targets, msg)
	}

	return &CanvasSnapshotResponse{
		MealID:    mealID,
		Revision:  rev,
		Document:  cloneCanvasDoc(normalized),
		UpdatedAt: updatedAt,
	}, nil
}

// BroadcastMealSync 餐次状态或菜单变化时通知同房在线端秒级同步
func (h *CanvasHub) BroadcastMealSync(mealID uint, reason string, actorID uint) {
	r := h.getActiveRoom(mealID)
	if r == nil {
		return
	}
	r.mu.Lock()
	targets := r.snapshotClientsLocked(nil)
	r.mu.Unlock()
	if len(targets) == 0 {
		return
	}
	msg, _ := json.Marshal(map[string]any{
		"type":     "meal_sync",
		"meal_id":  mealID,
		"reason":   reason,
		"actor_id": actorID,
	})
	sendToClients(targets, msg)
}

// EvictGuests 关房或餐次结束后踢出房内来客连接
func (h *CanvasHub) EvictGuests(mealID uint) {
	r := h.getActiveRoom(mealID)
	if r == nil {
		return
	}
	r.mu.Lock()
	if r.evicted {
		r.mu.Unlock()
		return
	}
	var targets []*canvasClient
	for c := range r.clients {
		if c.actor.Role == "guest" {
			targets = append(targets, c)
		}
	}
	r.mu.Unlock()
	for _, c := range targets {
		c.revokeAndDrain()
	}
}

// EvictUser 将指定已退房来客移出实时画布连接
func (h *CanvasHub) EvictUser(mealID, userID uint) {
	r := h.getActiveRoom(mealID)
	if r == nil {
		return
	}
	r.mu.Lock()
	if r.evicted {
		r.mu.Unlock()
		return
	}
	var targets []*canvasClient
	for c := range r.clients {
		if c.userID == userID && c.actor.Role == "guest" {
			targets = append(targets, c)
		}
	}
	r.mu.Unlock()
	for _, c := range targets {
		c.revokeAndDrain()
	}
}

// ServeClient 接入一名认证用户的 WebSocket 连接
func (h *CanvasHub) ServeClient(conn *websocket.Conn, mealID, userID uint, role string, canEdit bool, clientID string) {
	if clientID == "" {
		clientID = "u" + time.Now().Format("150405.000")
	}
	actor := loadCanvasActor(userID, role)
	r := h.acquireLiveRoomLocked(mealID)
	c := &canvasClient{
		room:            r,
		conn:            conn,
		userID:          userID,
		clientID:        clientID,
		actor:           actor,
		canEdit:         canEdit,
		lastAccessCheck: time.Now(),
		send:            make(chan []byte, 64),
	}

	if err := r.ensureLoadedLocked(); err != nil {
		r.mu.Unlock()
		_ = conn.Close()
		h.evictIfEmpty(r)
		return
	}
	r.clients[c] = struct{}{}
	users := r.onlineUsersLocked()
	welcomeBytes, _ := json.Marshal(map[string]any{
		"type":         "welcome",
		"meal_id":      mealID,
		"revision":     r.revision,
		"document":     cloneCanvasDoc(r.doc),
		"can_edit":     canEdit,
		"online_users": users,
	})
	presenceBytes, _ := json.Marshal(map[string]any{
		"type":         "presence",
		"meal_id":      mealID,
		"online_users": users,
	})
	otherTargets := r.snapshotClientsLocked(c)
	r.mu.Unlock()

	c.enqueue(welcomeBytes)
	sendToClients(otherTargets, presenceBytes)

	go c.writePump()
	c.readPump()
}

func (r *canvasRoom) ensureLoadedLocked() error {
	if r.loaded {
		return nil
	}
	var rec model.MealCanvas
	err := model.DB.Where("meal_session_id = ?", r.mealID).First(&rec).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		r.revision = 0
		r.doc = nil
		r.loaded = true
		return nil
	}
	if err != nil {
		return err
	}
	var doc CanvasDocPayload
	if len(rec.Document) > 0 {
		if err := json.Unmarshal(rec.Document, &doc); err != nil {
			return err
		}
		r.doc = normalizeCanvasDoc(&doc)
	}
	r.revision = rec.Revision
	t := rec.UpdatedAt
	r.updatedAt = &t
	r.loaded = true
	return nil
}

func (r *canvasRoom) persistLocked(next *CanvasDocPayload, updatedBy uint) (int64, *time.Time, error) {
	rawBytes, err := json.Marshal(next)
	if err != nil {
		return 0, nil, err
	}
	nextRev := r.revision + 1
	now := time.Now()
	rec := model.MealCanvas{
		MealSessionID: r.mealID,
		Revision:      nextRev,
		Document:      model.JSON(rawBytes),
		UpdatedBy:     updatedBy,
		UpdatedAt:     now,
	}
	if err := model.DB.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "meal_session_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"revision", "document", "updated_by", "updated_at"}),
	}).Create(&rec).Error; err != nil {
		return 0, nil, err
	}
	r.doc = cloneCanvasDoc(next)
	r.revision = nextRev
	r.updatedAt = &now
	return nextRev, &now, nil
}

func (r *canvasRoom) snapshotClientsLocked(exclude *canvasClient) []*canvasClient {
	out := make([]*canvasClient, 0, len(r.clients))
	for c := range r.clients {
		if c == exclude {
			continue
		}
		out = append(out, c)
	}
	return out
}

func (r *canvasRoom) onlineUsersLocked() []CanvasActor {
	seen := make(map[uint]bool)
	out := make([]CanvasActor, 0, len(r.clients))
	for c := range r.clients {
		if seen[c.userID] {
			continue
		}
		seen[c.userID] = true
		out = append(out, c.actor)
	}
	return out
}

func (r *canvasRoom) handleOp(c *canvasClient, msg inboundWSMessage) {
	if c.revoked.Load() {
		return
	}
	_, canEdit, _, err := NewCanvasService().CheckAccess(c.userID, r.mealID)
	if err != nil || !canEdit {
		errText := "当前不可编辑画布"
		if err != nil {
			errText = err.Error()
		}
		c.sendError(errText)
		if c.actor.Role == "guest" {
			c.revokeAndDrain()
		}
		return
	}

	clientID := msg.ClientID
	if clientID == "" {
		clientID = c.clientID
	}

	r.mu.Lock()
	if err := r.ensureLoadedLocked(); err != nil {
		r.mu.Unlock()
		c.sendError("加载画布失败")
		return
	}
	nextDoc, changed, replacedByRemote, err := applyCanvasOp(r.doc, r.revision, msg.Kind, msg.Payload)
	if err != nil {
		r.mu.Unlock()
		c.sendError(err.Error())
		return
	}
	if replacedByRemote {
		snapBytes, _ := json.Marshal(map[string]any{
			"type":      "snapshot",
			"meal_id":   r.mealID,
			"revision":  r.revision,
			"actor":     c.actor,
			"client_id": "server",
			"document":  cloneCanvasDoc(r.doc),
		})
		r.mu.Unlock()
		c.enqueue(snapBytes)
		return
	}
	if !changed {
		r.mu.Unlock()
		return
	}
	rev, _, err := r.persistLocked(nextDoc, c.userID)
	if err != nil {
		r.mu.Unlock()
		c.sendError("保存画布失败")
		return
	}
	targets := r.snapshotClientsLocked(nil)
	var outbound []byte
	if msg.Kind == "replace_document" {
		outbound, _ = json.Marshal(map[string]any{
			"type":      "snapshot",
			"meal_id":   r.mealID,
			"revision":  rev,
			"actor":     c.actor,
			"client_id": clientID,
			"document":  cloneCanvasDoc(nextDoc),
		})
	} else {
		outbound, _ = json.Marshal(map[string]any{
			"type":      "op_applied",
			"meal_id":   r.mealID,
			"revision":  rev,
			"actor":     c.actor,
			"client_id": clientID,
			"op_id":     msg.OpID,
			"kind":      msg.Kind,
			"payload":   msg.Payload,
		})
	}
	r.mu.Unlock()

	sendToClients(targets, outbound)
}

func (r *canvasRoom) handleLivePreview(c *canvasClient, msg inboundWSMessage) {
	if !c.canEdit || c.revoked.Load() {
		return
	}
	if c.actor.Role == "guest" {
		needCheck := false
		c.accessCheckMu.Lock()
		if time.Since(c.lastAccessCheck) > 10*time.Second {
			c.lastAccessCheck = time.Now()
			needCheck = true
		}
		c.accessCheckMu.Unlock()
		if needCheck {
			if _, canEdit, _, err := NewCanvasService().CheckAccess(c.userID, r.mealID); err != nil || !canEdit {
				c.revokeAndDrain()
				return
			}
		}
	}
	clientID := msg.ClientID
	if clientID == "" {
		clientID = c.clientID
	}
	outbound, err := json.Marshal(map[string]any{
		"type":             "live_preview",
		"meal_id":          r.mealID,
		"actor":            c.actor,
		"client_id":        clientID,
		"target_kind":      msg.TargetKind,
		"target_id":        msg.TargetID,
		"position":         msg.Position,
		"scale":            msg.Scale,
		"rotation_degrees": msg.RotationDegrees,
		"active_stroke":    msg.ActiveStroke,
	})
	if err != nil {
		return
	}

	r.mu.Lock()
	targets := r.snapshotClientsLocked(c)
	r.mu.Unlock()
	sendToClients(targets, outbound)
}

func (r *canvasRoom) disconnect(c *canvasClient) {
	r.mu.Lock()
	if _, ok := r.clients[c]; !ok {
		r.mu.Unlock()
		return
	}
	delete(r.clients, c)
	users := r.onlineUsersLocked()
	targets := r.snapshotClientsLocked(nil)
	r.mu.Unlock()

	c.closeSend()

	if len(targets) > 0 {
		presenceBytes, _ := json.Marshal(map[string]any{
			"type":         "presence",
			"meal_id":      r.mealID,
			"online_users": users,
		})
		clearBytes, _ := json.Marshal(map[string]any{
			"type":        "live_preview",
			"meal_id":     r.mealID,
			"actor":       c.actor,
			"client_id":   c.clientID,
			"target_kind": "clear",
			"target_id":   "",
		})
		sendToClients(targets, presenceBytes)
		sendToClients(targets, clearBytes)
	}
	r.hub.evictIfEmpty(r)
}

func (c *canvasClient) enqueue(data []byte) {
	c.sendMu.Lock()
	defer c.sendMu.Unlock()
	if c.closed {
		return
	}
	select {
	case c.send <- data:
	default:
		// 慢消费者直接关闭，避免阻塞同房其他成员广播
		c.closed = true
		close(c.send)
		_ = c.conn.Close()
	}
}

func (c *canvasClient) closeSend() {
	c.sendMu.Lock()
	defer c.sendMu.Unlock()
	if !c.closed {
		c.closed = true
		close(c.send)
	}
}

func (c *canvasClient) revokeAndDrain() {
	if !c.revoked.CompareAndSwap(false, true) {
		return
	}
	c.closeSend()
	time.AfterFunc(2*time.Second, func() {
		_ = c.conn.Close()
	})
}

func (c *canvasClient) sendError(msg string) {
	b, _ := json.Marshal(map[string]any{
		"type":    "error",
		"meal_id": c.room.mealID,
		"message": msg,
	})
	c.enqueue(b)
}

func (c *canvasClient) readPump() {
	defer func() {
		c.room.disconnect(c)
		_ = c.conn.Close()
	}()
	c.conn.SetReadLimit(2 * 1024 * 1024)
	_ = c.conn.SetReadDeadline(time.Now().Add(65 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(65 * time.Second))
		return nil
	})

	for {
		if c.revoked.Load() {
			return
		}
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("[CanvasWS] 读消息断开 meal=%d uid=%d err=%v", c.room.mealID, c.userID, err)
			}
			return
		}
		_ = c.conn.SetReadDeadline(time.Now().Add(65 * time.Second))
		if c.revoked.Load() {
			return
		}
		var msg inboundWSMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			c.sendError("消息格式有误")
			continue
		}
		switch msg.Type {
		case "ping":
			pong, _ := json.Marshal(map[string]any{"type": "pong"})
			c.enqueue(pong)
		case "live_preview":
			c.room.handleLivePreview(c, msg)
		case "op":
			c.room.handleOp(c, msg)
		}
	}
}

func (c *canvasClient) writePump() {
	ticker := time.NewTicker(25 * time.Second)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()
	for {
		select {
		case data, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func sendToClients(targets []*canvasClient, data []byte) {
	if len(data) == 0 {
		return
	}
	for _, c := range targets {
		c.enqueue(data)
	}
}
