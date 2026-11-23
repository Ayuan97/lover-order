package model

import "time"

// MealCanvas 餐次自由画布云端文档（供家庭成员与聚餐来客实时共享与历史回放）
type MealCanvas struct {
	ID            uint      `json:"id" gorm:"primaryKey"`
	MealSessionID uint      `json:"meal_session_id" gorm:"not null;uniqueIndex"`
	Revision      int64     `json:"revision" gorm:"not null;default:0"`
	Document      JSON      `json:"document" gorm:"type:longtext"`
	UpdatedBy     uint      `json:"updated_by" gorm:"default:0"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// TableName 画布表名
func (MealCanvas) TableName() string {
	return "meal_canvases"
}
