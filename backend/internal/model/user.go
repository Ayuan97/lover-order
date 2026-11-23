package model

import (
	"time"

	"gorm.io/gorm"
)

// User 用户
type User struct {
	ID           uint           `json:"id" gorm:"primaryKey"`
	AppleUserID  string         `json:"apple_user_id" gorm:"uniqueIndex;size:128;not null;comment:Apple 用户唯一标识"`
	DeviceID     *string        `json:"device_id,omitempty" gorm:"uniqueIndex;size:128;comment:设备唯一标识"`
	PasswordHash string         `json:"-" gorm:"size:255;not null;default:'';comment:bcrypt 密码哈希"`
	HasPassword  bool           `json:"has_password" gorm:"-"`
	Email        string         `json:"email" gorm:"size:128;comment:邮箱（Apple 首次登录返回）"`
	Nickname     string         `json:"nickname" gorm:"size:64;not null;default:'';comment:昵称"`
	Avatar       string         `json:"avatar" gorm:"size:512;comment:头像 URL"`
	Gender       int8           `json:"gender" gorm:"default:0;comment:性别 0未知 1男 2女"`
	HouseholdID  *uint          `json:"household_id" gorm:"index;comment:所属一个家"`
	DefaultScene string         `json:"default_scene" gorm:"size:16;default:'household';comment:默认餐次标签 产品固定 household"`
	DefaultMood  string         `json:"default_mood" gorm:"size:16;default:'easy';comment:默认心情 easy/normal/serious/change"`
	TastePrefs   JSON           `json:"taste_prefs" gorm:"type:json;comment:口味偏好标签"`
	IsActive     bool           `json:"is_active" gorm:"default:true;index;comment:是否激活"`
	LastLoginAt  *time.Time     `json:"last_login_at" gorm:"comment:最后登录时间"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `json:"-" gorm:"index"`

	Household *Household `json:"household,omitempty" gorm:"foreignKey:HouseholdID"`
}

// AfterFind 查询用户后填充计算字段
func (u *User) AfterFind(tx *gorm.DB) error {
	u.HasPassword = u.PasswordHash != ""
	return nil
}

// TableName 用户表名
func (User) TableName() string {
	return "users"
}

// InHousehold 判断是否已加入一个家
func (u *User) InHousehold() bool {
	return u.HouseholdID != nil && *u.HouseholdID > 0
}
