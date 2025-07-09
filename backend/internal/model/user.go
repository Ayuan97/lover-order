package model

import (
	"time"

	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	ID             uint           `json:"id" gorm:"primaryKey"`
	OpenID         string         `json:"openid" gorm:"uniqueIndex;size:100;not null;comment:微信openid"`
	UnionID        string         `json:"unionid" gorm:"size:100;comment:微信unionid"`
	Nickname       string         `json:"nickname" gorm:"size:100;comment:昵称"`
	Avatar         string         `json:"avatar" gorm:"size:500;comment:头像URL"`
	Phone          string         `json:"phone" gorm:"size:20;comment:手机号"`
	Gender         int8           `json:"gender" gorm:"default:0;comment:性别：0未知，1男，2女"`
	Role           string         `json:"role" gorm:"type:enum('admin','member','guest');default:'member';comment:角色"`
	FamilyID       *uint          `json:"family_id" gorm:"index;comment:家庭ID"`
	GuestExpiresAt *time.Time     `json:"guest_expires_at" gorm:"comment:访客过期时间"`
	LastLoginAt    *time.Time     `json:"last_login_at" gorm:"comment:最后登录时间"`
	IsActive       bool           `json:"is_active" gorm:"default:true;comment:是否激活"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系
	Family          *Family            `json:"family,omitempty" gorm:"foreignKey:FamilyID"`
	CreatedRecipes  []Recipe           `json:"created_recipes,omitempty" gorm:"foreignKey:CreatedBy"`
	Orders          []Order            `json:"orders,omitempty" gorm:"foreignKey:UserID"`
	Favorites       []Favorite         `json:"favorites,omitempty" gorm:"foreignKey:UserID"`
	Reviews         []RecipeReview     `json:"reviews,omitempty" gorm:"foreignKey:UserID"`
	SentInvitations []FamilyInvitation `json:"sent_invitations,omitempty" gorm:"foreignKey:InvitedBy"`
}

// TableName 指定表名
func (User) TableName() string {
	return "users"
}

// IsGuest 判断是否为访客
func (u *User) IsGuest() bool {
	return u.Role == "guest"
}

// IsAdmin 判断是否为管理员
func (u *User) IsAdmin() bool {
	return u.Role == "admin"
}

// IsGuestExpired 判断访客是否过期
func (u *User) IsGuestExpired() bool {
	if !u.IsGuest() || u.GuestExpiresAt == nil {
		return false
	}
	return time.Now().After(*u.GuestExpiresAt)
}

// CanAccessFamily 判断用户是否可以访问指定家庭
func (u *User) CanAccessFamily(familyID uint) bool {
	if u.FamilyID == nil {
		return false
	}
	if *u.FamilyID != familyID {
		return false
	}
	if u.IsGuest() && u.IsGuestExpired() {
		return false
	}
	return u.IsActive
}

// Family 家庭模型
type Family struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	Name        string         `json:"name" gorm:"size:100;not null;comment:家庭名称"`
	InviteCode  string         `json:"invite_code" gorm:"uniqueIndex;size:20;comment:邀请码"`
	Avatar      string         `json:"avatar" gorm:"size:500;comment:家庭头像"`
	Description string         `json:"description" gorm:"type:text;comment:家庭描述"`
	CreatedBy   uint           `json:"created_by" gorm:"not null;comment:创建者ID"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系（注意：为避免循环依赖，Creator关联在需要时手动加载）
	Members     []User             `json:"members,omitempty" gorm:"foreignKey:FamilyID"`
	Categories  []RecipeCategory   `json:"categories,omitempty" gorm:"foreignKey:FamilyID"`
	Recipes     []Recipe           `json:"recipes,omitempty" gorm:"foreignKey:FamilyID"`
	Orders      []Order            `json:"orders,omitempty" gorm:"foreignKey:FamilyID"`
	Invitations []FamilyInvitation `json:"invitations,omitempty" gorm:"foreignKey:FamilyID"`
}

// TableName 指定表名
func (Family) TableName() string {
	return "families"
}

// GetMemberCount 获取家庭成员数量
func (f *Family) GetMemberCount() int64 {
	var count int64
	DB.Model(&User{}).Where("family_id = ? AND role != 'guest' AND is_active = true", f.ID).Count(&count)
	return count
}

// GetActiveGuestCount 获取活跃访客数量
func (f *Family) GetActiveGuestCount() int64 {
	var count int64
	DB.Model(&User{}).Where("family_id = ? AND role = 'guest' AND is_active = true AND (guest_expires_at IS NULL OR guest_expires_at > ?)",
		f.ID, time.Now()).Count(&count)
	return count
}
