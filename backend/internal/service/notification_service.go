package service

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"math/rand/v2"
	"net/http"
	"os"
	"slices"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/golang-jwt/jwt/v4"
	"gorm.io/gorm"
	"lover-order-backend/internal/config"
	"lover-order-backend/internal/model"
)

// 自定义短通知音效文件名（对应 iOS Bundle 根目录下的 .caf 合成短音频）
const (
	NotifySoundPlatePop    = "plate_pop.caf"
	NotifySoundDinnerChime = "dinner_chime.caf"
	NotifySoundNudgeBoing  = "nudge_boing.caf"

	// iOS UNNotificationCategory 标识符
	apnsCategoryDishOrNudge = "MEAL_DISH_OR_NUDGE"
	apnsCategoryDinner      = "MEAL_NUDGE_DINNER"

	dishCoalesceWindow = 45 * time.Second
	nudgeCooldown      = 15 * time.Second
	replyCooldown      = 4 * time.Second
)

type coalescedDishState struct {
	maxDishID uint
	updatedAt time.Time
}

var (
	nudgeRateMu       sync.Mutex
	lastNudgeSentAt   = make(map[string]time.Time)
	lastReplySentAt   = make(map[string]time.Time)
	dishCoalesceMu    sync.Mutex
	lastCoalescedDish = make(map[string]coalescedDishState)
)

func pruneTimeMapLocked(m map[string]time.Time, now time.Time, maxAge time.Duration) {
	if len(m) < 64 {
		return
	}
	for k, t := range m {
		if now.Sub(t) > maxAge {
			delete(m, k)
		}
	}
}

func pruneCoalescedDishMapLocked(now time.Time) {
	if len(lastCoalescedDish) < 64 {
		return
	}
	for k, st := range lastCoalescedDish {
		if now.Sub(st.updatedAt) > 5*time.Minute {
			delete(lastCoalescedDish, k)
		}
	}
}

// NotificationService 通知事件与 APNs 推送服务
type NotificationService struct{}

// NewNotificationService 构造
func NewNotificationService() *NotificationService {
	return &NotificationService{}
}

// DeviceRegisterInput 设备推送令牌注册入参
type DeviceRegisterInput struct {
	Token          string   `json:"token" binding:"required"`
	DeviceID       string   `json:"device_id" binding:"required,uuid"`
	Platform       string   `json:"platform"`
	Environment    string   `json:"environment"`
	AppVersion     string   `json:"app_version"`
	MutedKinds     []string `json:"muted_kinds" binding:"max=10,unique,dive,oneof=meal_dish_added meal_confirmed meal_completed meal_reviewed dining_joined dining_dish_added household_joined meal_nudge meal_nudge_reply"`
	UseCustomSound *bool    `json:"use_custom_sound"`
}

// NotificationListResult 通知列表响应
type NotificationListResult struct {
	Items          []model.NotificationEvent `json:"items"`
	UnreadCount    int64                     `json:"unread_count"`
	LatestID       uint                      `json:"latest_id"`
	APNsDeliveries map[uint]string           `json:"apns_deliveries"`
}

// NudgeInput 家庭成员间主动传呼/提醒入参（仅家庭日常成员互发，不涉及临时来客）
type NudgeInput struct {
	Preset       string `json:"preset"`
	Message      string `json:"message"`
	StickerCode  string `json:"sticker_code"`
	MealID       *uint  `json:"meal_id"`
	TargetUserID *uint  `json:"target_user_id"`
}

// NudgeReplyInput 锁屏横幅或站内一键轻回应入参
type NudgeReplyInput struct {
	EventID   uint   `json:"event_id"`
	ReplyCode string `json:"reply_code" binding:"required"`
	MealID    *uint  `json:"meal_id"`
}

// NudgeSendResult 传呼/回应发送结果
type NudgeSendResult struct {
	PresetKey      string `json:"preset_key"`
	Title          string `json:"title"`
	Body           string `json:"body"`
	StickerCode    string `json:"sticker_code"`
	SoundName      string `json:"sound_name"`
	DeepLink       string `json:"deep_link"`
	RecipientCount int    `json:"recipient_count"`
}

type dispatchOptions struct {
	recipientIDs []uint
	actorID      *uint
	householdID  *uint
	kind         string
	presetKey    string
	title        string
	body         string
	stickerCode  string
	imageURL     string
	soundName    string
	mealID       *uint
	roomCode     string
	deepLink     string
	collapseID   string
}

// RegisterDevice 注册或刷新设备 APNs Token
func (s *NotificationService) RegisterDevice(userID uint, in DeviceRegisterInput) error {
	tok := strings.TrimSpace(in.Token)
	if tok == "" {
		return errors.New("device token 不能为空")
	}
	platform := strings.TrimSpace(in.Platform)
	if platform == "" {
		platform = "ios"
	}
	env := strings.TrimSpace(in.Environment)
	if env != "production" {
		env = "sandbox"
	}
	useCustomSound := true
	if in.UseCustomSound != nil {
		useCustomSound = *in.UseCustomSound
	}

	mutedKinds := strings.Join(in.MutedKinds, ",")
	var existing model.DeviceToken
	err := model.DB.Where("token = ?", tok).First(&existing).Error
	if err == nil {
		return model.DB.Model(&existing).Updates(map[string]any{
			"user_id":          userID,
			"device_id":        in.DeviceID,
			"platform":         platform,
			"environment":      env,
			"app_version":      strings.TrimSpace(in.AppVersion),
			"muted_kinds":      mutedKinds,
			"use_custom_sound": useCustomSound,
			"is_active":        true,
			"last_seen_at":     time.Now(),
		}).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	item := &model.DeviceToken{
		UserID:         userID,
		DeviceID:       in.DeviceID,
		Token:          tok,
		Platform:       platform,
		Environment:    env,
		AppVersion:     strings.TrimSpace(in.AppVersion),
		MutedKinds:     mutedKinds,
		UseCustomSound: useCustomSound,
		IsActive:       true,
		LastSeenAt:     time.Now(),
	}
	return model.DB.Create(item).Error
}

// UnregisterDevice 停用当前用户的推送令牌（登出时调用）
func (s *NotificationService) UnregisterDevice(userID uint, token string) error {
	q := model.DB.Model(&model.DeviceToken{}).Where("user_id = ?", userID)
	tok := strings.TrimSpace(token)
	if tok != "" {
		q = q.Where("token = ?", tok)
	}
	return q.Update("is_active", false).Error
}

// ListEvents 获取当前用户站内通知与未读统计
func (s *NotificationService) ListEvents(userID uint, deviceID string, afterID *uint, limit int) (*NotificationListResult, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}

	items := []model.NotificationEvent{}
	q := model.DB.Where("user_id = ?", userID).Preload("Actor")
	order := "id DESC"
	if afterID != nil {
		q = q.Where("id > ?", *afterID)
		order = "id ASC"
	}
	if err := q.Order(order).Limit(limit).Find(&items).Error; err != nil {
		return nil, err
	}

	var unreadCount int64
	if err := model.DB.Model(&model.NotificationEvent{}).
		Where("user_id = ? AND is_read = ?", userID, false).
		Count(&unreadCount).Error; err != nil {
		return nil, err
	}

	var latestID uint
	deliveries := make(map[uint]string)
	now := time.Now()
	for _, item := range items {
		latestID = max(latestID, item.ID)
		if state := item.APNsDeliveries[deviceID]; state != "" {
			// 服务重启可能中断记录写回。结果未知时保留 APNs 归属，避免重发已弹过的消息。
			if state == apnsPending && now.Sub(item.CreatedAt) >= apnsPendingLimit {
				state = apnsRemote
			}
			deliveries[item.ID] = state
		}
	}

	return &NotificationListResult{
		Items:          items,
		UnreadCount:    unreadCount,
		LatestID:       latestID,
		APNsDeliveries: deliveries,
	}, nil
}

// MarkRead 标记单条或全部通知为已读（eventID == 0 时全部标已读）
func (s *NotificationService) MarkRead(userID uint, eventID uint) error {
	now := time.Now()
	q := model.DB.Model(&model.NotificationEvent{}).
		Where("user_id = ? AND is_read = ?", userID, false)
	if eventID > 0 {
		q = q.Where("id = ?", eventID)
	}
	return q.Updates(map[string]any{
		"is_read": true,
		"read_at": &now,
	}).Error
}

// SendTest 为当前用户生成一条测试提醒（附带贴纸、菜图与定制音效以体验完整富媒体横幅）
func (s *NotificationService) SendTest(userID uint) (*model.NotificationEvent, error) {
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, errors.New("用户不存在")
	}

	var hid *uint
	var mealIDPtr *uint
	deepLink := "lo://meal/0"
	title := "叮铃铃！今天这顿想吃啥？"
	body := "点通知可直达画布，长按横幅还能一键回应 Ta"
	stickerCode := "food_cheers"
	soundName := NotifySoundDinnerChime
	imageURL := ""

	if user.HouseholdID != nil {
		hid = user.HouseholdID
		var active model.MealSession
		if err := model.DB.Where("household_id = ? AND status IN ?", *hid, []string{model.MealStatusPlanning, model.MealStatusConfirmed}).
			Preload("Dishes").Order("id DESC").First(&active).Error; err == nil {
			idCopy := active.ID
			mealIDPtr = &idCopy
			deepLink = fmt.Sprintf("lo://meal/%d", active.ID)
			imageURL = leadDishImage(active.Dishes)
			if len(active.Dishes) > 0 {
				title = "桌上有好菜等翻牌"
				body = fmt.Sprintf("「%s」已摆上画布，下拉横幅试试一键回应吧", summarizeDishes(extractDishNames(active.Dishes)))
				stickerCode = "mood_drool"
				soundName = NotifySoundPlatePop
			}
		} else {
			var completed model.MealSession
			if err := model.DB.Where("household_id = ? AND status = ?", *hid, model.MealStatusCompleted).
				Preload("Dishes").Order("id DESC").First(&completed).Error; err == nil {
				idCopy := completed.ID
				mealIDPtr = &idCopy
				deepLink = fmt.Sprintf("lo://history/%d", completed.ID)
				imageURL = leadDishImage(completed.Dishes)
				name := strings.TrimSpace(completed.Title)
				if name == "" {
					name = "最近这顿饭"
				}
				title = "光盘记忆已收好啦"
				body = fmt.Sprintf("「%s」已存进记录，生成海报或补两句感受吧", truncateText(name, 18))
				stickerCode = "vibe_camera"
			}
		}
	}

	ev := &model.NotificationEvent{
		UserID:      userID,
		ActorID:     &userID,
		HouseholdID: hid,
		Kind:        model.NotifyKindTest,
		PresetKey:   "test",
		Title:       title,
		Body:        body,
		StickerCode: stickerCode,
		ImageURL:    imageURL,
		SoundName:   soundName,
		MealID:      mealIDPtr,
		DeepLink:    deepLink,
	}
	if err := model.DB.Create(ev).Error; err != nil {
		return nil, err
	}
	_ = model.DB.Preload("Actor").First(ev, ev.ID).Error

	return ev, nil
}

// SendNudge 家庭日常成员向家里同伴发送趣味餐桌传呼（来客不可发起或接收）
func (s *NotificationService) SendNudge(userID uint, in NudgeInput) (*NudgeSendResult, error) {
	var sender model.User
	if err := model.DB.First(&sender, userID).Error; err != nil {
		return nil, errors.New("用户不存在")
	}
	if sender.HouseholdID == nil || *sender.HouseholdID == 0 {
		return nil, errors.New("先创建或加入一个家，才能提醒家里人哦")
	}
	householdID := *sender.HouseholdID

	allRecipients := householdRecipients(householdID, userID)
	if len(allRecipients) == 0 {
		return nil, errors.New("家里还没有其他成员，先叫 Ta 进来吧")
	}
	recipients := allRecipients
	if in.TargetUserID != nil && *in.TargetUserID > 0 {
		if !slices.Contains(allRecipients, *in.TargetUserID) {
			return nil, errors.New("只能提醒同一个家里的成员哦")
		}
		recipients = []uint{*in.TargetUserID}
	}

	now := time.Now()
	rateKey := fmt.Sprintf("%d:%d", userID, householdID)
	nudgeRateMu.Lock()
	pruneTimeMapLocked(lastNudgeSentAt, now, 5*time.Minute)
	if prev, ok := lastNudgeSentAt[rateKey]; ok && now.Sub(prev) < nudgeCooldown {
		nudgeRateMu.Unlock()
		return nil, errors.New("刚喊过 Ta 啦，给 Ta 一点赶来的时间～")
	}
	lastNudgeSentAt[rateKey] = now
	nudgeRateMu.Unlock()

	actorName := strings.TrimSpace(sender.Nickname)
	if actorName == "" {
		actorName = "Ta"
	}

	preset := normalizeNudgePreset(in.Preset)
	customMsg := truncateText(strings.TrimSpace(in.Message), 36)
	if preset == "custom" && customMsg == "" {
		preset = "hungry"
	}

	mealIDPtr, _, shoppingCount := resolveHouseholdContextMeal(householdID, preset, in.MealID)
	title, body, defaultSticker, soundName, deepLink := buildNudgeCopy(
		preset, actorName, customMsg, mealIDPtr, shoppingCount, now,
	)
	stickerCode := sanitizeStickerCode(in.StickerCode)
	if stickerCode == "" {
		stickerCode = defaultSticker
	}

	// 主动传呼优先展示用户点选的手绘水粉贴纸，不覆盖为菜品底图
	eventMap := s.dispatch(dispatchOptions{
		recipientIDs: recipients,
		actorID:      &userID,
		householdID:  &householdID,
		kind:         model.NotifyKindMealNudge,
		presetKey:    preset,
		title:        title,
		body:         body,
		stickerCode:  stickerCode,
		soundName:    soundName,
		mealID:       mealIDPtr,
		deepLink:     deepLink,
		collapseID:   fmt.Sprintf("nudge-%d-%d", householdID, userID),
	})

	GlobalCanvasHub().BroadcastHouseholdNudge(
		householdID,
		CanvasActor{
			ID:       sender.ID,
			Nickname: actorName,
			Avatar:   sender.Avatar,
			Role:     "host",
		},
		eventMap,
		model.NotifyKindMealNudge,
		preset,
		title,
		body,
		stickerCode,
		soundName,
		deepLink,
	)

	return &NudgeSendResult{
		PresetKey:      preset,
		Title:          title,
		Body:           body,
		StickerCode:    stickerCode,
		SoundName:      soundName,
		DeepLink:       deepLink,
		RecipientCount: len(recipients),
	}, nil
}

// SendNudgeReply 对同伴的通知或传呼发送一键轻回应（如“马上来”“赞成”“洗手马上到”“回戳”）
func (s *NotificationService) SendNudgeReply(userID uint, in NudgeReplyInput) (*NudgeSendResult, error) {
	var sender model.User
	if err := model.DB.First(&sender, userID).Error; err != nil {
		return nil, errors.New("用户不存在")
	}
	if sender.HouseholdID == nil || *sender.HouseholdID == 0 {
		return nil, errors.New("先加入一个家才能回应哦")
	}
	householdID := *sender.HouseholdID

	allRecipients := householdRecipients(householdID, userID)
	if len(allRecipients) == 0 {
		return nil, errors.New("家里暂无其他成员")
	}

	now := time.Now()
	replyCode := normalizeReplyCode(in.ReplyCode)
	rateKey := fmt.Sprintf("%d:%s", userID, replyCode)
	nudgeRateMu.Lock()
	pruneTimeMapLocked(lastReplySentAt, now, 5*time.Minute)
	if prev, ok := lastReplySentAt[rateKey]; ok && now.Sub(prev) < replyCooldown {
		nudgeRateMu.Unlock()
		return &NudgeSendResult{PresetKey: replyCode, RecipientCount: 0}, nil
	}
	lastReplySentAt[rateKey] = now
	nudgeRateMu.Unlock()

	recipients := allRecipients
	mealIDPtr := in.MealID
	if in.EventID > 0 {
		var orig model.NotificationEvent
		if err := model.DB.Where("id = ? AND user_id = ?", in.EventID, userID).First(&orig).Error; err == nil {
			if !orig.IsRead {
				_ = s.MarkRead(userID, orig.ID)
			}
			if mealIDPtr == nil && orig.MealID != nil {
				idCopy := *orig.MealID
				mealIDPtr = &idCopy
			}
			if orig.ActorID != nil && slices.Contains(allRecipients, *orig.ActorID) {
				recipients = []uint{*orig.ActorID}
			}
		}
	}
	if mealIDPtr == nil {
		var active model.MealSession
		if err := model.DB.Where("household_id = ? AND status IN ?", householdID, []string{model.MealStatusPlanning, model.MealStatusConfirmed}).
			Order("id DESC").First(&active).Error; err == nil {
			idCopy := active.ID
			mealIDPtr = &idCopy
		}
	}

	actorName := strings.TrimSpace(sender.Nickname)
	if actorName == "" {
		actorName = "Ta"
	}
	title, body, stickerCode, soundName := buildReplyCopy(replyCode, actorName)
	deepLink := "lo://meal/0"
	if mealIDPtr != nil && *mealIDPtr > 0 {
		deepLink = fmt.Sprintf("lo://meal/%d", *mealIDPtr)
	}

	eventMap := s.dispatch(dispatchOptions{
		recipientIDs: recipients,
		actorID:      &userID,
		householdID:  &householdID,
		kind:         model.NotifyKindNudgeReply,
		presetKey:    replyCode,
		title:        title,
		body:         body,
		stickerCode:  stickerCode,
		soundName:    soundName,
		mealID:       mealIDPtr,
		deepLink:     deepLink,
		collapseID:   fmt.Sprintf("nudge-reply-%d-%d", householdID, userID),
	})

	GlobalCanvasHub().BroadcastHouseholdNudge(
		householdID,
		CanvasActor{
			ID:       sender.ID,
			Nickname: actorName,
			Avatar:   sender.Avatar,
			Role:     "host",
		},
		eventMap,
		model.NotifyKindNudgeReply,
		replyCode,
		title,
		body,
		stickerCode,
		soundName,
		deepLink,
	)

	return &NudgeSendResult{
		PresetKey:      replyCode,
		Title:          title,
		Body:           body,
		StickerCode:    stickerCode,
		SoundName:      soundName,
		DeepLink:       deepLink,
		RecipientCount: len(recipients),
	}, nil
}

// NotifyMealDishAdded 通知家里其他人有人加了新菜（支持时段趣味文案与 45 秒内同人连加菜串行合并防刷屏）
func (s *NotificationService) NotifyMealDishAdded(householdID, actorID, mealID uint, dishName, dishImage string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}

		s.dispatchCoalescedDishAdded(
			model.NotifyKindMealDishAdded,
			householdID,
			actorID,
			mealID,
			actorName,
			dishName,
			dishImage,
			"mood_drool",
			fmt.Sprintf("meal-dish-%d-%d", mealID, actorID),
			recipients,
			func(count int, names []string) (string, string) {
				t := pickOne([]string{
					fmt.Sprintf("%s 一口气端上了 %d 道菜", actorName, count),
					fmt.Sprintf("桌上有大动静！%s 连挑了 %d 道", actorName, count),
					fmt.Sprintf("%s 灵感爆发，连加 %d 道好菜", actorName, count),
				})
				b := fmt.Sprintf("刚把「%s」摆上画布，快去过目吧", summarizeDishes(names))
				return t, b
			},
			func() (string, string) {
				return buildDishAddedCopy(actorName, truncateText(dishName, 16), time.Now())
			},
		)
	}()
}

// NotifyMealConfirmed 通知家里其他人及点菜房客人今天这顿定好了
func (s *NotificationService) NotifyMealConfirmed(householdID, actorID, mealID uint, dishNames []string, leadImage string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := mergeRecipients(
			householdRecipients(householdID, actorID),
			mealParticipantRecipients(mealID, actorID),
		)
		if len(recipients) == 0 {
			return
		}
		summary := summarizeDishes(dishNames)
		title := pickOne([]string{
			"敲定啦！今天吃什么拍板咯",
			"菜单定好啦，准备享口福",
			fmt.Sprintf("%s 拍板了今天这一顿", actorName),
		})
		body := fmt.Sprintf("今日菜单：%s，点进画布看一眼吧", summary)
		if summary == "" {
			body = fmt.Sprintf("%s 定好了今天这顿，去画布看一眼吧", actorName)
		}
		s.dispatch(dispatchOptions{
			recipientIDs: recipients,
			actorID:      &actorID,
			householdID:  &householdID,
			kind:         model.NotifyKindMealConfirmed,
			presetKey:    "confirmed",
			title:        title,
			body:         body,
			stickerCode:  "food_cheers",
			imageURL:     strings.TrimSpace(leadImage),
			soundName:    NotifySoundDinnerChime,
			mealID:       &mealID,
			deepLink:     fmt.Sprintf("lo://meal/%d", mealID),
			collapseID:   fmt.Sprintf("meal-confirm-%d", mealID),
		})
	}()
}

// NotifyMealCompleted 通知家里其他人这顿吃完了
func (s *NotificationService) NotifyMealCompleted(householdID, actorID, mealID uint, mealTitle, leadImage string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		label := strings.TrimSpace(mealTitle)
		if label == "" {
			label = "今天这一顿"
		}
		shortLabel := truncateText(label, 18)
		title := pickOne([]string{
			"光盘打卡！这顿圆满收官",
			"吃饱喝足～收进我们的小本本啦",
			"这顿饭吃好啦，留点纪念吧",
		})
		body := pickOne([]string{
			fmt.Sprintf("%s 记下了「%s」吃完，来贴两张照片或导出海报吧", actorName, shortLabel),
			fmt.Sprintf("「%s」已归档进记录，趁热写两句回味一下吧", shortLabel),
		})
		s.dispatch(dispatchOptions{
			recipientIDs: recipients,
			actorID:      &actorID,
			householdID:  &householdID,
			kind:         model.NotifyKindMealCompleted,
			title:        title,
			body:         body,
			stickerCode:  "mood_full_cat",
			imageURL:     strings.TrimSpace(leadImage),
			soundName:    NotifySoundDinnerChime,
			mealID:       &mealID,
			deepLink:     fmt.Sprintf("lo://history/%d", mealID),
		})
	}()
}

// NotifyMealReviewed 通知家里其他人收到了新评价/照片
func (s *NotificationService) NotifyMealReviewed(householdID, actorID, mealID uint, rating int, comment string, photos []string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		photoCount := len(photos)
		firstPhoto := ""
		for _, p := range photos {
			if trimmed := strings.TrimSpace(p); trimmed != "" {
				firstPhoto = trimmed
				break
			}
		}

		title := pickOne([]string{
			fmt.Sprintf("%s 给这顿盖了 %d 颗星", actorName, rating),
			fmt.Sprintf("收到 %s 的 %d 星食评啦", actorName, rating),
		})
		trimmed := strings.TrimSpace(comment)
		var body string
		switch {
		case trimmed != "" && photoCount > 0:
			body = fmt.Sprintf("「%s」· 还附了 %d 张实拍美照", truncateText(trimmed, 24), photoCount)
		case trimmed != "":
			body = fmt.Sprintf("写下回味：「%s」", truncateText(trimmed, 32))
		case photoCount > 0:
			body = fmt.Sprintf("%s 晒了 %d 张这顿饭的实拍图，快去大饱眼福", actorName, photoCount)
		default:
			body = fmt.Sprintf("%s 留下了餐后记录，去看看这顿饭吧", actorName)
		}
		s.dispatch(dispatchOptions{
			recipientIDs: recipients,
			actorID:      &actorID,
			householdID:  &householdID,
			kind:         model.NotifyKindMealReviewed,
			title:        title,
			body:         body,
			stickerCode:  "mood_star_eyes",
			imageURL:     firstPhoto,
			soundName:    NotifySoundPlatePop,
			mealID:       &mealID,
			deepLink:     fmt.Sprintf("lo://history/%d", mealID),
		})
	}()
}

// NotifyDiningJoined 通知家里成员有朋友加入了点菜房
func (s *NotificationService) NotifyDiningJoined(householdID, actorID, mealID uint, roomCode string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		title := pickOne([]string{
			fmt.Sprintf("门铃叮咚！%s 进房一起点菜啦", actorName),
			fmt.Sprintf("%s 拿着入场券到桌边啦", actorName),
		})
		body := fmt.Sprintf("已进入点菜房 %s，快去画布看看 Ta 想吃什么", roomCode)
		s.dispatch(dispatchOptions{
			recipientIDs: recipients,
			actorID:      &actorID,
			householdID:  &householdID,
			kind:         model.NotifyKindDiningJoined,
			title:        title,
			body:         body,
			stickerCode:  "food_cheers",
			soundName:    NotifySoundNudgeBoing,
			mealID:       &mealID,
			roomCode:     roomCode,
			deepLink:     fmt.Sprintf("lo://meal/%d", mealID),
		})
	}()
}

// NotifyDiningDishAdded 通知家里成员有朋友在点菜房里点了菜（45 秒内连点串行合并）
func (s *NotificationService) NotifyDiningDishAdded(householdID, actorID, mealID uint, dishName, dishImage string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}

		s.dispatchCoalescedDishAdded(
			model.NotifyKindDiningDishAdded,
			householdID,
			actorID,
			mealID,
			actorName,
			dishName,
			dishImage,
			"food_ramen",
			fmt.Sprintf("dining-dish-%d-%d", mealID, actorID),
			recipients,
			func(count int, names []string) (string, string) {
				return fmt.Sprintf("客人 %s 连点了 %d 道菜", actorName, count),
					fmt.Sprintf("点菜房新增「%s」，今晚好热闹", summarizeDishes(names))
			},
			func() (string, string) {
				t := pickOne([]string{
					fmt.Sprintf("%s 翻牌了一道「%s」", actorName, truncateText(dishName, 16)),
					fmt.Sprintf("点菜房上新：%s 想吃「%s」", actorName, truncateText(dishName, 14)),
				})
				return t, "来自聚餐点菜房，快去画布看看桌上阵容吧"
			},
		)
	}()
}

type pendingAPNsJob struct {
	ev      *model.NotificationEvent
	targets []model.DeviceToken
	bearer  string
}

// dispatchCoalescedDishAdded 串行化短窗口内同一人的连加菜查询、旧未读清理与新通知入库，杜绝并发连点重复落库或乱序覆盖
func (s *NotificationService) dispatchCoalescedDishAdded(
	kind string,
	householdID, actorID, mealID uint,
	actorName, dishName, dishImage, stickerCode, collapseID string,
	recipients []uint,
	multiCopy func(count int, names []string) (string, string),
	singleCopy func() (string, string),
) {
	cfg := config.AppConfig.APNs
	coalesceKey := fmt.Sprintf("%s:%d:%d", kind, mealID, actorID)

	dishCoalesceMu.Lock()
	now := time.Now()
	pruneCoalescedDishMapLocked(now)
	cutoff := now.Add(-dishCoalesceWindow)

	var recentDishes []model.MealDish
	_ = model.DB.Where("meal_session_id = ? AND added_by = ? AND created_at >= ?", mealID, actorID, cutoff).
		Order("id ASC").Find(&recentDishes).Error

	var maxDishID uint
	for _, d := range recentDishes {
		if d.ID > maxDishID {
			maxDishID = d.ID
		}
	}
	if prev, ok := lastCoalescedDish[coalesceKey]; ok && maxDishID > 0 && maxDishID <= prev.maxDishID && now.Sub(prev.updatedAt) < dishCoalesceWindow {
		// 前序并发协程已把当前最新菜品一并纳入合并通知，直接跳过避免重复推送
		dishCoalesceMu.Unlock()
		return
	}
	if maxDishID > 0 {
		lastCoalescedDish[coalesceKey] = coalescedDishState{maxDishID: maxDishID, updatedAt: now}
	}

	imageURL := strings.TrimSpace(dishImage)
	if lead := leadDishImage(recentDishes); lead != "" {
		imageURL = lead
	}

	var title, body string
	if len(recentDishes) >= 2 {
		title, body = multiCopy(len(recentDishes), extractDishNames(recentDishes))
		model.DB.Where(
			"user_id IN ? AND actor_id = ? AND meal_id = ? AND kind = ? AND is_read = ? AND created_at >= ?",
			recipients, actorID, mealID, kind, false, cutoff,
		).Delete(&model.NotificationEvent{})
	} else {
		title, body = singleCopy()
	}

	deepLink := fmt.Sprintf("lo://meal/%d", mealID)
	jobs := make([]pendingAPNsJob, 0, len(recipients))
	for _, uid := range recipients {
		ev := &model.NotificationEvent{
			UserID:      uid,
			ActorID:     &actorID,
			HouseholdID: &householdID,
			Kind:        kind,
			Title:       title,
			Body:        body,
			StickerCode: stickerCode,
			ImageURL:    imageURL,
			SoundName:   NotifySoundPlatePop,
			MealID:      &mealID,
			DeepLink:    deepLink,
		}
		targets, bearer := apnsTargets(ev, cfg)
		if len(targets) > 0 {
			ev.APNsDeliveries = make(map[string]string, len(targets))
			for _, device := range targets {
				ev.APNsDeliveries[device.DeviceID] = apnsPending
			}
		}
		if err := model.DB.Create(ev).Error; err != nil {
			log.Printf("[Notification] 创建事件失败 uid=%d err=%v", uid, err)
			continue
		}
		if len(targets) > 0 {
			jobs = append(jobs, pendingAPNsJob{ev: ev, targets: targets, bearer: bearer})
		}
	}
	dishCoalesceMu.Unlock()

	for _, job := range jobs {
		pushEventToDevices(job.ev, job.targets, cfg, job.bearer, collapseID)
	}
}

// NotifyHouseholdJoined 通知家内原有成员有新家人加入
func (s *NotificationService) NotifyHouseholdJoined(householdID, actorID uint, householdName string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		name := strings.TrimSpace(householdName)
		if name == "" {
			name = "我们家"
		}
		title := fmt.Sprintf("欢迎回家！%s 加入了「%s」", actorName, truncateText(name, 12))
		body := "餐桌多了一双筷子，以后一起在画布上商量每天吃什么吧"
		s.dispatch(dispatchOptions{
			recipientIDs: recipients,
			actorID:      &actorID,
			householdID:  &householdID,
			kind:         model.NotifyKindHouseholdJoined,
			title:        title,
			body:         body,
			stickerCode:  "mood_hug_heart",
			soundName:    NotifySoundDinnerChime,
			deepLink:     "lo://household",
		})
	}()
}

func (s *NotificationService) dispatch(opts dispatchOptions) map[uint]uint {
	cfg := config.AppConfig.APNs
	createdByUser := make(map[uint]uint, len(opts.recipientIDs))
	for _, uid := range opts.recipientIDs {
		ev := &model.NotificationEvent{
			UserID:      uid,
			ActorID:     opts.actorID,
			HouseholdID: opts.householdID,
			Kind:        opts.kind,
			PresetKey:   opts.presetKey,
			Title:       opts.title,
			Body:        opts.body,
			StickerCode: opts.stickerCode,
			ImageURL:    opts.imageURL,
			SoundName:   opts.soundName,
			MealID:      opts.mealID,
			RoomCode:    opts.roomCode,
			DeepLink:    opts.deepLink,
		}
		targets, bearer := apnsTargets(ev, cfg)
		if len(targets) > 0 {
			ev.APNsDeliveries = make(map[string]string, len(targets))
			for _, device := range targets {
				ev.APNsDeliveries[device.DeviceID] = apnsPending
			}
		}
		if err := model.DB.Create(ev).Error; err != nil {
			log.Printf("[Notification] 创建事件失败 uid=%d err=%v", uid, err)
			continue
		}
		createdByUser[uid] = ev.ID
		if len(targets) > 0 {
			pushEventToDevices(ev, targets, cfg, bearer, opts.collapseID)
		}
	}
	return createdByUser
}

// --- 趣味文案池与预设解析辅助 ---

func normalizeNudgePreset(raw string) string {
	switch strings.TrimSpace(strings.ToLower(raw)) {
	case "hungry", "inspiration", "check_canvas", "confirm_menu",
		"shopping_list", "cooking", "dinner_ready", "write_review", "custom":
		return strings.TrimSpace(strings.ToLower(raw))
	default:
		return "hungry"
	}
}

func normalizeReplyCode(raw string) string {
	switch strings.TrimSpace(strings.ToLower(raw)) {
	case "coming", "thumbs_up", "washing_hands", "wave_back":
		return strings.TrimSpace(strings.ToLower(raw))
	default:
		return "wave_back"
	}
}

func sanitizeStickerCode(raw string) string {
	cleaned := strings.TrimSpace(raw)
	cleaned = strings.TrimPrefix(cleaned, "StickerEmoji_")
	if len(cleaned) < 3 || len(cleaned) > 48 {
		return ""
	}
	if !strings.HasPrefix(cleaned, "mood_") && !strings.HasPrefix(cleaned, "food_") && !strings.HasPrefix(cleaned, "vibe_") {
		return ""
	}
	for _, r := range cleaned {
		if !(unicode.IsLower(r) || unicode.IsDigit(r) || r == '_') {
			return ""
		}
	}
	return cleaned
}

func resolveHouseholdContextMeal(householdID uint, preset string, requestedMealID *uint) (*uint, string, int) {
	if requestedMealID != nil && *requestedMealID > 0 {
		var m model.MealSession
		if err := model.DB.Where("id = ? AND household_id = ?", *requestedMealID, householdID).
			Preload("Dishes").First(&m).Error; err == nil {
			idCopy := m.ID
			return &idCopy, leadDishImage(m.Dishes), countShoppingIngredients(householdID, m.Dishes)
		}
	}
	if preset == "write_review" {
		var completed model.MealSession
		if err := model.DB.Where("household_id = ? AND status = ?", householdID, model.MealStatusCompleted).
			Preload("Dishes").Order("id DESC").First(&completed).Error; err == nil {
			idCopy := completed.ID
			return &idCopy, leadDishImage(completed.Dishes), 0
		}
	}
	var active model.MealSession
	if err := model.DB.Where("household_id = ? AND status IN ?", householdID, []string{model.MealStatusPlanning, model.MealStatusConfirmed}).
		Preload("Dishes").Order("id DESC").First(&active).Error; err == nil {
		idCopy := active.ID
		return &idCopy, leadDishImage(active.Dishes), countShoppingIngredients(householdID, active.Dishes)
	}
	return nil, "", 0
}

func countShoppingIngredients(householdID uint, dishes []model.MealDish) int {
	if len(dishes) == 0 {
		return 0
	}
	recipeIDs := make([]uint, 0, len(dishes))
	for _, d := range dishes {
		if d.RecipeID != nil && *d.RecipeID > 0 {
			recipeIDs = append(recipeIDs, *d.RecipeID)
		}
	}
	if len(recipeIDs) == 0 {
		return 0
	}
	var recipes []model.Recipe
	if err := model.DB.Where("household_id = ? AND id IN ?", householdID, recipeIDs).Find(&recipes).Error; err != nil {
		return 0
	}
	seen := make(map[string]bool)
	for _, r := range recipes {
		for _, ing := range r.IngredientsList() {
			rawName, _ := ing["name"].(string)
			name := strings.TrimSpace(rawName)
			if name != "" {
				seen[name] = true
			}
		}
	}
	return len(seen)
}

func buildNudgeCopy(
	preset, actorName, customMsg string,
	mealID *uint,
	shoppingCount int,
	now time.Time,
) (title, body, defaultSticker, soundName, deepLink string) {
	mealLink := "lo://meal/0"
	if mealID != nil && *mealID > 0 {
		mealLink = fmt.Sprintf("lo://meal/%d", *mealID)
	}
	deepLink = mealLink
	soundName = NotifySoundNudgeBoing
	defaultSticker = "mood_drool"
	hour := now.Hour()

	switch preset {
	case "hungry":
		defaultSticker = "mood_drool"
		soundName = NotifySoundNudgeBoing
		switch {
		case hour >= 5 && hour < 10:
			title = fmt.Sprintf("早安咕咕叫～%s 饿啦", actorName)
			body = "新的一天吃点什么好？快来画布贴一道"
		case hour >= 11 && hour < 14:
			title = fmt.Sprintf("午饭雷达响啦！%s 喊你挑菜", actorName)
			body = "肚子开始抗议咯，快上画布看看今天吃啥"
		case hour >= 14 && hour < 17:
			title = fmt.Sprintf("%s 有点嘴馋啦", actorName)
			body = "来画布逛逛，提前商量下待会儿吃点啥吧"
		case hour >= 21 || hour < 5:
			title = fmt.Sprintf("深夜馋虫！%s 肚子饿啦", actorName)
			body = "要不要整点宵夜解解馋？快上画布看看"
		default:
			title = pickOne([]string{
				fmt.Sprintf("%s 肚子咕咕叫啦", actorName),
				fmt.Sprintf("饭点传呼：%s 问今天吃啥？", actorName),
			})
			body = "画布已经铺好啦，快来选两道想吃的菜吧"
		}
	case "inspiration":
		defaultSticker = "vibe_sparkles"
		soundName = NotifySoundNudgeBoing
		title = fmt.Sprintf("%s 正在求点菜灵感", actorName)
		body = "选择困难发作中，想吃什么尽管往画布上抛！"
	case "check_canvas":
		defaultSticker = "mood_wink"
		soundName = NotifySoundPlatePop
		title = pickOne([]string{
			fmt.Sprintf("%s 喊你快看画布", actorName),
			fmt.Sprintf("桌上有新彩蛋！%s 叫你来看", actorName),
		})
		body = "刚在「这一顿」画布留了新创作，快点进来看看吧"
	case "confirm_menu":
		defaultSticker = "food_ramen"
		soundName = NotifySoundPlatePop
		title = fmt.Sprintf("%s 问：这几道够吃吗？", actorName)
		body = "菜挑得差不多啦，等你来画布拍板定下这一顿"
	case "shopping_list":
		defaultSticker = "food_croissant"
		soundName = NotifySoundPlatePop
		title = fmt.Sprintf("%s 把买菜清单递给你啦", actorName)
		if shoppingCount > 0 {
			body = fmt.Sprintf("这一顿共 %d 项食材待备齐，点开就能边买边勾", shoppingCount)
		} else {
			body = "这一顿要准备的菜理好啦，点开看看缺啥食材"
		}
		if mealID != nil && *mealID > 0 {
			deepLink = fmt.Sprintf("lo://shopping/%d", *mealID)
		}
	case "cooking":
		defaultSticker = "food_fried_egg"
		soundName = NotifySoundPlatePop
		title = fmt.Sprintf("大厨 %s 已系上围裙开火咯", actorName)
		body = "厨房正在飘香中，期待一下待会儿的好菜吧"
	case "dinner_ready":
		defaultSticker = "food_cheers"
		soundName = NotifySoundDinnerChime
		title = pickOne([]string{
			fmt.Sprintf("叮铃铃！%s 喊你开饭啦", actorName),
			fmt.Sprintf("上菜咯！%s 摇响了开饭铃", actorName),
		})
		body = "热腾腾端上桌啦，快去洗手拿碗筷！"
	case "write_review":
		defaultSticker = "vibe_camera"
		soundName = NotifySoundPlatePop
		title = fmt.Sprintf("%s 邀你一起给这顿留张影", actorName)
		body = "刚才那顿吃得开心吗？来晒张照片写两句回味吧"
		if mealID != nil && *mealID > 0 {
			deepLink = fmt.Sprintf("lo://history/%d", *mealID)
		}
	case "custom":
		defaultSticker = "mood_finger_heart"
		soundName = NotifySoundNudgeBoing
		title = fmt.Sprintf("%s 给这一顿捎了句话", actorName)
		body = "点进画布看看吧"
	}

	if customMsg != "" {
		body = fmt.Sprintf("「%s」", customMsg)
	}
	return
}

func buildReplyCopy(replyCode, actorName string) (title, body, stickerCode, soundName string) {
	switch replyCode {
	case "coming":
		return fmt.Sprintf("%s：收到，马上来！", actorName),
			"正在赶来画布的路上，等我挑两道",
			"vibe_puppy",
			NotifySoundNudgeBoing
	case "thumbs_up":
		return fmt.Sprintf("%s 双手赞成这道菜！", actorName),
			"太懂我的胃了，今天必须安排上",
			"mood_thumbs_up",
			NotifySoundPlatePop
	case "washing_hands":
		return fmt.Sprintf("%s：洗好手马上上桌！", actorName),
			"筷子端稳啦，这就冲向餐桌",
			"mood_star_eyes",
			NotifySoundDinnerChime
	default:
		return fmt.Sprintf("%s 回戳了你一下", actorName),
			"收到你的小暗号啦，贴贴～",
			"mood_hug_heart",
			NotifySoundNudgeBoing
	}
}

func buildDishAddedCopy(actorName, shortDish string, now time.Time) (string, string) {
	hour := now.Hour()
	switch {
	case hour >= 21 || hour < 5:
		return pickOne([]string{
				fmt.Sprintf("深夜放毒！%s 想吃「%s」", actorName, shortDish),
				fmt.Sprintf("%s 深夜点名「%s」", actorName, shortDish),
			}),
			"馋虫出动啦，刚把这道菜悄悄贴上了画布"
	case hour >= 11 && hour < 14:
		return pickOne([]string{
				fmt.Sprintf("午饭灵感：%s 想吃「%s」", actorName, shortDish),
				fmt.Sprintf("桌上有动静！%s 端上了「%s」", actorName, shortDish),
			}),
			"已经摆上今天这一顿画布，去商量一下吧"
	case hour >= 17 && hour < 21:
		return pickOne([]string{
				fmt.Sprintf("%s 今晚想吃「%s」", actorName, shortDish),
				fmt.Sprintf("开胃预警～%s 加了「%s」", actorName, shortDish),
			}),
			"刚把菜贴上桌面，去画布看看再搭几道吧"
	default:
		return pickOne([]string{
				fmt.Sprintf("桌上有动静！%s 加了「%s」", actorName, shortDish),
				fmt.Sprintf("%s 馋这道「%s」啦", actorName, shortDish),
			}),
			"已经摆在「这一顿」画布上，等你一起挑"
	}
}

func pickOne(candidates []string) string {
	if len(candidates) == 0 {
		return ""
	}
	if len(candidates) == 1 {
		return candidates[0]
	}
	return candidates[rand.IntN(len(candidates))]
}

func extractDishNames(dishes []model.MealDish) []string {
	out := make([]string, 0, len(dishes))
	for _, d := range dishes {
		if n := strings.TrimSpace(d.RecipeName); n != "" {
			out = append(out, n)
		}
	}
	return out
}

func leadDishImage(dishes []model.MealDish) string {
	for i := len(dishes) - 1; i >= 0; i-- {
		if cut := strings.TrimSpace(dishes[i].RecipeCutoutImage); cut != "" {
			return cut
		}
		if img := strings.TrimSpace(dishes[i].RecipeImage); img != "" {
			return img
		}
	}
	return ""
}

func actorDisplayName(userID uint) string {
	var u model.User
	if err := model.DB.Select("id, nickname").First(&u, userID).Error; err == nil {
		if n := strings.TrimSpace(u.Nickname); n != "" {
			return n
		}
	}
	return "Ta"
}

func householdRecipients(householdID, excludeUserID uint) []uint {
	var ids []uint
	model.DB.Model(&model.User{}).
		Where("household_id = ? AND is_active = ? AND id <> ?", householdID, true, excludeUserID).
		Pluck("id", &ids)
	return ids
}

func mealParticipantRecipients(mealID, excludeUserID uint) []uint {
	var ids []uint
	model.DB.Model(&model.MealParticipant{}).
		Where("meal_session_id = ? AND user_id <> ?", mealID, excludeUserID).
		Pluck("user_id", &ids)
	return ids
}

func mergeRecipients(groups ...[]uint) []uint {
	seen := make(map[uint]bool)
	var out []uint
	for _, g := range groups {
		for _, id := range g {
			if id == 0 || seen[id] {
				continue
			}
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

func summarizeDishes(names []string) string {
	cleaned := make([]string, 0, len(names))
	for _, n := range names {
		if t := strings.TrimSpace(n); t != "" {
			cleaned = append(cleaned, t)
		}
	}
	if len(cleaned) == 0 {
		return ""
	}
	if len(cleaned) <= 3 {
		return strings.Join(cleaned, "、")
	}
	return fmt.Sprintf("%s 等 %d 道菜", strings.Join(cleaned[:3], "、"), len(cleaned))
}

func truncateText(s string, maxRunes int) string {
	runes := []rune(strings.TrimSpace(s))
	if len(runes) <= maxRunes {
		return string(runes)
	}
	if maxRunes <= 1 {
		return string(runes[:maxRunes])
	}
	return string(runes[:maxRunes-1]) + "…"
}

func apnsCategoryForEvent(ev *model.NotificationEvent) string {
	switch ev.Kind {
	case model.NotifyKindMealConfirmed:
		return apnsCategoryDinner
	case model.NotifyKindMealDishAdded:
		return apnsCategoryDishOrNudge
	case model.NotifyKindMealNudge:
		if ev.PresetKey == "dinner_ready" {
			return apnsCategoryDinner
		}
		return apnsCategoryDishOrNudge
	case model.NotifyKindTest:
		return apnsCategoryDishOrNudge
	default:
		return ""
	}
}

// --- 标准 APNs HTTP/2 ES256 推送发信器 ---

type apnsAuthCache struct {
	mu       sync.Mutex
	token    string
	issuedAt time.Time
	privKey  *ecdsa.PrivateKey
	keyPath  string
}

var (
	sharedAPNsAuth   apnsAuthCache
	sharedAPNsClient = &http.Client{
		Timeout: 8 * time.Second,
		Transport: &http.Transport{
			ForceAttemptHTTP2: true,
		},
	}
)

func apnsConfigured(cfg config.APNsConfig) bool {
	return cfg.Enabled && cfg.TeamID != "" && cfg.KeyID != "" && cfg.PrivateKeyPath != ""
}

const (
	apnsPending      = "pending"
	apnsRemote       = "remote"
	apnsPendingLimit = time.Minute
)

func apnsTargets(ev *model.NotificationEvent, cfg config.APNsConfig) ([]model.DeviceToken, string) {
	var tokens []model.DeviceToken
	if err := model.DB.Where("user_id = ? AND device_id <> ''", ev.UserID).
		Order("last_seen_at DESC, id DESC").Find(&tokens).Error; err != nil {
		log.Printf("[APNs] 查询设备令牌失败 uid=%d err=%v", ev.UserID, err)
		return nil, ""
	}
	seen := make(map[string]bool)
	tokens = slices.DeleteFunc(tokens, func(device model.DeviceToken) bool {
		if seen[device.DeviceID] {
			return true
		}
		seen[device.DeviceID] = true
		return !device.IsActive || slices.Contains(strings.Split(device.MutedKinds, ","), ev.Kind)
	})
	if len(tokens) == 0 {
		return nil, ""
	}
	if !apnsConfigured(cfg) {
		log.Printf("[APNs-dryrun] uid=%d devices=%d kind=%s preset=%s title=%q deep_link=%s",
			ev.UserID, len(tokens), ev.Kind, ev.PresetKey, ev.Title, ev.DeepLink)
		return nil, ""
	}

	bearer, err := apnsBearerToken(cfg)
	if err != nil {
		log.Printf("[APNs] 生成鉴权 JWT 失败 err=%v", err)
		return nil, ""
	}
	return tokens, bearer
}

func pushEventToDevices(ev *model.NotificationEvent, tokens []model.DeviceToken, cfg config.APNsConfig, bearer, collapseID string) {
	defer func() {
		if err := model.DB.Model(ev).Select("APNsDeliveries").Updates(ev).Error; err != nil {
			log.Printf("[APNs] 保存推送结果失败 event=%d err=%v", ev.ID, err)
		}
	}()
	var unread int64
	model.DB.Model(&model.NotificationEvent{}).
		Where("user_id = ? AND is_read = ?", ev.UserID, false).
		Count(&unread)

	bundleID := cfg.BundleID
	if bundleID == "" {
		bundleID = "com.loverorder.app"
	}

	category := apnsCategoryForEvent(ev)

	for _, dev := range tokens {
		sound := "default"
		if dev.UseCustomSound && ev.SoundName != "" {
			sound = ev.SoundName
		}
		aps := map[string]any{
			"alert": map[string]string{
				"title": ev.Title,
				"body":  ev.Body,
			},
			"sound":           sound,
			"badge":           unread,
			"mutable-content": 1,
		}
		if category != "" {
			aps["category"] = category
		}
		payloadMap := map[string]any{
			"aps":       aps,
			"event_id":  ev.ID,
			"kind":      ev.Kind,
			"deep_link": ev.DeepLink,
		}
		if ev.PresetKey != "" {
			payloadMap["preset_key"] = ev.PresetKey
		}
		if ev.StickerCode != "" {
			payloadMap["sticker_code"] = ev.StickerCode
		}
		if ev.ImageURL != "" {
			payloadMap["image_url"] = ev.ImageURL
		}
		if ev.SoundName != "" {
			payloadMap["sound_name"] = ev.SoundName
		}
		if ev.MealID != nil {
			payloadMap["meal_id"] = *ev.MealID
		}
		payloadBytes, err := json.Marshal(payloadMap)
		if err != nil {
			delete(ev.APNsDeliveries, dev.DeviceID)
			continue
		}

		host := "https://api.sandbox.push.apple.com"
		if cfg.Production || dev.Environment == "production" {
			host = "https://api.push.apple.com"
		}
		endpoint := fmt.Sprintf("%s/3/device/%s", host, dev.Token)
		req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(payloadBytes))
		if err != nil {
			delete(ev.APNsDeliveries, dev.DeviceID)
			continue
		}
		req.Header.Set("authorization", "bearer "+bearer)
		req.Header.Set("apns-topic", bundleID)
		req.Header.Set("apns-push-type", "alert")
		req.Header.Set("apns-priority", "10")
		if collapseID != "" {
			req.Header.Set("apns-collapse-id", collapseID)
		}
		req.Header.Set("content-type", "application/json")

		// 传输超时无法知道 APNs 是否已接收。保留其归属，避免两边各弹一次。
		ev.APNsDeliveries[dev.DeviceID] = apnsRemote
		resp, err := sharedAPNsClient.Do(req)
		if err != nil {
			log.Printf("[APNs] 推送请求失败 dev=%d err=%v", dev.ID, err)
			continue
		}
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		_ = resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			continue
		}
		delete(ev.APNsDeliveries, dev.DeviceID)
		log.Printf("[APNs] 推送拒绝 dev=%d status=%d body=%s", dev.ID, resp.StatusCode, string(respBody))
		if resp.StatusCode == http.StatusGone || (resp.StatusCode == http.StatusBadRequest && strings.Contains(string(respBody), "BadDeviceToken")) {
			model.DB.Model(&model.DeviceToken{}).Where("id = ? AND user_id = ?", dev.ID, ev.UserID).Update("is_active", false)
		}
	}
}

func apnsBearerToken(cfg config.APNsConfig) (string, error) {
	sharedAPNsAuth.mu.Lock()
	defer sharedAPNsAuth.mu.Unlock()

	if sharedAPNsAuth.token != "" && time.Since(sharedAPNsAuth.issuedAt) < 45*time.Minute {
		return sharedAPNsAuth.token, nil
	}

	if sharedAPNsAuth.privKey == nil || sharedAPNsAuth.keyPath != cfg.PrivateKeyPath {
		raw, err := os.ReadFile(cfg.PrivateKeyPath)
		if err != nil {
			return "", err
		}
		block, _ := pem.Decode(raw)
		if block == nil {
			return "", errors.New("无效的 APNs p8 PEM 内容")
		}
		parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err != nil {
			return "", err
		}
		ecKey, ok := parsed.(*ecdsa.PrivateKey)
		if !ok {
			return "", errors.New("APNs 密钥不是 ECDSA 私钥")
		}
		sharedAPNsAuth.privKey = ecKey
		sharedAPNsAuth.keyPath = cfg.PrivateKeyPath
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"iss": cfg.TeamID,
		"iat": now.Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	tok.Header["kid"] = cfg.KeyID
	signed, err := tok.SignedString(sharedAPNsAuth.privKey)
	if err != nil {
		return "", err
	}
	sharedAPNsAuth.token = signed
	sharedAPNsAuth.issuedAt = now
	return signed, nil
}
