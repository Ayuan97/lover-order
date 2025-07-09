package model

import (
	"fmt"
	"time"

	"gorm.io/gorm"
)

// Order 订单模型
type Order struct {
	ID             uint           `json:"id" gorm:"primaryKey"`
	OrderNo        string         `json:"order_no" gorm:"uniqueIndex;size:32;not null;comment:订单号"`
	UserID         uint           `json:"user_id" gorm:"not null;index;comment:下单用户ID"`
	FamilyID       uint           `json:"family_id" gorm:"not null;index;comment:家庭ID"`
	TotalAmount    float64        `json:"total_amount" gorm:"type:decimal(10,2);default:0;comment:订单总金额"`
	ItemCount      int            `json:"item_count" gorm:"default:0;comment:菜品总数量"`
	Status         string         `json:"status" gorm:"type:enum('pending','confirmed','cooking','completed','cancelled');default:'pending';index;comment:订单状态"`
	MealTime       *time.Time     `json:"meal_time" gorm:"index;comment:期望用餐时间"`
	ActualMealTime *time.Time     `json:"actual_meal_time" gorm:"comment:实际用餐时间"`
	Note           string         `json:"note" gorm:"type:text;comment:订单备注"`
	IsGuestOrder   bool           `json:"is_guest_order" gorm:"default:false;comment:是否访客订单"`
	ConfirmedBy    *uint          `json:"confirmed_by" gorm:"comment:确认人ID"`
	ConfirmedAt    *time.Time     `json:"confirmed_at" gorm:"comment:确认时间"`
	CompletedAt    *time.Time     `json:"completed_at" gorm:"comment:完成时间"`
	CancelledAt    *time.Time     `json:"cancelled_at" gorm:"comment:取消时间"`
	CancelReason   string         `json:"cancel_reason" gorm:"size:200;comment:取消原因"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联关系
	User            User        `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Family          Family      `json:"family,omitempty" gorm:"foreignKey:FamilyID"`
	ConfirmedByUser *User       `json:"confirmed_by_user,omitempty" gorm:"foreignKey:ConfirmedBy"`
	Items           []OrderItem `json:"items,omitempty" gorm:"foreignKey:OrderID"`
}

// TableName 指定表名
func (Order) TableName() string {
	return "orders"
}

// OrderItem 订单详情模型
type OrderItem struct {
	ID                uint      `json:"id" gorm:"primaryKey"`
	OrderID           uint      `json:"order_id" gorm:"not null;index;comment:订单ID"`
	RecipeID          uint      `json:"recipe_id" gorm:"not null;index;comment:菜谱ID"`
	RecipeName        string    `json:"recipe_name" gorm:"size:100;not null;comment:菜品名称快照"`
	RecipeImage       string    `json:"recipe_image" gorm:"size:500;comment:菜品图片快照"`
	RecipeDescription string    `json:"recipe_description" gorm:"type:text;comment:菜品描述快照"`
	Quantity          int       `json:"quantity" gorm:"not null;default:1;comment:数量"`
	UnitPrice         float64   `json:"unit_price" gorm:"type:decimal(10,2);not null;comment:单价"`
	TotalPrice        float64   `json:"total_price" gorm:"type:decimal(10,2);not null;comment:小计"`
	Note              string    `json:"note" gorm:"size:200;comment:单品备注"`
	CreatedAt         time.Time `json:"created_at"`

	// 关联关系
	Order  Order  `json:"order,omitempty" gorm:"foreignKey:OrderID"`
	Recipe Recipe `json:"recipe,omitempty" gorm:"foreignKey:RecipeID"`
}

// TableName 指定表名
func (OrderItem) TableName() string {
	return "order_items"
}

// GenerateOrderNo 生成订单号
func GenerateOrderNo() string {
	return "LO" + time.Now().Format("20060102150405") + "001"
}

// CanCancel 判断订单是否可以取消
func (o *Order) CanCancel() bool {
	return o.Status == "pending" || o.Status == "confirmed"
}

// CanConfirm 判断订单是否可以确认
func (o *Order) CanConfirm() bool {
	return o.Status == "pending"
}

// CanComplete 判断订单是否可以完成
func (o *Order) CanComplete() bool {
	return o.Status == "cooking"
}

// UpdateStatus 更新订单状态
func (o *Order) UpdateStatus(status string, userID uint) error {
	now := time.Now()
	updates := map[string]interface{}{
		"status":     status,
		"updated_at": now,
	}

	switch status {
	case "confirmed":
		if !o.CanConfirm() {
			return fmt.Errorf("订单状态不允许确认")
		}
		updates["confirmed_by"] = userID
		updates["confirmed_at"] = now
	case "completed":
		if !o.CanComplete() {
			return fmt.Errorf("订单状态不允许完成")
		}
		updates["completed_at"] = now
		updates["actual_meal_time"] = now
	case "cancelled":
		if !o.CanCancel() {
			return fmt.Errorf("订单状态不允许取消")
		}
		updates["cancelled_at"] = now
	}

	return DB.Model(o).Updates(updates).Error
}

// CalculateTotalAmount 计算订单总金额
func (o *Order) CalculateTotalAmount() error {
	var total float64
	var count int

	for _, item := range o.Items {
		total += item.TotalPrice
		count += item.Quantity
	}

	return DB.Model(o).Updates(map[string]interface{}{
		"total_amount": total,
		"item_count":   count,
	}).Error
}
