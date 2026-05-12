package model

import "time"

// Favorite 用户对菜谱的收藏
type Favorite struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"user_id" gorm:"not null;uniqueIndex:uk_user_recipe;index"`
	RecipeID  uint      `json:"recipe_id" gorm:"not null;uniqueIndex:uk_user_recipe;index"`
	CreatedAt time.Time `json:"created_at"`

	Recipe *Recipe `json:"recipe,omitempty" gorm:"foreignKey:RecipeID"`
}

// TableName 收藏表名
func (Favorite) TableName() string {
	return "favorites"
}

// HouseholdInvite 一个家的邀请记录 用邀请码扩展支持过期与限次
type HouseholdInvite struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	HouseholdID uint       `json:"household_id" gorm:"not null;index"`
	Code        string     `json:"code" gorm:"uniqueIndex;size:16;not null"`
	CreatedBy   uint       `json:"created_by" gorm:"not null;index"`
	ExpiresAt   *time.Time `json:"expires_at" gorm:"comment:为空则永久"`
	MaxUses     int        `json:"max_uses" gorm:"default:0;comment:0 表示不限制"`
	UsedCount   int        `json:"used_count" gorm:"default:0"`
	IsActive    bool       `json:"is_active" gorm:"default:true;index"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

// TableName 家邀请表名
func (HouseholdInvite) TableName() string {
	return "household_invites"
}

// Usable 判断邀请是否可用
func (h *HouseholdInvite) Usable() bool {
	if !h.IsActive {
		return false
	}
	if h.ExpiresAt != nil && time.Now().After(*h.ExpiresAt) {
		return false
	}
	if h.MaxUses > 0 && h.UsedCount >= h.MaxUses {
		return false
	}
	return true
}
