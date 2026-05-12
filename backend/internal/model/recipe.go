package model

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// JSON 自定义 JSON 列类型 用于在 MySQL JSON 字段与 Go 类型间转换
type JSON []byte

// Value 实现 driver.Valuer
func (j JSON) Value() (driver.Value, error) {
	if len(j) == 0 {
		return nil, nil
	}
	return string(j), nil
}

// Scan 实现 sql.Scanner
func (j *JSON) Scan(value interface{}) error {
	if value == nil {
		*j = nil
		return nil
	}
	switch s := value.(type) {
	case string:
		*j = []byte(s)
	case []byte:
		*j = s
	default:
		return fmt.Errorf("cannot scan %T into JSON", value)
	}
	return nil
}

// RecipeCategory 菜谱分类
type RecipeCategory struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	Name        string         `json:"name" gorm:"size:32;not null;comment:分类名"`
	Icon        string         `json:"icon" gorm:"size:32;comment:分类图标 emoji 或字符"`
	Color       string         `json:"color" gorm:"size:16;default:'#516B4A';comment:分类色"`
	SortOrder   int            `json:"sort_order" gorm:"default:0;comment:排序"`
	HouseholdID uint           `json:"household_id" gorm:"not null;index;comment:所属一个家"`
	IsActive    bool           `json:"is_active" gorm:"default:true;comment:是否启用"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`
}

// TableName 菜谱分类表名
func (RecipeCategory) TableName() string {
	return "recipe_categories"
}

// Recipe 菜谱
type Recipe struct {
	ID            uint           `json:"id" gorm:"primaryKey"`
	Name          string         `json:"name" gorm:"size:64;not null;comment:菜名"`
	Description   string         `json:"description" gorm:"size:255;comment:简介"`
	CoverImage    string         `json:"cover_image" gorm:"size:512;comment:封面图"`
	Images        JSON           `json:"images" gorm:"type:json;comment:图集"`
	CategoryID    *uint          `json:"category_id" gorm:"index;comment:分类"`
	CookingTime   int            `json:"cooking_time" gorm:"default:0;comment:制作时间 分钟"`
	Difficulty    string         `json:"difficulty" gorm:"type:enum('easy','medium','hard');default:'easy';comment:难度"`
	Servings      int            `json:"servings" gorm:"default:2;comment:几人份"`
	Ingredients   JSON           `json:"ingredients" gorm:"type:json;comment:食材清单"`
	Steps         JSON           `json:"steps" gorm:"type:json;comment:做法步骤"`
	Tips          string         `json:"tips" gorm:"type:text;comment:小贴士"`
	Tags          JSON           `json:"tags" gorm:"type:json;comment:风味标签"`
	MoodTags      JSON           `json:"mood_tags" gorm:"type:json;comment:适用心情 easy/normal/serious/change"`
	SceneTags     JSON           `json:"scene_tags" gorm:"type:json;comment:适用场景标签"`
	HouseholdID   uint           `json:"household_id" gorm:"not null;index;comment:所属一个家"`
	CreatedBy     uint           `json:"created_by" gorm:"not null;index;comment:创建者"`
	IsArchived    bool           `json:"is_archived" gorm:"default:false;index;comment:是否归档"`
	ViewCount     int            `json:"view_count" gorm:"default:0;comment:查看次数"`
	UseCount      int            `json:"use_count" gorm:"default:0;comment:加入一顿次数"`
	LastUsedAt    *time.Time     `json:"last_used_at" gorm:"comment:最近一次被吃"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `json:"-" gorm:"index"`

	Category *RecipeCategory `json:"category,omitempty" gorm:"foreignKey:CategoryID"`
	Creator  *User           `json:"creator,omitempty" gorm:"foreignKey:CreatedBy"`
}

// TableName 菜谱表名
func (Recipe) TableName() string {
	return "recipes"
}

// ImagesSlice 把 JSON 列转成字符串切片
func (r *Recipe) ImagesSlice() []string {
	return jsonToStringSlice(r.Images)
}

// SetImages 把字符串切片写回 JSON 列
func (r *Recipe) SetImages(items []string) error {
	data, err := json.Marshal(items)
	if err != nil {
		return err
	}
	r.Images = JSON(data)
	return nil
}

// TagsSlice 取标签数组
func (r *Recipe) TagsSlice() []string {
	return jsonToStringSlice(r.Tags)
}

// SetTags 写标签数组
func (r *Recipe) SetTags(items []string) error {
	data, err := json.Marshal(items)
	if err != nil {
		return err
	}
	r.Tags = JSON(data)
	return nil
}

// MoodTagsSlice 取心情标签
func (r *Recipe) MoodTagsSlice() []string {
	return jsonToStringSlice(r.MoodTags)
}

// SetMoodTags 写心情标签
func (r *Recipe) SetMoodTags(items []string) error {
	data, err := json.Marshal(items)
	if err != nil {
		return err
	}
	r.MoodTags = JSON(data)
	return nil
}

// SceneTagsSlice 取场景标签
func (r *Recipe) SceneTagsSlice() []string {
	return jsonToStringSlice(r.SceneTags)
}

// SetSceneTags 写场景标签
func (r *Recipe) SetSceneTags(items []string) error {
	data, err := json.Marshal(items)
	if err != nil {
		return err
	}
	r.SceneTags = JSON(data)
	return nil
}

// IngredientsList 取食材结构
func (r *Recipe) IngredientsList() []map[string]any {
	return jsonToMapSlice(r.Ingredients)
}

// SetIngredients 写食材结构
func (r *Recipe) SetIngredients(items []map[string]any) error {
	data, err := json.Marshal(items)
	if err != nil {
		return err
	}
	r.Ingredients = JSON(data)
	return nil
}

// StepsList 取步骤结构
func (r *Recipe) StepsList() []map[string]any {
	return jsonToMapSlice(r.Steps)
}

// SetSteps 写步骤结构
func (r *Recipe) SetSteps(items []map[string]any) error {
	data, err := json.Marshal(items)
	if err != nil {
		return err
	}
	r.Steps = JSON(data)
	return nil
}

// IncrViewCount 浏览次数 +1
func (r *Recipe) IncrViewCount() error {
	return DB.Model(r).UpdateColumn("view_count", gorm.Expr("view_count + ?", 1)).Error
}

// MarkUsed 在一顿中被选用时调用
func (r *Recipe) MarkUsed() error {
	now := time.Now()
	return DB.Model(r).Updates(map[string]any{
		"use_count":    gorm.Expr("use_count + ?", 1),
		"last_used_at": now,
	}).Error
}

func jsonToStringSlice(j JSON) []string {
	if len(j) == 0 {
		return []string{}
	}
	var items []string
	_ = json.Unmarshal(j, &items)
	return items
}

func jsonToMapSlice(j JSON) []map[string]any {
	if len(j) == 0 {
		return []map[string]any{}
	}
	var items []map[string]any
	_ = json.Unmarshal(j, &items)
	return items
}
