package service

import (
	"errors"
	"fmt"
	"time"

	"love-order-backend/internal/model"

	"gorm.io/gorm"
)

// OrderService 订单服务
type OrderService struct{}

// NewOrderService 创建订单服务
func NewOrderService() *OrderService {
	return &OrderService{}
}

// CreateOrderRequest 创建订单请求
type CreateOrderRequest struct {
	Items    []OrderItemRequest `json:"items" binding:"required,min=1"`
	MealTime *time.Time         `json:"meal_time"`
	Note     string             `json:"note"`
}

// OrderItemRequest 订单项请求
type OrderItemRequest struct {
	RecipeID uint   `json:"recipe_id" binding:"required"`
	Quantity int    `json:"quantity" binding:"required,min=1"`
	Note     string `json:"note"`
}

// OrderListRequest 订单列表请求
type OrderListRequest struct {
	Page      int       `form:"page" binding:"min=1"`
	Size      int       `form:"size" binding:"min=1,max=100"`
	Status    string    `form:"status"`
	StartDate time.Time `form:"start_date"`
	EndDate   time.Time `form:"end_date"`
	UserID    *uint     `form:"user_id"`
	SortBy    string    `form:"sort_by"`    // created_at, meal_time, total_amount
	SortOrder string    `form:"sort_order"` // asc, desc
}

// OrderListResponse 订单列表响应
type OrderListResponse struct {
	List  []model.Order `json:"list"`
	Total int64         `json:"total"`
	Page  int           `json:"page"`
	Size  int           `json:"size"`
}

// CreateOrder 创建订单
func (s *OrderService) CreateOrder(req *CreateOrderRequest, userID, familyID uint) (*model.Order, error) {
	// 开始事务
	tx := model.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 验证菜谱并计算总价
	var totalAmount float64
	var totalCount int
	var orderItems []model.OrderItem

	for _, item := range req.Items {
		// 查找菜谱
		var recipe model.Recipe
		if err := tx.Where("id = ? AND family_id = ? AND is_available = ?", item.RecipeID, familyID, true).First(&recipe).Error; err != nil {
			tx.Rollback()
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, fmt.Errorf("菜谱ID %d 不存在或不可用", item.RecipeID)
			}
			return nil, fmt.Errorf("查询菜谱失败: %v", err)
		}

		// 计算小计
		unitPrice := recipe.Price
		itemTotal := unitPrice * float64(item.Quantity)
		totalAmount += itemTotal
		totalCount += item.Quantity

		// 创建订单项
		orderItem := model.OrderItem{
			RecipeID:          recipe.ID,
			RecipeName:        recipe.Name,
			RecipeImage:       recipe.Image,
			RecipeDescription: recipe.Description,
			Quantity:          item.Quantity,
			UnitPrice:         unitPrice,
			TotalPrice:        itemTotal,
			Note:              item.Note,
		}
		orderItems = append(orderItems, orderItem)
	}

	// 生成订单号
	orderNo := generateOrderNo(userID)

	// 创建订单
	order := &model.Order{
		OrderNo:      orderNo,
		UserID:       userID,
		FamilyID:     familyID,
		TotalAmount:  totalAmount,
		ItemCount:    totalCount,
		Status:       "pending",
		MealTime:     req.MealTime,
		Note:         req.Note,
		IsGuestOrder: false, // 这里可以根据用户角色判断
	}

	// 检查是否为访客订单
	var user model.User
	if err := tx.First(&user, userID).Error; err == nil {
		order.IsGuestOrder = user.IsGuest()
	}

	if err := tx.Create(order).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建订单失败: %v", err)
	}

	// 创建订单项
	for i := range orderItems {
		orderItems[i].OrderID = order.ID
	}

	if err := tx.Create(&orderItems).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建订单项失败: %v", err)
	}

	// 更新菜谱点餐次数
	for _, item := range req.Items {
		tx.Model(&model.Recipe{}).Where("id = ?", item.RecipeID).
			UpdateColumn("order_count", gorm.Expr("order_count + ?", item.Quantity))
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("提交事务失败: %v", err)
	}

	// 重新加载订单数据
	model.DB.Preload("User").Preload("Items.Recipe").First(order, order.ID)

	return order, nil
}

// GetOrderList 获取订单列表
func (s *OrderService) GetOrderList(req *OrderListRequest, userID, familyID uint, isAdmin bool) (*OrderListResponse, error) {
	// 设置默认值
	if req.Page == 0 {
		req.Page = 1
	}
	if req.Size == 0 {
		req.Size = 20
	}

	query := model.DB.Where("family_id = ?", familyID)

	// 非管理员只能查看自己的订单
	if !isAdmin {
		query = query.Where("user_id = ?", userID)
	} else if req.UserID != nil {
		// 管理员可以查看指定用户的订单
		query = query.Where("user_id = ?", *req.UserID)
	}

	// 状态过滤
	if req.Status != "" {
		validStatuses := map[string]bool{
			"pending":   true,
			"confirmed": true,
			"cooking":   true,
			"completed": true,
			"cancelled": true,
		}
		if validStatuses[req.Status] {
			query = query.Where("status = ?", req.Status)
		}
	}

	// 时间范围过滤
	if !req.StartDate.IsZero() {
		query = query.Where("created_at >= ?", req.StartDate)
	}
	if !req.EndDate.IsZero() {
		query = query.Where("created_at <= ?", req.EndDate)
	}

	// 排序
	orderBy := "created_at DESC"
	if req.SortBy != "" {
		validSortFields := map[string]bool{
			"created_at":   true,
			"meal_time":    true,
			"total_amount": true,
		}

		if validSortFields[req.SortBy] {
			sortOrder := "DESC"
			if req.SortOrder == "asc" {
				sortOrder = "ASC"
			}
			orderBy = req.SortBy + " " + sortOrder
		}
	}

	// 获取总数
	var total int64
	if err := query.Model(&model.Order{}).Count(&total).Error; err != nil {
		return nil, fmt.Errorf("查询订单总数失败: %v", err)
	}

	// 获取列表
	var orders []model.Order
	offset := (req.Page - 1) * req.Size
	err := query.Preload("User").Preload("Items.Recipe").
		Order(orderBy).
		Offset(offset).
		Limit(req.Size).
		Find(&orders).Error

	if err != nil {
		return nil, fmt.Errorf("查询订单列表失败: %v", err)
	}

	return &OrderListResponse{
		List:  orders,
		Total: total,
		Page:  req.Page,
		Size:  req.Size,
	}, nil
}

// GetOrderByID 根据ID获取订单详情
func (s *OrderService) GetOrderByID(orderID, userID, familyID uint, isAdmin bool) (*model.Order, error) {
	var order model.Order
	query := model.DB.Where("id = ? AND family_id = ?", orderID, familyID)

	// 非管理员只能查看自己的订单
	if !isAdmin {
		query = query.Where("user_id = ?", userID)
	}

	err := query.Preload("User").Preload("Items.Recipe").Preload("ConfirmedByUser").First(&order).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("订单不存在")
		}
		return nil, fmt.Errorf("查询订单失败: %v", err)
	}

	return &order, nil
}

// UpdateOrderStatus 更新订单状态
func (s *OrderService) UpdateOrderStatus(orderID uint, status string, userID, familyID uint, isAdmin bool) error {
	// 查找订单
	var order model.Order
	query := model.DB.Where("id = ? AND family_id = ?", orderID, familyID)

	// 非管理员只能操作自己的订单，且只能取消
	if !isAdmin {
		query = query.Where("user_id = ?", userID)
		if status != "cancelled" {
			return errors.New("权限不足")
		}
	}

	if err := query.First(&order).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("订单不存在")
		}
		return fmt.Errorf("查询订单失败: %v", err)
	}

	// 更新状态
	if err := order.UpdateStatus(status, userID); err != nil {
		return err
	}

	return nil
}

// CancelOrder 取消订单
func (s *OrderService) CancelOrder(orderID uint, reason string, userID, familyID uint, isAdmin bool) error {
	// 查找订单
	var order model.Order
	query := model.DB.Where("id = ? AND family_id = ?", orderID, familyID)

	// 非管理员只能取消自己的订单
	if !isAdmin {
		query = query.Where("user_id = ?", userID)
	}

	if err := query.First(&order).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("订单不存在")
		}
		return fmt.Errorf("查询订单失败: %v", err)
	}

	// 检查是否可以取消
	if !order.CanCancel() {
		return errors.New("订单状态不允许取消")
	}

	// 更新订单状态
	now := time.Now()
	updates := map[string]interface{}{
		"status":        "cancelled",
		"cancelled_at":  now,
		"cancel_reason": reason,
		"updated_at":    now,
	}

	if err := model.DB.Model(&order).Updates(updates).Error; err != nil {
		return fmt.Errorf("取消订单失败: %v", err)
	}

	return nil
}

// GetOrderStats 获取订单统计
func (s *OrderService) GetOrderStats(familyID uint, userID *uint, days int) (map[string]interface{}, error) {
	if days == 0 {
		days = 30 // 默认30天
	}

	startDate := time.Now().AddDate(0, 0, -days)
	query := model.DB.Where("family_id = ? AND created_at >= ?", familyID, startDate)

	if userID != nil {
		query = query.Where("user_id = ?", *userID)
	}

	// 总订单数
	var totalOrders int64
	query.Model(&model.Order{}).Count(&totalOrders)

	// 各状态订单数
	var statusStats []struct {
		Status string `json:"status"`
		Count  int64  `json:"count"`
	}
	model.DB.Model(&model.Order{}).
		Select("status, COUNT(*) as count").
		Where("family_id = ? AND created_at >= ?", familyID, startDate).
		Group("status").
		Scan(&statusStats)

	// 总金额
	var totalAmount float64
	query.Model(&model.Order{}).
		Select("COALESCE(SUM(total_amount), 0)").
		Scan(&totalAmount)

	// 平均订单金额
	var avgAmount float64
	if totalOrders > 0 {
		avgAmount = totalAmount / float64(totalOrders)
	}

	// 最受欢迎的菜品
	var popularRecipes []struct {
		RecipeID   uint   `json:"recipe_id"`
		RecipeName string `json:"recipe_name"`
		OrderCount int64  `json:"order_count"`
	}
	model.DB.Table("order_items oi").
		Select("oi.recipe_id, oi.recipe_name, SUM(oi.quantity) as order_count").
		Joins("INNER JOIN orders o ON oi.order_id = o.id").
		Where("o.family_id = ? AND o.created_at >= ?", familyID, startDate).
		Group("oi.recipe_id, oi.recipe_name").
		Order("order_count DESC").
		Limit(10).
		Scan(&popularRecipes)

	// 每日订单趋势
	var dailyTrend []struct {
		Date  string `json:"date"`
		Count int64  `json:"count"`
	}
	model.DB.Model(&model.Order{}).
		Select("DATE(created_at) as date, COUNT(*) as count").
		Where("family_id = ? AND created_at >= ?", familyID, startDate).
		Group("DATE(created_at)").
		Order("date ASC").
		Scan(&dailyTrend)

	return map[string]interface{}{
		"total_orders":    totalOrders,
		"total_amount":    totalAmount,
		"average_amount":  avgAmount,
		"status_stats":    statusStats,
		"popular_recipes": popularRecipes,
		"daily_trend":     dailyTrend,
		"period_days":     days,
	}, nil
}

// GetUserOrderSummary 获取用户订单汇总
func (s *OrderService) GetUserOrderSummary(userID, familyID uint) (map[string]interface{}, error) {
	// 总订单数
	var totalOrders int64
	model.DB.Model(&model.Order{}).
		Where("user_id = ? AND family_id = ?", userID, familyID).
		Count(&totalOrders)

	// 本月订单数
	thisMonth := time.Now().Format("2006-01")
	var monthlyOrders int64
	model.DB.Model(&model.Order{}).
		Where("user_id = ? AND family_id = ? AND DATE_FORMAT(created_at, '%Y-%m') = ?", userID, familyID, thisMonth).
		Count(&monthlyOrders)

	// 收藏菜谱数
	var favoriteCount int64
	model.DB.Model(&model.Favorite{}).
		Where("user_id = ?", userID).
		Count(&favoriteCount)

	// 最近订单
	var recentOrders []model.Order
	model.DB.Where("user_id = ? AND family_id = ?", userID, familyID).
		Preload("Items.Recipe").
		Order("created_at DESC").
		Limit(5).
		Find(&recentOrders)

	// 最常点的菜品
	var favoriteRecipes []struct {
		RecipeID   uint   `json:"recipe_id"`
		RecipeName string `json:"recipe_name"`
		OrderCount int64  `json:"order_count"`
	}
	model.DB.Table("order_items oi").
		Select("oi.recipe_id, oi.recipe_name, SUM(oi.quantity) as order_count").
		Joins("INNER JOIN orders o ON oi.order_id = o.id").
		Where("o.user_id = ? AND o.family_id = ?", userID, familyID).
		Group("oi.recipe_id, oi.recipe_name").
		Order("order_count DESC").
		Limit(5).
		Scan(&favoriteRecipes)

	return map[string]interface{}{
		"total_orders":     totalOrders,
		"monthly_orders":   monthlyOrders,
		"favorite_count":   favoriteCount,
		"recent_orders":    recentOrders,
		"favorite_recipes": favoriteRecipes,
	}, nil
}

// RepeatOrder 重复下单
func (s *OrderService) RepeatOrder(originalOrderID, userID, familyID uint) (*model.Order, error) {
	// 查找原订单
	var originalOrder model.Order
	if err := model.DB.Preload("Items").Where("id = ? AND user_id = ? AND family_id = ?", originalOrderID, userID, familyID).First(&originalOrder).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("原订单不存在")
		}
		return nil, fmt.Errorf("查询原订单失败: %v", err)
	}

	// 构建新订单请求
	var items []OrderItemRequest
	for _, item := range originalOrder.Items {
		// 检查菜谱是否仍然可用
		var recipe model.Recipe
		if err := model.DB.Where("id = ? AND is_available = ?", item.RecipeID, true).First(&recipe).Error; err != nil {
			continue // 跳过不可用的菜谱
		}

		items = append(items, OrderItemRequest{
			RecipeID: item.RecipeID,
			Quantity: item.Quantity,
			Note:     item.Note,
		})
	}

	if len(items) == 0 {
		return nil, errors.New("原订单中的菜品都不可用")
	}

	// 创建新订单
	req := &CreateOrderRequest{
		Items: items,
		Note:  "重复订单：" + originalOrder.OrderNo,
	}

	return s.CreateOrder(req, userID, familyID)
}

// generateOrderNo 生成订单号
func generateOrderNo(userID uint) string {
	timestamp := time.Now().Format("20060102150405")
	userStr := fmt.Sprintf("%04d", userID%10000)
	return "LO" + timestamp + userStr
}
