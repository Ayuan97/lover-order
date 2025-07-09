package model

import (
	"encoding/json"
	"time"

	"gorm.io/gorm"
)

// Favorite 收藏模型
type Favorite struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"user_id" gorm:"not null;uniqueIndex:uk_user_recipe;comment:用户ID"`
	RecipeID  uint      `json:"recipe_id" gorm:"not null;uniqueIndex:uk_user_recipe;index;comment:菜谱ID"`
	CreatedAt time.Time `json:"created_at"`

	// 关联关系
	User   User   `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Recipe Recipe `json:"recipe,omitempty" gorm:"foreignKey:RecipeID"`
}

// TableName 指定表名
func (Favorite) TableName() string {
	return "favorites"
}

// RecipeReview 菜谱评价模型
type RecipeReview struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	UserID      uint           `json:"user_id" gorm:"not null;index;comment:评价用户ID"`
	RecipeID    uint           `json:"recipe_id" gorm:"not null;index;comment:菜谱ID"`
	OrderID     *uint          `json:"order_id" gorm:"index;comment:关联订单ID"`
	Rating      int            `json:"rating" gorm:"not null;index;comment:评分(1-5分)"`
	Comment     string         `json:"comment" gorm:"type:text;comment:评价内容"`
	Images      JSON           `json:"images" gorm:"type:json;comment:评价图片"`
	IsAnonymous bool           `json:"is_anonymous" gorm:"default:false;comment:是否匿名评价"`
	Reply       string         `json:"reply" gorm:"type:text;comment:回复内容"`
	RepliedBy   *uint          `json:"replied_by" gorm:"comment:回复人ID"`
	RepliedAt   *time.Time     `json:"replied_at" gorm:"comment:回复时间"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系
	User          User   `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Recipe        Recipe `json:"recipe,omitempty" gorm:"foreignKey:RecipeID"`
	Order         *Order `json:"order,omitempty" gorm:"foreignKey:OrderID"`
	RepliedByUser *User  `json:"replied_by_user,omitempty" gorm:"foreignKey:RepliedBy"`
}

// TableName 指定表名
func (RecipeReview) TableName() string {
	return "recipe_reviews"
}

// GetImagesSlice 获取评价图片数组
func (r *RecipeReview) GetImagesSlice() []string {
	if len(r.Images) == 0 {
		return []string{}
	}
	var images []string
	json.Unmarshal(r.Images, &images)
	return images
}

// SetImagesSlice 设置评价图片数组
func (r *RecipeReview) SetImagesSlice(images []string) error {
	data, err := json.Marshal(images)
	if err != nil {
		return err
	}
	r.Images = JSON(data)
	return nil
}

// FamilyInvitation 家庭邀请模型
type FamilyInvitation struct {
	ID         uint           `json:"id" gorm:"primaryKey"`
	FamilyID   uint           `json:"family_id" gorm:"not null;index;comment:家庭ID"`
	InviteCode string         `json:"invite_code" gorm:"not null;index;comment:邀请码"`
	InvitedBy  uint           `json:"invited_by" gorm:"not null;index;comment:邀请人ID"`
	InviteType string         `json:"invite_type" gorm:"type:enum('member','guest');default:'guest';comment:邀请类型"`
	ExpiresAt  time.Time      `json:"expires_at" gorm:"not null;index;comment:过期时间"`
	MaxUses    int            `json:"max_uses" gorm:"default:1;comment:最大使用次数"`
	UsedCount  int            `json:"used_count" gorm:"default:0;comment:已使用次数"`
	UsedBy     JSON           `json:"used_by" gorm:"type:json;comment:使用者ID列表"`
	Note       string         `json:"note" gorm:"size:200;comment:邀请备注"`
	IsActive   bool           `json:"is_active" gorm:"default:true;comment:是否有效"`
	CreatedAt  time.Time      `json:"created_at"`
	UpdatedAt  time.Time      `json:"updated_at"`
	DeletedAt  gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系
	Family        Family `json:"family,omitempty" gorm:"foreignKey:FamilyID"`
	InvitedByUser User   `json:"invited_by_user,omitempty" gorm:"foreignKey:InvitedBy"`
}

// TableName 指定表名
func (FamilyInvitation) TableName() string {
	return "family_invitations"
}

// IsExpired 判断邀请是否过期
func (f *FamilyInvitation) IsExpired() bool {
	return time.Now().After(f.ExpiresAt)
}

// IsAvailable 判断邀请是否可用
func (f *FamilyInvitation) IsAvailable() bool {
	return f.IsActive && !f.IsExpired() && f.UsedCount < f.MaxUses
}

// GetUsedBySlice 获取使用者ID数组
func (f *FamilyInvitation) GetUsedBySlice() []uint {
	if len(f.UsedBy) == 0 {
		return []uint{}
	}
	var usedBy []uint
	json.Unmarshal(f.UsedBy, &usedBy)
	return usedBy
}

// AddUsedBy 添加使用者ID
func (f *FamilyInvitation) AddUsedBy(userID uint) error {
	usedBy := f.GetUsedBySlice()
	usedBy = append(usedBy, userID)

	data, err := json.Marshal(usedBy)
	if err != nil {
		return err
	}
	f.UsedBy = JSON(data)
	f.UsedCount = len(usedBy)

	return DB.Model(f).Updates(map[string]interface{}{
		"used_by":    f.UsedBy,
		"used_count": f.UsedCount,
	}).Error
}
