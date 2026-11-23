package service

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
)

// CanvasService 餐次自由画布权限校验、存储与增量操作合并服务
type CanvasService struct{}

// NewCanvasService 构造
func NewCanvasService() *CanvasService {
	return &CanvasService{}
}

// CanvasDocPayload 与 iOS CanvasDocument 对齐的画布文档载荷（剥离本地图片二进制）
type CanvasDocPayload struct {
	SchemaVersion       int               `json:"schemaVersion"`
	Background          string            `json:"background"`
	Blur                float64           `json:"blur"`
	MoodFilter          string            `json:"moodFilter"`
	CustomBackgroundURL *string           `json:"customBackgroundURL,omitempty"`
	Stickers            []json.RawMessage `json:"stickers"`
	Notes               []json.RawMessage `json:"notes"`
	Strokes             []json.RawMessage `json:"strokes"`
	Size                json.RawMessage   `json:"size,omitempty"`
}

// CanvasSnapshotResponse REST 获取/保存画布返回结构
type CanvasSnapshotResponse struct {
	MealID    uint              `json:"meal_id"`
	Revision  int64             `json:"revision"`
	Document  *CanvasDocPayload `json:"document"`
	UpdatedAt *time.Time        `json:"updated_at,omitempty"`
}

// CanvasOpPayload WebSocket 增量操作载荷
type CanvasOpPayload struct {
	Sticker                  json.RawMessage   `json:"sticker,omitempty"`
	Note                     json.RawMessage   `json:"note,omitempty"`
	Stroke                   json.RawMessage   `json:"stroke,omitempty"`
	ID                       string            `json:"id,omitempty"`
	MealDishID               *uint             `json:"meal_dish_id,omitempty"`
	Background               *string           `json:"background,omitempty"`
	Blur                     *float64          `json:"blur,omitempty"`
	MoodFilter               *string           `json:"mood_filter,omitempty"`
	CustomBackgroundURL      *string           `json:"custom_background_url,omitempty"`
	ClearCustomBackgroundURL bool              `json:"clear_custom_background_url,omitempty"`
	Stickers                 []json.RawMessage `json:"stickers,omitempty"`
	Notes                    []json.RawMessage `json:"notes,omitempty"`
	Document                 *CanvasDocPayload `json:"document,omitempty"`
	OnlyIfEmpty              bool              `json:"only_if_empty,omitempty"`
}

type canvasStickerMeta struct {
	ID         string `json:"id"`
	MealDishID *uint  `json:"mealDishID"`
}

type canvasIDMeta struct {
	ID string `json:"id"`
}

// CheckAccess 检查用户对指定餐次画布的读写权限与身份角色（host / guest）
func (s *CanvasService) CheckAccess(userID, mealID uint) (canRead bool, canEdit bool, role string, err error) {
	var m model.MealSession
	if err := model.DB.First(&m, mealID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, false, "", errors.New("这一顿不存在")
		}
		return false, false, "", err
	}

	var u model.User
	if err := model.DB.Where("id = ? AND is_active = ?", userID, true).First(&u).Error; err != nil {
		return false, false, "", errors.New("用户不存在或已停用")
	}

	editableStatus := m.Status == model.MealStatusPlanning || m.Status == model.MealStatusConfirmed
	if u.HouseholdID != nil && *u.HouseholdID == m.HouseholdID {
		return true, editableStatus, "host", nil
	}

	if roomAlive(&m) {
		var cnt int64
		if err := model.DB.Model(&model.MealParticipant{}).
			Where("meal_session_id = ? AND user_id = ?", m.ID, userID).
			Count(&cnt).Error; err != nil {
			return false, false, "", err
		}
		if cnt > 0 {
			return true, editableStatus, "guest", nil
		}
	}

	return false, false, "", errors.New("无权访问这顿画布")
}

// Get 获取餐次画布当前快照
func (s *CanvasService) Get(userID, mealID uint) (*CanvasSnapshotResponse, error) {
	canRead, _, _, err := s.CheckAccess(userID, mealID)
	if err != nil {
		return nil, err
	}
	if !canRead {
		return nil, errors.New("无权访问这顿画布")
	}
	return GlobalCanvasHub().GetSnapshot(mealID)
}

// Save 全量保存餐次画布并广播快照
func (s *CanvasService) Save(userID, mealID uint, doc *CanvasDocPayload, clientID string) (*CanvasSnapshotResponse, error) {
	if doc == nil {
		return nil, errors.New("画布内容不能为空")
	}
	_, canEdit, role, err := s.CheckAccess(userID, mealID)
	if err != nil {
		return nil, err
	}
	if !canEdit {
		return nil, errors.New("当前餐次状态不可编辑画布")
	}
	actor := loadCanvasActor(userID, role)
	return GlobalCanvasHub().SaveDocument(mealID, doc, actor, clientID)
}

func loadCanvasActor(userID uint, role string) CanvasActor {
	var u model.User
	actor := CanvasActor{ID: userID, Nickname: "好友", Role: role}
	if err := model.DB.Select("id, nickname, avatar").First(&u, userID).Error; err == nil {
		if n := strings.TrimSpace(u.Nickname); n != "" {
			actor.Nickname = n
		}
		actor.Avatar = u.Avatar
	}
	return actor
}

func defaultCanvasDoc() *CanvasDocPayload {
	return &CanvasDocPayload{
		SchemaVersion: 3,
		Background:    "meadow",
		Blur:          0,
		MoodFilter:    "none",
		Stickers:      []json.RawMessage{},
		Notes:         []json.RawMessage{},
		Strokes:       []json.RawMessage{},
	}
}

func normalizeCanvasDoc(doc *CanvasDocPayload) *CanvasDocPayload {
	if doc == nil {
		return defaultCanvasDoc()
	}
	cp := *doc
	if cp.SchemaVersion < 3 {
		cp.SchemaVersion = 3
	}
	if strings.TrimSpace(cp.Background) == "" {
		cp.Background = "meadow"
	}
	if strings.TrimSpace(cp.MoodFilter) == "" {
		cp.MoodFilter = "none"
	}
	if cp.Stickers == nil {
		cp.Stickers = []json.RawMessage{}
	} else {
		cp.Stickers = append([]json.RawMessage(nil), cp.Stickers...)
	}
	if cp.Notes == nil {
		cp.Notes = []json.RawMessage{}
	} else {
		cp.Notes = append([]json.RawMessage(nil), cp.Notes...)
	}
	if cp.Strokes == nil {
		cp.Strokes = []json.RawMessage{}
	} else {
		cp.Strokes = append([]json.RawMessage(nil), cp.Strokes...)
	}
	return &cp
}

func cloneCanvasDoc(doc *CanvasDocPayload) *CanvasDocPayload {
	if doc == nil {
		return nil
	}
	return normalizeCanvasDoc(doc)
}

// applyCanvasOp 将单次操作合并到画布副本上；onlyIfEmpty 被跳过时返回 replacedByRemote=true, changed=false
func applyCanvasOp(doc *CanvasDocPayload, currentRev int64, kind string, payload CanvasOpPayload) (next *CanvasDocPayload, changed bool, replacedByRemote bool, err error) {
	if doc == nil {
		next = defaultCanvasDoc()
	} else {
		next = cloneCanvasDoc(doc)
	}

	switch kind {
	case "upsert_sticker":
		if len(payload.Sticker) == 0 {
			return nil, false, false, errors.New("缺少 sticker 数据")
		}
		var meta canvasStickerMeta
		if err := json.Unmarshal(payload.Sticker, &meta); err != nil || strings.TrimSpace(meta.ID) == "" {
			return nil, false, false, errors.New("sticker 格式不合法")
		}
		idx := -1
		for i, raw := range next.Stickers {
			var cur canvasStickerMeta
			if json.Unmarshal(raw, &cur) != nil {
				continue
			}
			if strings.EqualFold(cur.ID, meta.ID) || (meta.MealDishID != nil && cur.MealDishID != nil && *meta.MealDishID == *cur.MealDishID) {
				idx = i
				break
			}
		}
		if idx >= 0 {
			next.Stickers[idx] = payload.Sticker
		} else {
			next.Stickers = append(next.Stickers, payload.Sticker)
		}
		return next, true, false, nil

	case "delete_sticker":
		targetID := strings.TrimSpace(payload.ID)
		if targetID == "" && payload.MealDishID == nil {
			return nil, false, false, errors.New("缺少待删除 sticker 标识")
		}
		filtered := make([]json.RawMessage, 0, len(next.Stickers))
		removed := false
		for _, raw := range next.Stickers {
			var cur canvasStickerMeta
			if json.Unmarshal(raw, &cur) == nil {
				matchID := targetID != "" && strings.EqualFold(cur.ID, targetID)
				matchDish := payload.MealDishID != nil && cur.MealDishID != nil && *payload.MealDishID == *cur.MealDishID
				if matchID || matchDish {
					removed = true
					continue
				}
			}
			filtered = append(filtered, raw)
		}
		if !removed {
			return next, false, false, nil
		}
		next.Stickers = filtered
		return next, true, false, nil

	case "upsert_note":
		if len(payload.Note) == 0 {
			return nil, false, false, errors.New("缺少 note 数据")
		}
		var meta canvasIDMeta
		if err := json.Unmarshal(payload.Note, &meta); err != nil || strings.TrimSpace(meta.ID) == "" {
			return nil, false, false, errors.New("note 格式不合法")
		}
		idx := findIDIndex(next.Notes, meta.ID)
		if idx >= 0 {
			next.Notes[idx] = payload.Note
		} else {
			next.Notes = append(next.Notes, payload.Note)
		}
		return next, true, false, nil

	case "delete_note":
		targetID := strings.TrimSpace(payload.ID)
		if targetID == "" {
			return nil, false, false, errors.New("缺少 note id")
		}
		filtered, removed := removeByID(next.Notes, targetID)
		if !removed {
			return next, false, false, nil
		}
		next.Notes = filtered
		return next, true, false, nil

	case "add_stroke":
		if len(payload.Stroke) == 0 {
			return nil, false, false, errors.New("缺少 stroke 数据")
		}
		var meta canvasIDMeta
		if err := json.Unmarshal(payload.Stroke, &meta); err == nil && strings.TrimSpace(meta.ID) != "" {
			if idx := findIDIndex(next.Strokes, meta.ID); idx >= 0 {
				next.Strokes[idx] = payload.Stroke
				return next, true, false, nil
			}
		}
		next.Strokes = append(next.Strokes, payload.Stroke)
		return next, true, false, nil

	case "delete_stroke":
		targetID := strings.TrimSpace(payload.ID)
		if targetID == "" {
			if len(next.Strokes) == 0 {
				return next, false, false, nil
			}
			next.Strokes = next.Strokes[:len(next.Strokes)-1]
			return next, true, false, nil
		}
		filtered, removed := removeByID(next.Strokes, targetID)
		if !removed {
			return next, false, false, nil
		}
		next.Strokes = filtered
		return next, true, false, nil

	case "clear_strokes":
		if len(next.Strokes) == 0 {
			return next, false, false, nil
		}
		next.Strokes = []json.RawMessage{}
		return next, true, false, nil

	case "clear_additions":
		if len(next.Notes) == 0 && len(next.Strokes) == 0 {
			return next, false, false, nil
		}
		next.Notes = []json.RawMessage{}
		next.Strokes = []json.RawMessage{}
		return next, true, false, nil

	case "update_background":
		if payload.Background != nil && strings.TrimSpace(*payload.Background) != "" {
			next.Background = strings.TrimSpace(*payload.Background)
		}
		if payload.Blur != nil {
			next.Blur = *payload.Blur
		}
		if payload.MoodFilter != nil && strings.TrimSpace(*payload.MoodFilter) != "" {
			next.MoodFilter = strings.TrimSpace(*payload.MoodFilter)
		}
		if payload.ClearCustomBackgroundURL {
			next.CustomBackgroundURL = nil
		} else if payload.CustomBackgroundURL != nil {
			trimmed := strings.TrimSpace(*payload.CustomBackgroundURL)
			if trimmed == "" {
				next.CustomBackgroundURL = nil
			} else {
				next.CustomBackgroundURL = &trimmed
			}
		}
		return next, true, false, nil

	case "batch_stickers_notes":
		if payload.Stickers != nil {
			next.Stickers = append([]json.RawMessage(nil), payload.Stickers...)
		}
		if payload.Notes != nil {
			next.Notes = append([]json.RawMessage(nil), payload.Notes...)
		}
		return next, true, false, nil

	case "replace_document":
		if payload.Document == nil {
			return nil, false, false, errors.New("缺少 document")
		}
		if payload.OnlyIfEmpty && currentRev > 0 {
			return next, false, true, nil
		}
		return normalizeCanvasDoc(payload.Document), true, false, nil

	default:
		return nil, false, false, errors.New("不支持的画布操作类型")
	}
}

func findIDIndex(items []json.RawMessage, id string) int {
	for i, raw := range items {
		var meta canvasIDMeta
		if json.Unmarshal(raw, &meta) == nil && strings.EqualFold(meta.ID, id) {
			return i
		}
	}
	return -1
}

func removeByID(items []json.RawMessage, id string) ([]json.RawMessage, bool) {
	filtered := make([]json.RawMessage, 0, len(items))
	removed := false
	for _, raw := range items {
		var meta canvasIDMeta
		if json.Unmarshal(raw, &meta) == nil && strings.EqualFold(meta.ID, id) {
			removed = true
			continue
		}
		filtered = append(filtered, raw)
	}
	return filtered, removed
}
