package service

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"maps"
	"strings"
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

type cachedLivePreview struct {
	data      []byte
	updatedAt time.Time
}

type storedCanvasDocument struct {
	*CanvasDocPayload
	AppliedOpIDs map[string]bool `json:"appliedOpIDs,omitempty"`
}

type canvasRoom struct {
	hub            *CanvasHub
	mealID         uint
	householdID    uint
	mu             sync.Mutex
	clients        map[*canvasClient]struct{}
	activePreviews map[string]cachedLivePreview
	appliedOpIDs   map[string]bool
	loaded         bool
	evicted        bool
	revision       int64
	doc            *CanvasDocPayload
	updatedAt      *time.Time
}

type canvasClient struct {
	room     *canvasRoom
	conn     *websocket.Conn
	userID   uint
	clientID string
	actorMu  sync.RWMutex
	actor    CanvasActor
	canEdit  bool

	revoked         atomic.Bool
	accessCheckMu   sync.Mutex
	lastAccessCheck time.Time

	sendMu sync.Mutex
	send   chan []byte
	closed bool
}

func (c *canvasClient) snapshotActor() CanvasActor {
	c.actorMu.RLock()
	a := c.actor
	c.actorMu.RUnlock()
	return a
}

func (c *canvasClient) updateActorProfile(nickname, avatar string) bool {
	c.actorMu.Lock()
	defer c.actorMu.Unlock()
	changed := c.actor.Nickname != nickname || c.actor.Avatar != avatar
	c.actor.Nickname = nickname
	c.actor.Avatar = avatar
	return changed
}

type inboundWSMessage struct {
	Type            string          `json:"type"`
	ClientID        string          `json:"client_id"`
	OpID            string          `json:"op_id"`
	Kind            string          `json:"kind"`
	Payload         CanvasOpPayload `json:"payload"`
	Revision        *int64          `json:"revision,omitempty"`
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

// BroadcastHouseholdSync 同一个家的共享资料变化时（菜谱、分类、成员资料、收藏贴图、历史、共享开屏、购物清单）推送给在线家庭房间
func (h *CanvasHub) BroadcastHouseholdSync(householdID uint, reason string, actorID uint) {
	if householdID == 0 {
		return
	}
	h.mu.Lock()
	rooms := make([]*canvasRoom, 0, len(h.rooms))
	for _, r := range h.rooms {
		rooms = append(rooms, r)
	}
	h.mu.Unlock()

	for _, r := range rooms {
		r.mu.Lock()
		if r.evicted {
			r.mu.Unlock()
			continue
		}
		r.ensureHouseholdLocked()
		if r.householdID != householdID {
			r.mu.Unlock()
			continue
		}
		var targets []*canvasClient
		if reason == "recipes_changed" {
			targets = r.snapshotClientsLocked(nil)
		} else {
			targets = make([]*canvasClient, 0, len(r.clients))
			for c := range r.clients {
				if c.snapshotActor().Role == "host" {
					targets = append(targets, c)
				}
			}
		}
		mealID := r.mealID
		r.mu.Unlock()
		if len(targets) == 0 {
			continue
		}
		msg, _ := json.Marshal(map[string]any{
			"type":     "meal_sync",
			"meal_id":  mealID,
			"reason":   reason,
			"actor_id": actorID,
		})
		sendToClients(targets, msg)
	}
}

// DeleteDishSticker 服务端删菜后同步从画布文档移除对应菜品贴图并广播，避免脏贴图残留或双端互删竞态
func (h *CanvasHub) DeleteDishSticker(mealID, dishID, actorID uint) {
	if mealID == 0 || dishID == 0 {
		return
	}
	r := h.acquireLiveRoomLocked(mealID)
	defer h.evictIfEmpty(r)

	if err := r.ensureLoadedLocked(); err != nil || r.doc == nil {
		r.mu.Unlock()
		return
	}
	dishIDCopy := dishID
	payload := CanvasOpPayload{MealDishID: &dishIDCopy}
	nextDoc, changed, _, err := applyCanvasOp(r.doc, r.revision, mealID, "delete_sticker", payload)
	if err != nil || !changed {
		r.mu.Unlock()
		return
	}
	rev, _, err := r.persistLocked(nextDoc, actorID)
	if err != nil {
		r.mu.Unlock()
		return
	}
	targets := r.snapshotClientsLocked(nil)
	r.mu.Unlock()

	if len(targets) > 0 {
		actor := CanvasActor{ID: actorID, Nickname: "系统", Role: "system"}
		if actorID > 0 {
			actor = loadCanvasActor(actorID, "host")
		}
		outbound, _ := json.Marshal(map[string]any{
			"type":      "op_applied",
			"meal_id":   mealID,
			"revision":  rev,
			"actor":     actor,
			"client_id": "server",
			"op_id":     fmt.Sprintf("srv-del-%d-%d-%d", mealID, dishID, rev),
			"kind":      "delete_sticker",
			"payload":   payload,
		})
		sendToClients(targets, outbound)
	}
}

// UpdateDishStickerImage 当一顿里的某道菜换了本顿实拍/往期图时，原位同步画布文档中对应贴图的图片并广播。
func (h *CanvasHub) UpdateDishStickerImage(mealID, dishID uint, image string, isCutout bool, actorID uint) {
	if mealID == 0 || dishID == 0 {
		return
	}
	r := h.acquireLiveRoomLocked(mealID)
	defer h.evictIfEmpty(r)

	if err := r.ensureLoadedLocked(); err != nil || r.doc == nil {
		r.mu.Unlock()
		return
	}

	nextDoc := cloneCanvasDoc(r.doc)
	updatedStickers := make([]json.RawMessage, 0, 1)
	for i, raw := range nextDoc.Stickers {
		var meta canvasStickerMeta
		if json.Unmarshal(raw, &meta) != nil || meta.MealDishID == nil || *meta.MealDishID != dishID {
			continue
		}
		var stickerMap map[string]any
		if json.Unmarshal(raw, &stickerMap) != nil {
			continue
		}
		stickerMap["image"] = image
		stickerMap["isCutout"] = isCutout
		encoded, err := json.Marshal(stickerMap)
		if err != nil {
			continue
		}
		nextDoc.Stickers[i] = encoded
		updatedStickers = append(updatedStickers, encoded)
	}

	if len(updatedStickers) == 0 {
		r.mu.Unlock()
		return
	}

	rev, _, err := r.persistLocked(nextDoc, actorID)
	if err != nil {
		r.mu.Unlock()
		return
	}
	targets := r.snapshotClientsLocked(nil)
	r.mu.Unlock()

	if len(targets) > 0 {
		actor := CanvasActor{ID: actorID, Nickname: "系统", Role: "system"}
		if actorID > 0 {
			actor = loadCanvasActor(actorID, "host")
		}
		for idx, stickerRaw := range updatedStickers {
			payload := CanvasOpPayload{Sticker: stickerRaw}
			outbound, _ := json.Marshal(map[string]any{
				"type":      "op_applied",
				"meal_id":   mealID,
				"revision":  rev,
				"actor":     actor,
				"client_id": "server",
				"op_id":     fmt.Sprintf("srv-dishimg-%d-%d-%d-%d", mealID, dishID, rev, idx),
				"kind":      "upsert_sticker",
				"payload":   payload,
			})
			sendToClients(targets, outbound)
		}
	}
}

// RefreshUserActor 用户更新头像或昵称后，刷新在线房间里的节点头像/昵称并广播最新 presence
func (h *CanvasHub) RefreshUserActor(userID uint) {
	if userID == 0 {
		return
	}
	var u model.User
	nickname := "好友"
	avatar := ""
	if err := model.DB.Select("id, nickname, avatar").First(&u, userID).Error; err == nil {
		if n := strings.TrimSpace(u.Nickname); n != "" {
			nickname = n
		}
		avatar = u.Avatar
	}

	h.mu.Lock()
	rooms := make([]*canvasRoom, 0, len(h.rooms))
	for _, r := range h.rooms {
		rooms = append(rooms, r)
	}
	h.mu.Unlock()

	for _, r := range rooms {
		r.mu.Lock()
		if r.evicted {
			r.mu.Unlock()
			continue
		}
		updated := false
		for c := range r.clients {
			if c.userID == userID && c.updateActorProfile(nickname, avatar) {
				updated = true
			}
		}
		if !updated {
			r.mu.Unlock()
			continue
		}
		users := r.onlineUsersLocked()
		targets := r.snapshotClientsLocked(nil)
		mealID := r.mealID
		r.mu.Unlock()

		if len(targets) > 0 {
			presenceBytes, _ := json.Marshal(map[string]any{
				"type":         "presence",
				"meal_id":      mealID,
				"online_users": users,
			})
			sendToClients(targets, presenceBytes)
		}
	}
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
		if c.snapshotActor().Role == "guest" {
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
		if c.userID == userID && c.snapshotActor().Role == "guest" {
			targets = append(targets, c)
		}
	}
	r.mu.Unlock()
	for _, c := range targets {
		c.revokeAndDrain()
	}
}

// EvictHouseholdMember immediately closes every connection the user opened as a household member.
func (h *CanvasHub) EvictHouseholdMember(householdID, userID uint) {
	h.mu.Lock()
	rooms := make([]*canvasRoom, 0, len(h.rooms))
	for _, r := range h.rooms {
		rooms = append(rooms, r)
	}
	h.mu.Unlock()

	for _, r := range rooms {
		r.mu.Lock()
		if r.householdID == householdID {
			for c := range r.clients {
				if c.userID == userID && c.snapshotActor().Role == "host" {
					c.revoked.Store(true)
					_ = c.conn.Close()
				}
			}
		}
		r.mu.Unlock()
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
	if role == "host" {
		var memberCount int64
		err := model.DB.Model(&model.User{}).
			Where("id = ? AND household_id = ? AND is_active = ?", userID, r.householdID, true).
			Count(&memberCount).Error
		if err != nil || memberCount == 0 {
			r.mu.Unlock()
			_ = conn.Close()
			h.evictIfEmpty(r)
			return
		}
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
	now := time.Now()
	var activePreviewPayloads [][]byte
	for cid, entry := range r.activePreviews {
		if now.Sub(entry.updatedAt) >= 2*time.Second {
			delete(r.activePreviews, cid)
			continue
		}
		if cid != clientID && len(entry.data) > 0 {
			activePreviewPayloads = append(activePreviewPayloads, entry.data)
		}
	}
	otherTargets := r.snapshotClientsLocked(c)
	c.enqueue(welcomeBytes)
	for _, previewBytes := range activePreviewPayloads {
		c.enqueueDropIfFull(previewBytes)
	}
	r.mu.Unlock()
	sendToClients(otherTargets, presenceBytes)

	go c.writePump()
	c.readPump()
}

func (r *canvasRoom) ensureHouseholdLocked() {
	if r.householdID > 0 {
		return
	}
	var hid uint
	if err := model.DB.Model(&model.MealSession{}).Select("household_id").Where("id = ?", r.mealID).Scan(&hid).Error; err == nil && hid > 0 {
		r.householdID = hid
	}
}

func (r *canvasRoom) ensureLoadedLocked() error {
	r.ensureHouseholdLocked()
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
	doc := storedCanvasDocument{CanvasDocPayload: &CanvasDocPayload{}}
	if len(rec.Document) > 0 {
		if err := json.Unmarshal(rec.Document, &doc); err != nil {
			return err
		}
		r.doc = normalizeCanvasDoc(doc.CanvasDocPayload)
		r.appliedOpIDs = doc.AppliedOpIDs
	}
	r.revision = rec.Revision
	t := rec.UpdatedAt
	r.updatedAt = &t
	r.loaded = true
	return nil
}

func (r *canvasRoom) persistLocked(next *CanvasDocPayload, updatedBy uint, opIDs ...string) (int64, *time.Time, error) {
	appliedOpIDs := r.appliedOpIDs
	if len(opIDs) > 0 {
		appliedOpIDs = maps.Clone(appliedOpIDs)
		if appliedOpIDs == nil {
			appliedOpIDs = make(map[string]bool, len(opIDs))
		}
		for _, opID := range opIDs {
			if opID != "" {
				appliedOpIDs[opID] = true
			}
		}
	}
	rawBytes, err := json.Marshal(storedCanvasDocument{CanvasDocPayload: next, AppliedOpIDs: appliedOpIDs})
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
	r.appliedOpIDs = appliedOpIDs
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
		out = append(out, c.snapshotActor())
	}
	return out
}

func (r *canvasRoom) handleOp(c *canvasClient, msg inboundWSMessage) {
	if c.revoked.Load() {
		return
	}
	actor := c.snapshotActor()
	_, canEdit, _, err := NewCanvasService().CheckAccess(c.userID, r.mealID)
	if err != nil || !canEdit {
		errText := "当前不可编辑画布"
		if err != nil {
			errText = err.Error()
		}
		c.sendError(errText)
		if actor.Role == "guest" {
			c.revokeAndDrain()
		}
		return
	}

	clientID := msg.ClientID
	if clientID == "" {
		clientID = c.clientID
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if c.revoked.Load() {
		return
	}
	delete(r.activePreviews, clientID)
	if err := r.ensureLoadedLocked(); err != nil {
		c.sendError("加载画布失败")
		return
	}
	if r.appliedOpIDs[msg.OpID] {
		c.enqueue(r.operationSnapshotLocked(actor, clientID, msg.OpID, nil))
		return
	}
	nextDoc, changed, replacedByRemote, err := applyCanvasOp(r.doc, r.revision, r.mealID, msg.Kind, msg.Payload)
	if err != nil {
		c.sendError(err.Error())
		return
	}
	if replacedByRemote {
		c.enqueue(r.operationSnapshotLocked(actor, clientID, msg.OpID, nil))
		return
	}
	var seedOpIDs []string
	if msg.Kind == "replace_document" && msg.Payload.OnlyIfEmpty {
		seedOpIDs = msg.Payload.SeedOpIDs
	}
	opIDs := append([]string{msg.OpID}, seedOpIDs...)
	rev, _, err := r.persistLocked(nextDoc, c.userID, opIDs...)
	if err != nil {
		c.sendError("保存画布失败")
		c.revokeAndDrain()
		return
	}
	targets := r.snapshotClientsLocked(nil)
	var outbound []byte
	if msg.Kind == "replace_document" || !changed {
		outbound = r.operationSnapshotLocked(actor, clientID, msg.OpID, seedOpIDs)
	} else {
		outbound, _ = json.Marshal(map[string]any{
			"type":      "op_applied",
			"meal_id":   r.mealID,
			"revision":  rev,
			"actor":     actor,
			"client_id": clientID,
			"op_id":     msg.OpID,
			"kind":      msg.Kind,
			"payload":   msg.Payload,
		})
	}
	sendToClients(targets, outbound)
}

func (r *canvasRoom) operationSnapshotLocked(actor CanvasActor, clientID, opID string, seedOpIDs []string) []byte {
	data, _ := json.Marshal(map[string]any{
		"type":        "snapshot",
		"meal_id":     r.mealID,
		"revision":    r.revision,
		"actor":       actor,
		"client_id":   clientID,
		"op_id":       opID,
		"seed_op_ids": seedOpIDs,
		"document":    r.doc,
	})
	return data
}

func (r *canvasRoom) handleLivePreview(c *canvasClient, msg inboundWSMessage) {
	if !c.canEdit || c.revoked.Load() {
		return
	}
	actor := c.snapshotActor()
	if actor.Role == "guest" {
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
		"actor":            actor,
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
	if msg.TargetKind == "clear" {
		delete(r.activePreviews, clientID)
	} else {
		if r.activePreviews == nil {
			r.activePreviews = make(map[string]cachedLivePreview)
		}
		r.activePreviews[clientID] = cachedLivePreview{
			data:      outbound,
			updatedAt: time.Now(),
		}
	}
	targets := r.snapshotClientsLocked(c)
	r.mu.Unlock()
	sendToClientsBestEffort(targets, outbound)
}

func (r *canvasRoom) handlePing(c *canvasClient, clientRev *int64) {
	if c.revoked.Load() {
		return
	}
	r.mu.Lock()
	rev := r.revision
	var catchUpDoc *CanvasDocPayload
	if clientRev != nil && rev > *clientRev && r.doc != nil {
		catchUpDoc = cloneCanvasDoc(r.doc)
	}
	r.mu.Unlock()

	pong, _ := json.Marshal(map[string]any{
		"type":     "pong",
		"meal_id":  r.mealID,
		"revision": rev,
	})
	c.enqueue(pong)

	if catchUpDoc != nil {
		snapBytes, _ := json.Marshal(map[string]any{
			"type":      "snapshot",
			"meal_id":   r.mealID,
			"revision":  rev,
			"client_id": "server",
			"document":  catchUpDoc,
		})
		c.enqueue(snapBytes)
	}
}

func (r *canvasRoom) handleResync(c *canvasClient) {
	if c.revoked.Load() {
		return
	}
	r.mu.Lock()
	if err := r.ensureLoadedLocked(); err != nil {
		r.mu.Unlock()
		c.sendError("同步画布失败")
		return
	}
	rev := r.revision
	var docCopy *CanvasDocPayload
	if rev > 0 && r.doc != nil {
		docCopy = cloneCanvasDoc(r.doc)
	}
	users := r.onlineUsersLocked()
	r.mu.Unlock()

	presenceBytes, _ := json.Marshal(map[string]any{
		"type":         "presence",
		"meal_id":      r.mealID,
		"online_users": users,
	})
	c.enqueue(presenceBytes)

	if docCopy != nil {
		snapBytes, _ := json.Marshal(map[string]any{
			"type":      "snapshot",
			"meal_id":   r.mealID,
			"revision":  rev,
			"client_id": "server",
			"document":  docCopy,
		})
		c.enqueue(snapBytes)
	}
}

func (r *canvasRoom) disconnect(c *canvasClient) {
	r.mu.Lock()
	if _, ok := r.clients[c]; !ok {
		r.mu.Unlock()
		return
	}
	delete(r.clients, c)
	delete(r.activePreviews, c.clientID)
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
			"actor":       c.snapshotActor(),
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

func (c *canvasClient) enqueueDropIfFull(data []byte) {
	c.sendMu.Lock()
	defer c.sendMu.Unlock()
	if c.closed {
		return
	}
	select {
	case c.send <- data:
	default:
		// 高频预览帧队满直接丢弃，不踢掉正在恢复中的连接
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
			c.room.handlePing(c, msg.Revision)
		case "resync":
			c.room.handleResync(c)
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

func sendToClientsBestEffort(targets []*canvasClient, data []byte) {
	if len(data) == 0 {
		return
	}
	for _, c := range targets {
		c.enqueueDropIfFull(data)
	}
}
