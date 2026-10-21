package model

import "time"

// StickerFavorite 保存个人可重复使用的贴图，与餐次和画布排版独立。
type StickerFavorite struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"-" gorm:"not null;uniqueIndex:uk_user_sticker_image"`
	Image     string    `json:"image" gorm:"size:512;not null;uniqueIndex:uk_user_sticker_image"`
	CreatedAt time.Time `json:"created_at"`
}
