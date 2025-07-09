package model

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// JSON 自定义JSON类型
type JSON []byte

// Value 实现driver.Valuer接口
func (j JSON) Value() (driver.Value, error) {
	if len(j) == 0 {
		return nil, nil
	}
	return string(j), nil
}

// Scan 实现sql.Scanner接口
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

// RecipeCategory 菜谱分类模型
type RecipeCategory struct {
	ID        uint           `json:"id" gorm:"primaryKey"`
	Name      string         `json:"name" gorm:"size:50;not null;comment:分类名称"`
	Icon      string         `json:"icon" gorm:"size:200;comment:分类图标URL"`
	Color     string         `json:"color" gorm:"size:20;default:'#FF8A65';comment:分类颜色"`
	SortOrder int            `json:"sort_order" gorm:"default:0;comment:排序权重"`
	FamilyID  uint           `json:"family_id" gorm:"not null;index;comment:家庭ID"`
	IsActive  bool           `json:"is_active" gorm:"default:true;comment:是否启用"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系
	Family  Family   `json:"family,omitempty" gorm:"foreignKey:FamilyID"`
	Recipes []Recipe `json:"recipes,omitempty" gorm:"foreignKey:CategoryID"`
}

// TableName 指定表名
func (RecipeCategory) TableName() string {
	return "recipe_categories"
}

// Recipe 菜谱模型
type Recipe struct {
	ID            uint           `json:"id" gorm:"primaryKey"`
	Name          string         `json:"name" gorm:"size:100;not null;comment:菜品名称"`
	Description   string         `json:"description" gorm:"type:text;comment:菜品描述"`
	Image         string         `json:"image" gorm:"size:500;comment:菜品主图"`
	Images        JSON           `json:"images" gorm:"type:json;comment:菜品图片集合"`
	Price         float64        `json:"price" gorm:"type:decimal(10,2);default:0;comment:虚拟价格"`
	CategoryID    *uint          `json:"category_id" gorm:"index;comment:分类ID"`
	CookingTime   int            `json:"cooking_time" gorm:"comment:制作时间（分钟）"`
	Difficulty    string         `json:"difficulty" gorm:"type:enum('easy','medium','hard');default:'easy';comment:制作难度"`
	Servings      int            `json:"servings" gorm:"default:1;comment:份量（几人份）"`
	Ingredients   JSON           `json:"ingredients" gorm:"type:json;comment:食材清单"`
	Steps         JSON           `json:"steps" gorm:"type:json;comment:制作步骤"`
	NutritionInfo JSON           `json:"nutrition_info" gorm:"type:json;comment:营养信息"`
	Tags          string         `json:"tags" gorm:"size:500;comment:标签（逗号分隔）"`
	FamilyID      uint           `json:"family_id" gorm:"not null;index;comment:家庭ID"`
	CreatedBy     uint           `json:"created_by" gorm:"not null;index;comment:创建者ID"`
	IsAvailable   bool           `json:"is_available" gorm:"default:true;index;comment:是否可点餐"`
	IsFeatured    bool           `json:"is_featured" gorm:"default:false;index;comment:是否推荐"`
	ViewCount     int            `json:"view_count" gorm:"default:0;comment:浏览次数"`
	LikeCount     int            `json:"like_count" gorm:"default:0;comment:点赞数"`
	OrderCount    int            `json:"order_count" gorm:"default:0;comment:被点餐次数"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系
	Family     Family          `json:"family,omitempty" gorm:"foreignKey:FamilyID"`
	Category   *RecipeCategory `json:"category,omitempty" gorm:"foreignKey:CategoryID"`
	Creator    User            `json:"creator,omitempty" gorm:"foreignKey:CreatedBy"`
	OrderItems []OrderItem     `json:"order_items,omitempty" gorm:"foreignKey:RecipeID"`
	Favorites  []Favorite      `json:"favorites,omitempty" gorm:"foreignKey:RecipeID"`
	Reviews    []RecipeReview  `json:"reviews,omitempty" gorm:"foreignKey:RecipeID"`
}

// TableName 指定表名
func (Recipe) TableName() string {
	return "recipes"
}

// GetImagesSlice 获取图片数组
func (r *Recipe) GetImagesSlice() []string {
	if len(r.Images) == 0 {
		return []string{}
	}
	var images []string
	json.Unmarshal(r.Images, &images)
	return images
}

// SetImagesSlice 设置图片数组
func (r *Recipe) SetImagesSlice(images []string) error {
	data, err := json.Marshal(images)
	if err != nil {
		return err
	}
	r.Images = JSON(data)
	return nil
}

// GetIngredientsSlice 获取食材数组
func (r *Recipe) GetIngredientsSlice() []map[string]interface{} {
	if len(r.Ingredients) == 0 {
		return []map[string]interface{}{}
	}
	var ingredients []map[string]interface{}
	json.Unmarshal(r.Ingredients, &ingredients)
	return ingredients
}

// SetIngredientsSlice 设置食材数组
func (r *Recipe) SetIngredientsSlice(ingredients []map[string]interface{}) error {
	data, err := json.Marshal(ingredients)
	if err != nil {
		return err
	}
	r.Ingredients = JSON(data)
	return nil
}

// GetStepsSlice 获取步骤数组
func (r *Recipe) GetStepsSlice() []map[string]interface{} {
	if len(r.Steps) == 0 {
		return []map[string]interface{}{}
	}
	var steps []map[string]interface{}
	json.Unmarshal(r.Steps, &steps)
	return steps
}

// SetStepsSlice 设置步骤数组
func (r *Recipe) SetStepsSlice(steps []map[string]interface{}) error {
	data, err := json.Marshal(steps)
	if err != nil {
		return err
	}
	r.Steps = JSON(data)
	return nil
}

// IncrementViewCount 增加浏览次数
func (r *Recipe) IncrementViewCount() error {
	return DB.Model(r).UpdateColumn("view_count", gorm.Expr("view_count + ?", 1)).Error
}

// IncrementOrderCount 增加点餐次数
func (r *Recipe) IncrementOrderCount() error {
	return DB.Model(r).UpdateColumn("order_count", gorm.Expr("order_count + ?", 1)).Error
}

// GetAverageRating 获取平均评分
func (r *Recipe) GetAverageRating() float64 {
	var result struct {
		AvgRating float64
	}
	DB.Model(&RecipeReview{}).Select("AVG(rating) as avg_rating").Where("recipe_id = ?", r.ID).Scan(&result)
	return result.AvgRating
}

// GetReviewCount 获取评价数量
func (r *Recipe) GetReviewCount() int64 {
	var count int64
	DB.Model(&RecipeReview{}).Where("recipe_id = ?", r.ID).Count(&count)
	return count
}
