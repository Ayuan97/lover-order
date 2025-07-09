package service

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"love-order-backend/internal/model"
)

// FamilyService 家庭服务
type FamilyService struct{}

// NewFamilyService 创建家庭服务
func NewFamilyService() *FamilyService {
	return &FamilyService{}
}

// CreateFamilyRequest 创建家庭请求
type CreateFamilyRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
	Avatar      string `json:"avatar"`
}

// UpdateFamilyRequest 更新家庭请求
type UpdateFamilyRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	Avatar      *string `json:"avatar"`
}

// JoinFamilyRequest 加入家庭请求
type JoinFamilyRequest struct {
	InviteCode string `json:"invite_code" binding:"required"`
}

// CreateFamily 创建家庭
func (s *FamilyService) CreateFamily(req *CreateFamilyRequest, userID uint) (*model.Family, error) {
	// 检查用户是否已加入其他家庭
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, errors.New("用户不存在")
	}

	if user.FamilyID != nil {
		return nil, errors.New("用户已加入其他家庭，请先退出")
	}

	// 开始事务
	tx := model.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 生成家庭邀请码
	inviteCode := generateFamilyInviteCode()

	// 创建家庭
	family := &model.Family{
		Name:        req.Name,
		Description: req.Description,
		Avatar:      req.Avatar,
		InviteCode:  inviteCode,
		CreatedBy:   userID,
	}

	if err := tx.Create(family).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建家庭失败: %v", err)
	}

	// 将创建者设为管理员并加入家庭
	updates := map[string]interface{}{
		"family_id":  family.ID,
		"role":       "admin",
		"updated_at": time.Now(),
	}

	if err := tx.Model(&user).Updates(updates).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("更新用户家庭信息失败: %v", err)
	}

	// 创建默认菜谱分类
	defaultCategories := []model.RecipeCategory{
		{Name: "早餐", Icon: "icon-breakfast", Color: "#FFB74D", SortOrder: 1, FamilyID: family.ID},
		{Name: "午餐", Icon: "icon-lunch", Color: "#81C784", SortOrder: 2, FamilyID: family.ID},
		{Name: "晚餐", Icon: "icon-dinner", Color: "#F06292", SortOrder: 3, FamilyID: family.ID},
		{Name: "小食", Icon: "icon-snack", Color: "#BA68C8", SortOrder: 4, FamilyID: family.ID},
		{Name: "饮品", Icon: "icon-drink", Color: "#4FC3F7", SortOrder: 5, FamilyID: family.ID},
		{Name: "汤品", Icon: "icon-soup", Color: "#FF8A65", SortOrder: 6, FamilyID: family.ID},
	}

	if err := tx.Create(&defaultCategories).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建默认分类失败: %v", err)
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("提交事务失败: %v", err)
	}

	// 重新加载家庭数据
	model.DB.Preload("Members").First(family, family.ID)

	return family, nil
}

// GetFamilyInfo 获取家庭信息
func (s *FamilyService) GetFamilyInfo(familyID uint) (*model.Family, error) {
	var family model.Family
	err := model.DB.Preload("Members", "is_active = true").First(&family, familyID).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("家庭不存在")
		}
		return nil, fmt.Errorf("查询家庭信息失败: %v", err)
	}

	return &family, nil
}

// UpdateFamily 更新家庭信息
func (s *FamilyService) UpdateFamily(familyID uint, req *UpdateFamilyRequest, userID uint) error {
	// 验证用户权限
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return errors.New("用户不存在")
	}

	if user.FamilyID == nil || *user.FamilyID != familyID {
		return errors.New("用户不属于该家庭")
	}

	if !user.IsAdmin() {
		return errors.New("需要管理员权限")
	}

	// 准备更新数据
	updates := make(map[string]interface{})

	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.Description != nil {
		updates["description"] = *req.Description
	}
	if req.Avatar != nil {
		updates["avatar"] = *req.Avatar
	}

	if len(updates) == 0 {
		return errors.New("没有可更新的字段")
	}

	updates["updated_at"] = time.Now()

	// 更新家庭信息
	if err := model.DB.Model(&model.Family{}).Where("id = ?", familyID).Updates(updates).Error; err != nil {
		return fmt.Errorf("更新家庭信息失败: %v", err)
	}

	return nil
}

// JoinFamily 加入家庭
func (s *FamilyService) JoinFamily(req *JoinFamilyRequest, userID uint) (*model.Family, error) {
	// 检查用户状态
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, errors.New("用户不存在")
	}

	if user.FamilyID != nil {
		return nil, errors.New("用户已加入其他家庭，请先退出")
	}

	// 查找邀请码
	var invitation model.FamilyInvitation
	err := model.DB.Where("invite_code = ? AND invite_type = 'member' AND is_active = ?", req.InviteCode, true).First(&invitation).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("邀请码不存在或已失效")
		}
		return nil, fmt.Errorf("查询邀请码失败: %v", err)
	}

	// 检查邀请码是否可用
	if !invitation.IsAvailable() {
		return nil, errors.New("邀请码已过期或已达到使用上限")
	}

	// 开始事务
	tx := model.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 更新用户家庭信息
	updates := map[string]interface{}{
		"family_id":  invitation.FamilyID,
		"role":       "member",
		"updated_at": time.Now(),
	}

	if err := tx.Model(&user).Updates(updates).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("更新用户家庭信息失败: %v", err)
	}

	// 更新邀请码使用记录
	if err := invitation.AddUsedBy(userID); err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("更新邀请码使用记录失败: %v", err)
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("提交事务失败: %v", err)
	}

	// 获取家庭信息
	var family model.Family
	model.DB.Preload("Members", "is_active = true").First(&family, invitation.FamilyID)

	return &family, nil
}

// LeaveFamily 退出家庭
func (s *FamilyService) LeaveFamily(userID uint) error {
	// 查找用户
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return errors.New("用户不存在")
	}

	if user.FamilyID == nil {
		return errors.New("用户未加入任何家庭")
	}

	// 检查是否为家庭创建者
	var family model.Family
	if err := model.DB.First(&family, *user.FamilyID).Error; err != nil {
		return errors.New("家庭不存在")
	}

	if family.CreatedBy == userID {
		// 检查是否还有其他成员
		var memberCount int64
		model.DB.Model(&model.User{}).Where("family_id = ? AND id != ? AND is_active = true", *user.FamilyID, userID).Count(&memberCount)

		if memberCount > 0 {
			return errors.New("作为家庭创建者，请先转让管理员权限或删除家庭")
		}

		// 如果没有其他成员，可以直接删除家庭
		return s.DeleteFamily(*user.FamilyID, userID)
	}

	// 更新用户信息
	updates := map[string]interface{}{
		"family_id":         nil,
		"role":              "member",
		"guest_expires_at":  nil,
		"updated_at":        time.Now(),
	}

	if err := model.DB.Model(&user).Updates(updates).Error; err != nil {
		return fmt.Errorf("退出家庭失败: %v", err)
	}

	return nil
}

// DeleteFamily 删除家庭
func (s *FamilyService) DeleteFamily(familyID, userID uint) error {
	// 验证权限
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return errors.New("用户不存在")
	}

	var family model.Family
	if err := model.DB.First(&family, familyID).Error; err != nil {
		return errors.New("家庭不存在")
	}

	if family.CreatedBy != userID {
		return errors.New("只有家庭创建者可以删除家庭")
	}

	// 开始事务
	tx := model.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 更新所有家庭成员
	if err := tx.Model(&model.User{}).Where("family_id = ?", familyID).Updates(map[string]interface{}{
		"family_id":         nil,
		"role":              "member",
		"guest_expires_at":  nil,
		"updated_at":        time.Now(),
	}).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("更新家庭成员失败: %v", err)
	}

	// 软删除家庭（GORM会自动处理关联数据）
	if err := tx.Delete(&family).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("删除家庭失败: %v", err)
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("提交事务失败: %v", err)
	}

	return nil
}

// GetFamilyStats 获取家庭统计信息
func (s *FamilyService) GetFamilyStats(familyID uint) (map[string]interface{}, error) {
	// 成员统计
	var memberCount, guestCount int64
	model.DB.Model(&model.User{}).Where("family_id = ? AND role != 'guest' AND is_active = true", familyID).Count(&memberCount)
	model.DB.Model(&model.User{}).Where("family_id = ? AND role = 'guest' AND is_active = true AND (guest_expires_at IS NULL OR guest_expires_at > ?)", familyID, time.Now()).Count(&guestCount)

	// 菜谱统计
	var recipeCount int64
	model.DB.Model(&model.Recipe{}).Where("family_id = ?", familyID).Count(&recipeCount)

	// 订单统计
	var orderCount int64
	var totalAmount float64
	model.DB.Model(&model.Order{}).Where("family_id = ?", familyID).Count(&orderCount)
	model.DB.Model(&model.Order{}).Where("family_id = ?", familyID).Select("COALESCE(SUM(total_amount), 0)").Scan(&totalAmount)

	// 本月订单
	thisMonth := time.Now().Format("2006-01")
	var monthlyOrders int64
	model.DB.Model(&model.Order{}).Where("family_id = ? AND DATE_FORMAT(created_at, '%Y-%m') = ?", familyID, thisMonth).Count(&monthlyOrders)

	return map[string]interface{}{
		"member_count":    memberCount,
		"guest_count":     guestCount,
		"recipe_count":    recipeCount,
		"order_count":     orderCount,
		"total_amount":    totalAmount,
		"monthly_orders":  monthlyOrders,
	}, nil
}

// generateFamilyInviteCode 生成家庭邀请码
func generateFamilyInviteCode() string {
	bytes := make([]byte, 6)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)[:10]
}
