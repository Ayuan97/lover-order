package service

import (
	"bytes"
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
	Sticker                  json.RawMessage      `json:"sticker,omitempty"`
	Note                     json.RawMessage      `json:"note,omitempty"`
	Stroke                   json.RawMessage      `json:"stroke,omitempty"`
	ID                       string               `json:"id,omitempty"`
	MealDishID               *uint                `json:"meal_dish_id,omitempty"`
	Background               *string              `json:"background,omitempty"`
	Blur                     *float64             `json:"blur,omitempty"`
	MoodFilter               *string              `json:"mood_filter,omitempty"`
	CustomBackgroundURL      *string              `json:"custom_background_url,omitempty"`
	ClearCustomBackgroundURL bool                 `json:"clear_custom_background_url,omitempty"`
	Stickers                 []json.RawMessage    `json:"stickers,omitempty"`
	Notes                    []json.RawMessage    `json:"notes,omitempty"`
	StickerPatches           []canvasStickerPatch `json:"sticker_patches,omitempty"`
	NotePatches              []canvasNotePatch    `json:"note_patches,omitempty"`
	StickerIDs               []string             `json:"sticker_ids,omitempty"`
	NoteIDs                  []string             `json:"note_ids,omitempty"`
	StrokeIDs                []string             `json:"stroke_ids,omitempty"`
	Document                 *CanvasDocPayload    `json:"document,omitempty"`
	OnlyIfEmpty              bool                 `json:"only_if_empty,omitempty"`
	SeedOpIDs                []string             `json:"seed_op_ids,omitempty"`
}

type canvasStickerMeta struct {
	ID         string `json:"id"`
	MealDishID *uint  `json:"mealDishID"`
}

type canvasIDMeta struct {
	ID string `json:"id"`
}

type canvasPatchPosition struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

type canvasElementPatch struct {
	ID              string               `json:"id"`
	Position        *canvasPatchPosition `json:"position,omitempty"`
	Scale           *float64             `json:"scale,omitempty"`
	RotationDegrees *float64             `json:"rotationDegrees,omitempty"`
	Layer           *int                 `json:"layer,omitempty"`
}

type canvasStickerPatch struct {
	canvasElementPatch
	MealDishID *uint   `json:"mealDishID,omitempty"`
	Effect     *string `json:"effect,omitempty"`
	Style      *string `json:"style,omitempty"`
}

type canvasNotePatch struct {
	canvasElementPatch
	Text       *string `json:"text,omitempty"`
	Font       *string `json:"font,omitempty"`
	Color      *string `json:"color,omitempty"`
	TextStyle  *string `json:"textStyle,omitempty"`
	TextEffect *string `json:"textEffect,omitempty"`
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

func cloneRawSlice(in []json.RawMessage) []json.RawMessage {
	out := make([]json.RawMessage, len(in))
	copy(out, in)
	return out
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
	// Go 中 append([]T(nil), empty...) 会返回 nil，被编码成 JSON null；用 make 保证空数组始终输出 []
	cp.Stickers = cloneRawSlice(cp.Stickers)
	cp.Notes = cloneRawSlice(cp.Notes)
	cp.Strokes = cloneRawSlice(cp.Strokes)
	return &cp
}

func cloneCanvasDoc(doc *CanvasDocPayload) *CanvasDocPayload {
	if doc == nil {
		return nil
	}
	return normalizeCanvasDoc(doc)
}

// applyCanvasOp 合并单次操作，并将菜图校正写回用于广播的载荷。
func applyCanvasOp(doc *CanvasDocPayload, currentRev int64, mealID uint, kind string, payload *CanvasOpPayload) (next *CanvasDocPayload, changed bool, replacedByRemote bool, err error) {
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
		idx := findStickerIndex(next.Stickers, meta.ID, meta.MealDishID)
		if meta.MealDishID != nil {
			if idx >= 0 {
				return next, false, false, nil
			}
			dish, err := loadCanvasDish(mealID, *meta.MealDishID)
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return next, false, false, nil
			}
			if err != nil {
				return nil, false, false, err
			}
			next.Stickers = append(next.Stickers, payload.Sticker)
			index := len(next.Stickers) - 1
			if _, err := patchCanvasDishPhoto(next.Stickers, index, dish); err != nil {
				return nil, false, false, err
			}
			payload.Sticker = next.Stickers[index]
			return next, true, false, nil
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
			if err := syncCanvasDishPhotos(mealID, payload.Stickers); err != nil {
				return nil, false, false, err
			}
			next.Stickers = cloneRawSlice(payload.Stickers)
		}
		if payload.Notes != nil {
			next.Notes = cloneRawSlice(payload.Notes)
		}
		return next, true, false, nil

	case "batch_upsert":
		if err := syncCanvasDishPhotos(mealID, payload.Stickers); err != nil {
			return nil, false, false, err
		}
		didChange := false
		for _, raw := range payload.Stickers {
			var meta canvasStickerMeta
			if json.Unmarshal(raw, &meta) != nil || strings.TrimSpace(meta.ID) == "" {
				continue
			}
			idx := -1
			for i, existingRaw := range next.Stickers {
				var cur canvasStickerMeta
				if json.Unmarshal(existingRaw, &cur) != nil {
					continue
				}
				if strings.EqualFold(cur.ID, meta.ID) || (meta.MealDishID != nil && cur.MealDishID != nil && *meta.MealDishID == *cur.MealDishID) {
					idx = i
					break
				}
			}
			if idx >= 0 {
				next.Stickers[idx] = raw
			} else {
				next.Stickers = append(next.Stickers, raw)
			}
			didChange = true
		}
		for _, raw := range payload.Notes {
			var meta canvasIDMeta
			if json.Unmarshal(raw, &meta) != nil || strings.TrimSpace(meta.ID) == "" {
				continue
			}
			if idx := findIDIndex(next.Notes, meta.ID); idx >= 0 {
				next.Notes[idx] = raw
			} else {
				next.Notes = append(next.Notes, raw)
			}
			didChange = true
		}
		return next, didChange, false, nil

	case "patch_elements":
		didChange := false
		for _, patch := range payload.StickerPatches {
			index := findStickerIndex(next.Stickers, patch.ID, patch.MealDishID)
			applied, err := patchCanvasElement(next.Stickers, index, patch)
			if err != nil {
				return nil, false, false, err
			}
			didChange = didChange || applied
		}
		for _, patch := range payload.NotePatches {
			index := findIDIndex(next.Notes, patch.ID)
			applied, err := patchCanvasElement(next.Notes, index, patch)
			if err != nil {
				return nil, false, false, err
			}
			didChange = didChange || applied
		}
		return next, didChange, false, nil

	case "batch_delete":
		didChange := false
		if len(payload.StickerIDs) > 0 {
			filtered, removed := removeByIDs(next.Stickers, payload.StickerIDs)
			if removed {
				next.Stickers = filtered
				didChange = true
			}
		}
		if len(payload.NoteIDs) > 0 {
			filtered, removed := removeByIDs(next.Notes, payload.NoteIDs)
			if removed {
				next.Notes = filtered
				didChange = true
			}
		}
		if len(payload.StrokeIDs) > 0 {
			filtered, removed := removeByIDs(next.Strokes, payload.StrokeIDs)
			if removed {
				next.Strokes = filtered
				didChange = true
			}
		}
		return next, didChange, false, nil

	case "replace_document":
		if payload.Document == nil {
			return nil, false, false, errors.New("缺少 document")
		}
		if payload.OnlyIfEmpty && currentRev > 0 {
			return next, false, true, nil
		}
		next = normalizeCanvasDoc(payload.Document)
		if err := syncCanvasDishPhotos(mealID, next.Stickers); err != nil {
			return nil, false, false, err
		}
		return next, true, false, nil

	default:
		return nil, false, false, errors.New("不支持的画布操作类型")
	}
}

func loadCanvasDish(mealID, dishID uint) (model.MealDish, error) {
	var dish model.MealDish
	err := model.DB.Select("recipe_image", "recipe_cutout_image").
		Where("id = ? AND meal_session_id = ?", dishID, mealID).Take(&dish).Error
	return dish, err
}

// syncCanvasDishPhotos 用餐次菜品照片校准画布快照及批量操作携带的旧图。
func syncCanvasDishPhotos(mealID uint, stickers []json.RawMessage) error {
	var dishIDs []uint
	stickerDishes := make(map[int]uint)
	for index, raw := range stickers {
		var meta canvasStickerMeta
		if json.Unmarshal(raw, &meta) == nil && meta.MealDishID != nil {
			dishIDs = append(dishIDs, *meta.MealDishID)
			stickerDishes[index] = *meta.MealDishID
		}
	}
	if len(dishIDs) == 0 {
		return nil
	}
	var dishes []model.MealDish
	if err := model.DB.Select("id", "recipe_image", "recipe_cutout_image").
		Where("meal_session_id = ? AND id IN ?", mealID, dishIDs).Find(&dishes).Error; err != nil {
		return err
	}
	byID := make(map[uint]model.MealDish, len(dishes))
	for _, dish := range dishes {
		byID[dish.ID] = dish
	}
	for index, dishID := range stickerDishes {
		if dish, ok := byID[dishID]; ok {
			if _, err := patchCanvasDishPhoto(stickers, index, dish); err != nil {
				return err
			}
		}
	}
	return nil
}

func patchCanvasDishPhoto(stickers []json.RawMessage, index int, dish model.MealDish) (bool, error) {
	image := dish.RecipeImage
	isCutout := dish.RecipeCutoutImage != ""
	if isCutout {
		image = dish.RecipeCutoutImage
	}
	return patchCanvasElement(stickers, index, struct {
		Image    string `json:"image"`
		IsCutout bool   `json:"isCutout"`
	}{Image: image, IsCutout: isCutout})
}

func patchCanvasElement(items []json.RawMessage, index int, patch any) (bool, error) {
	if index < 0 {
		return false, nil
	}
	var element map[string]json.RawMessage
	if err := json.Unmarshal(items[index], &element); err != nil {
		return false, err
	}

	// 只合并已解码的更新字段，同时保留原对象的其他字段。
	rawPatch, err := json.Marshal(patch)
	if err != nil {
		return false, err
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(rawPatch, &fields); err != nil {
		return false, err
	}
	delete(fields, "id")
	delete(fields, "mealDishID")

	didChange := false
	for key, value := range fields {
		if !bytes.Equal(element[key], value) {
			element[key] = value
			didChange = true
		}
	}
	if !didChange {
		return false, nil
	}
	updated, err := json.Marshal(element)
	if err != nil {
		return false, err
	}
	items[index] = updated
	return true, nil
}

func findStickerIndex(items []json.RawMessage, id string, dishID *uint) int {
	if dishID == nil {
		return findIDIndex(items, id)
	}
	for i, raw := range items {
		var item canvasStickerMeta
		if json.Unmarshal(raw, &item) == nil && item.MealDishID != nil && *item.MealDishID == *dishID {
			return i
		}
	}
	return -1
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
	return removeByIDs(items, []string{id})
}

func removeByIDs(items []json.RawMessage, ids []string) ([]json.RawMessage, bool) {
	if len(ids) == 0 {
		return items, false
	}
	targetSet := make(map[string]struct{}, len(ids))
	for _, rawID := range ids {
		trimmed := strings.ToLower(strings.TrimSpace(rawID))
		if trimmed != "" {
			targetSet[trimmed] = struct{}{}
		}
	}
	if len(targetSet) == 0 {
		return items, false
	}
	filtered := make([]json.RawMessage, 0, len(items))
	removed := false
	for _, raw := range items {
		var meta canvasIDMeta
		if json.Unmarshal(raw, &meta) == nil {
			if _, ok := targetSet[strings.ToLower(strings.TrimSpace(meta.ID))]; ok {
				removed = true
				continue
			}
		}
		filtered = append(filtered, raw)
	}
	return filtered, removed
}
