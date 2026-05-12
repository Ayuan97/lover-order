package model

import (
	"time"

	"gorm.io/gorm"
)

// 场景常量
const (
	SceneCouple = "pair"   // 我们这顿
	SceneFamily = "family" // 家里这顿
	SceneFuture = "future" // 未来这顿
)

// 心情常量
const (
	MoodEasy    = "easy"    // 轻松点
	MoodNormal  = "normal"  // 正常吃
	MoodSerious = "serious" // 认真吃
	MoodChange  = "change"  // 换换口味
)

// 一顿状态
const (
	MealStatusPlanning  = "planning"  // 规划中
	MealStatusConfirmed = "confirmed" // 定下了
	MealStatusCompleted = "completed" // 吃完了
	MealStatusCancelled = "cancelled" // 取消了
)

// MealSession 这一顿 用户挑菜并最终决定吃什么的载体
type MealSession struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	Title       string         `json:"title" gorm:"size:64;comment:可选的一顿标题"`
	Scene       string         `json:"scene" gorm:"type:enum('pair','family','future');default:'pair';index;comment:场景"`
	Mood        string         `json:"mood" gorm:"type:enum('easy','normal','serious','change');default:'easy';comment:心情"`
	PlannedAt   *time.Time     `json:"planned_at" gorm:"comment:打算吃的时间"`
	ConfirmedAt *time.Time     `json:"confirmed_at" gorm:"comment:定下来的时间"`
	CompletedAt *time.Time     `json:"completed_at" gorm:"comment:吃完时间"`
	Status      string         `json:"status" gorm:"type:enum('planning','confirmed','completed','cancelled');default:'planning';index"`
	Note        string         `json:"note" gorm:"size:255;comment:备注"`
	HouseholdID uint           `json:"household_id" gorm:"not null;index"`
	CreatedBy   uint           `json:"created_by" gorm:"not null;index"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`

	Dishes  []MealDish   `json:"dishes,omitempty" gorm:"foreignKey:MealSessionID"`
	Reviews []MealReview `json:"reviews,omitempty" gorm:"foreignKey:MealSessionID"`
	Creator *User        `json:"creator,omitempty" gorm:"foreignKey:CreatedBy"`
}

// TableName 一顿表名
func (MealSession) TableName() string {
	return "meal_sessions"
}

// MealDish 一顿里加入的某个菜 保留快照
type MealDish struct {
	ID            uint      `json:"id" gorm:"primaryKey"`
	MealSessionID uint      `json:"meal_session_id" gorm:"not null;index"`
	RecipeID      *uint     `json:"recipe_id" gorm:"index;comment:菜谱 ID 删除菜谱后可为空"`
	RecipeName    string    `json:"recipe_name" gorm:"size:64;not null;comment:菜名快照"`
	RecipeImage   string    `json:"recipe_image" gorm:"size:512;comment:菜图快照"`
	Note          string    `json:"note" gorm:"size:255;comment:备注 如换换口味"`
	SortOrder     int       `json:"sort_order" gorm:"default:0"`
	AddedBy       uint      `json:"added_by" gorm:"not null;index"`
	CreatedAt     time.Time `json:"created_at"`

	Recipe *Recipe `json:"recipe,omitempty" gorm:"foreignKey:RecipeID"`
}

// TableName 一顿里菜表名
func (MealDish) TableName() string {
	return "meal_dishes"
}

// MealReview 一顿吃完后的留言/打分
type MealReview struct {
	ID            uint           `json:"id" gorm:"primaryKey"`
	MealSessionID uint           `json:"meal_session_id" gorm:"not null;index"`
	UserID        uint           `json:"user_id" gorm:"not null;index"`
	Rating        int            `json:"rating" gorm:"comment:1-5 分"`
	Comment       string         `json:"comment" gorm:"type:text;comment:留言"`
	Photos        JSON           `json:"photos" gorm:"type:json;comment:照片"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `json:"-" gorm:"index"`

	User *User `json:"user,omitempty" gorm:"foreignKey:UserID"`
}

// TableName 一顿评价表名
func (MealReview) TableName() string {
	return "meal_reviews"
}
