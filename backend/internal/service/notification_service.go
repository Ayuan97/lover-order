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
	"net/http"
	"os"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"gorm.io/gorm"
	"lover-order-backend/internal/config"
	"lover-order-backend/internal/model"
)

// NotificationService 通知事件与 APNs 推送服务
type NotificationService struct{}

// NewNotificationService 构造
func NewNotificationService() *NotificationService {
	return &NotificationService{}
}

// DeviceRegisterInput 设备推送令牌注册入参
type DeviceRegisterInput struct {
	Token       string   `json:"token" binding:"required"`
	DeviceID    string   `json:"device_id" binding:"required,uuid"`
	Platform    string   `json:"platform"`
	Environment string   `json:"environment"`
	AppVersion  string   `json:"app_version"`
	MutedKinds  []string `json:"muted_kinds" binding:"max=7,unique,dive,oneof=meal_dish_added meal_confirmed meal_completed meal_reviewed dining_joined dining_dish_added household_joined"`
}

// NotificationListResult 通知列表响应
type NotificationListResult struct {
	Items          []model.NotificationEvent `json:"items"`
	UnreadCount    int64                     `json:"unread_count"`
	LatestID       uint                      `json:"latest_id"`
	APNsDeliveries map[uint]string           `json:"apns_deliveries"`
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

	mutedKinds := strings.Join(in.MutedKinds, ",")
	var existing model.DeviceToken
	err := model.DB.Where("token = ?", tok).First(&existing).Error
	if err == nil {
		return model.DB.Model(&existing).Updates(map[string]any{
			"user_id":      userID,
			"device_id":    in.DeviceID,
			"platform":     platform,
			"environment":  env,
			"app_version":  strings.TrimSpace(in.AppVersion),
			"muted_kinds":  mutedKinds,
			"is_active":    true,
			"last_seen_at": time.Now(),
		}).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	item := &model.DeviceToken{
		UserID:      userID,
		DeviceID:    in.DeviceID,
		Token:       tok,
		Platform:    platform,
		Environment: env,
		AppVersion:  strings.TrimSpace(in.AppVersion),
		MutedKinds:  mutedKinds,
		IsActive:    true,
		LastSeenAt:  time.Now(),
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

// SendTest 为当前用户生成一条测试提醒（优先关联最近完成的餐次以演示详情跳转）
func (s *NotificationService) SendTest(userID uint) (*model.NotificationEvent, error) {
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, errors.New("用户不存在")
	}

	var hid *uint
	var mealIDPtr *uint
	deepLink := "lo://meal/0"
	title := "今天吃什么定好啦"
	body := "Ta 挑好了今晚的菜，点进画布看看吧"

	if user.HouseholdID != nil {
		hid = user.HouseholdID
		var completed model.MealSession
		if err := model.DB.Where("household_id = ? AND status = ?", *hid, model.MealStatusCompleted).
			Order("id DESC").First(&completed).Error; err == nil {
			idCopy := completed.ID
			mealIDPtr = &idCopy
			deepLink = fmt.Sprintf("lo://history/%d", completed.ID)
			title = "这顿饭可以分享啦"
			name := strings.TrimSpace(completed.Title)
			if name == "" {
				name = "最近这顿饭"
			}
			body = fmt.Sprintf("「%s」已收进记录，生成海报或补写两句评价吧", name)
		} else {
			var active model.MealSession
			if err := model.DB.Where("household_id = ? AND status IN ?", *hid, []string{model.MealStatusPlanning, model.MealStatusConfirmed}).
				Order("id DESC").First(&active).Error; err == nil {
				idCopy := active.ID
				mealIDPtr = &idCopy
				deepLink = fmt.Sprintf("lo://meal/%d", active.ID)
			}
		}
	}

	ev := &model.NotificationEvent{
		UserID:      userID,
		ActorID:     &userID,
		HouseholdID: hid,
		Kind:        model.NotifyKindTest,
		Title:       title,
		Body:        body,
		MealID:      mealIDPtr,
		DeepLink:    deepLink,
	}
	if err := model.DB.Create(ev).Error; err != nil {
		return nil, err
	}
	_ = model.DB.Preload("Actor").First(ev, ev.ID).Error

	return ev, nil
}

// NotifyMealDishAdded 通知家里其他人有人加了新菜
func (s *NotificationService) NotifyMealDishAdded(householdID, actorID, mealID uint, dishName string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		title := fmt.Sprintf("%s 想吃「%s」", actorName, truncateText(dishName, 16))
		body := fmt.Sprintf("%s 往今天这一顿加了「%s」，去画布看看吧", actorName, truncateText(dishName, 20))
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindMealDishAdded, title, body, &mealID, "", fmt.Sprintf("lo://meal/%d", mealID))
	}()
}

// NotifyMealConfirmed 通知家里其他人及点菜房客人今天这顿定好了
func (s *NotificationService) NotifyMealConfirmed(householdID, actorID, mealID uint, dishNames []string) {
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
		title := "今天吃什么定好啦"
		body := fmt.Sprintf("%s 定下了这顿：%s", actorName, summary)
		if summary == "" {
			body = fmt.Sprintf("%s 定好了今天这顿，去画布看一眼吧", actorName)
		}
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindMealConfirmed, title, body, &mealID, "", fmt.Sprintf("lo://meal/%d", mealID))
	}()
}

// NotifyMealCompleted 通知家里其他人这顿吃完了
func (s *NotificationService) NotifyMealCompleted(householdID, actorID, mealID uint, mealTitle string) {
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
		title := "这顿饭吃好啦"
		body := fmt.Sprintf("%s 记下了「%s」吃完，来写几句感受或分享海报吧", actorName, truncateText(label, 18))
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindMealCompleted, title, body, &mealID, "", fmt.Sprintf("lo://history/%d", mealID))
	}()
}

// NotifyMealReviewed 通知家里其他人收到了新评价/照片
func (s *NotificationService) NotifyMealReviewed(householdID, actorID, mealID uint, rating int, comment string, photoCount int) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		title := fmt.Sprintf("%s 给这顿打了 %d 星", actorName, rating)
		trimmed := strings.TrimSpace(comment)
		var body string
		switch {
		case trimmed != "" && photoCount > 0:
			body = fmt.Sprintf("「%s」· 还附带 %d 张照片", truncateText(trimmed, 24), photoCount)
		case trimmed != "":
			body = fmt.Sprintf("「%s」", truncateText(trimmed, 34))
		case photoCount > 0:
			body = fmt.Sprintf("%s 晒了 %d 张这顿饭的照片，快去看看", actorName, photoCount)
		default:
			body = fmt.Sprintf("%s 留下了餐后记录，去看看这顿饭吧", actorName)
		}
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindMealReviewed, title, body, &mealID, "", fmt.Sprintf("lo://history/%d", mealID))
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
		title := fmt.Sprintf("%s 来一起点菜啦", actorName)
		body := fmt.Sprintf("加入了点菜房 %s，看看 Ta 想点什么", roomCode)
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindDiningJoined, title, body, &mealID, roomCode, fmt.Sprintf("lo://meal/%d", mealID))
	}()
}

// NotifyDiningDishAdded 通知家里成员有朋友在点菜房里点了菜
func (s *NotificationService) NotifyDiningDishAdded(householdID, actorID, mealID uint, dishName string) {
	go func() {
		actorName := actorDisplayName(actorID)
		recipients := householdRecipients(householdID, actorID)
		if len(recipients) == 0 {
			return
		}
		title := fmt.Sprintf("%s 点了一道「%s」", actorName, truncateText(dishName, 16))
		body := fmt.Sprintf("来自聚餐点菜房，快看看今晚菜单吧")
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindDiningDishAdded, title, body, &mealID, "", fmt.Sprintf("lo://meal/%d", mealID))
	}()
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
		title := fmt.Sprintf("%s 加入了「%s」", actorName, truncateText(name, 14))
		body := "以后可以一起在画布上商量每天吃什么啦"
		s.dispatch(recipients, &actorID, &householdID, model.NotifyKindHouseholdJoined, title, body, nil, "", "lo://household")
	}()
}

func (s *NotificationService) dispatch(
	recipientIDs []uint,
	actorID *uint,
	householdID *uint,
	kind, title, body string,
	mealID *uint,
	roomCode, deepLink string,
) {
	cfg := config.AppConfig.APNs
	for _, uid := range recipientIDs {
		ev := &model.NotificationEvent{
			UserID:      uid,
			ActorID:     actorID,
			HouseholdID: householdID,
			Kind:        kind,
			Title:       title,
			Body:        body,
			MealID:      mealID,
			RoomCode:    roomCode,
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
			pushEventToDevices(ev, targets, cfg, bearer)
		}
	}
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
		log.Printf("[APNs-dryrun] uid=%d devices=%d kind=%s title=%q deep_link=%s",
			ev.UserID, len(tokens), ev.Kind, ev.Title, ev.DeepLink)
		return nil, ""
	}

	bearer, err := apnsBearerToken(cfg)
	if err != nil {
		log.Printf("[APNs] 生成鉴权 JWT 失败 err=%v", err)
		return nil, ""
	}
	return tokens, bearer
}

func pushEventToDevices(ev *model.NotificationEvent, tokens []model.DeviceToken, cfg config.APNsConfig, bearer string) {
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

	payloadMap := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{
				"title": ev.Title,
				"body":  ev.Body,
			},
			"sound": "default",
			"badge": unread,
		},
		"event_id":  ev.ID,
		"kind":      ev.Kind,
		"deep_link": ev.DeepLink,
	}
	if ev.MealID != nil {
		payloadMap["meal_id"] = *ev.MealID
	}
	payloadBytes, err := json.Marshal(payloadMap)
	if err != nil {
		clear(ev.APNsDeliveries)
		return
	}

	for _, dev := range tokens {
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
