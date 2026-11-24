package model

import (
	"time"

	"gorm.io/gorm"
)

// Household 一个"家" 支持两人/多人共用一份菜单
type Household struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	Name        string         `json:"name" gorm:"size:64;not null;default:'我们家';comment:家的名字"`
	InviteCode  string         `json:"invite_code" gorm:"uniqueIndex;size:16;not null;comment:邀请码"`
	Description string         `json:"description" gorm:"size:255;comment:简介"`
	CreatedBy   uint           `json:"created_by" gorm:"not null;index;comment:创建者"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`

	Members []User `json:"members,omitempty" gorm:"foreignKey:HouseholdID"`
}

// TableName 一个家表名
func (Household) TableName() string {
	return "households"
}

// MemberCount 当前家庭活跃成员数
func (h *Household) MemberCount() int64 {
	if DB == nil {
		return 0
	}
	var count int64
	DB.Model(&User{}).
		Where("household_id = ? AND is_active = ?", h.ID, true).
		Count(&count)
	return count
}

// HouseholdLaunchCanvas 家庭共享开屏动画画布（由家庭创建者发布，所有成员可选择使用或自行 DIY）
type HouseholdLaunchCanvas struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	HouseholdID uint      `json:"household_id" gorm:"not null;uniqueIndex"`
	Document    JSON      `json:"document" gorm:"type:longtext"`
	Motion      string    `json:"motion" gorm:"size:32;default:'fadeZoom'"`
	HoldSpeed   string    `json:"hold_speed" gorm:"size:32;default:'standard'"`
	UpdatedBy   uint      `json:"updated_by" gorm:"default:0"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// TableName 家庭共享开屏画布表名
func (HouseholdLaunchCanvas) TableName() string {
	return "household_launch_canvases"
}
