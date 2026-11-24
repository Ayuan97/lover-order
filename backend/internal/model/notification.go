package model

import (
	"time"
)

// 通知事件类型常量
const (
	NotifyKindMealDishAdded   = "meal_dish_added"
	NotifyKindMealConfirmed   = "meal_confirmed"
	NotifyKindMealCompleted   = "meal_completed"
	NotifyKindMealReviewed    = "meal_reviewed"
	NotifyKindDiningJoined    = "dining_joined"
	NotifyKindDiningDishAdded = "dining_dish_added"
	NotifyKindHouseholdJoined = "household_joined"
	NotifyKindMealNudge       = "meal_nudge"
	NotifyKindNudgeReply      = "meal_nudge_reply"
	NotifyKindTest            = "test"
)

// DeviceToken 设备推送令牌
type DeviceToken struct {
	ID             uint      `json:"id" gorm:"primaryKey"`
	UserID         uint      `json:"user_id" gorm:"not null;index"`
	DeviceID       string    `json:"-" gorm:"size:128"`
	Token          string    `json:"token" gorm:"uniqueIndex;size:255;not null"`
	Platform       string    `json:"platform" gorm:"size:16;default:'ios';not null"`
	Environment    string    `json:"environment" gorm:"size:16;default:'sandbox';not null"`
	AppVersion     string    `json:"app_version" gorm:"size:32"`
	MutedKinds     string    `json:"-" gorm:"size:220;default:'';not null"`
	UseCustomSound bool      `json:"-" gorm:"default:true;not null"`
	IsActive       bool      `json:"is_active" gorm:"default:true;index"`
	LastSeenAt     time.Time `json:"last_seen_at"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// TableName 设备令牌表名
func (DeviceToken) TableName() string {
	return "device_tokens"
}

// NotificationEvent 站内通知事件流与推送记录
type NotificationEvent struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	UserID      uint       `json:"user_id" gorm:"not null;index"`
	ActorID     *uint      `json:"actor_id" gorm:"index"`
	HouseholdID *uint      `json:"household_id" gorm:"index"`
	Kind        string     `json:"kind" gorm:"size:32;not null;index"`
	PresetKey   string     `json:"preset_key,omitempty" gorm:"size:32;default:'';not null"`
	Title       string     `json:"title" gorm:"size:120;not null"`
	Body        string     `json:"body" gorm:"size:255;not null"`
	StickerCode string     `json:"sticker_code,omitempty" gorm:"size:64;default:'';not null"`
	ImageURL    string     `json:"image_url,omitempty" gorm:"size:512;default:'';not null"`
	SoundName   string     `json:"sound_name,omitempty" gorm:"size:48;default:'';not null"`
	MealID      *uint      `json:"meal_id" gorm:"index"`
	RoomCode    string     `json:"room_code" gorm:"size:16"`
	DeepLink    string     `json:"deep_link" gorm:"size:128"`
	IsRead      bool       `json:"is_read" gorm:"default:false;index"`
	ReadAt      *time.Time `json:"read_at"`
	CreatedAt   time.Time  `json:"created_at" gorm:"index"`

	APNsDeliveries map[string]string `json:"-" gorm:"type:json;serializer:json"`

	Actor *User `json:"actor,omitempty" gorm:"foreignKey:ActorID"`
}

// TableName 通知事件表名
func (NotificationEvent) TableName() string {
	return "notification_events"
}
