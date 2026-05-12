package service

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
)

// HouseholdService 一个家的业务
type HouseholdService struct{}

// NewHouseholdService 构造
func NewHouseholdService() *HouseholdService {
	return &HouseholdService{}
}

// CreateInput 创建一个家入参
type CreateInput struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Create 当前用户创建一个家并自动加入
func (s *HouseholdService) Create(userID uint, in CreateInput) (*model.Household, error) {
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, err
	}
	if user.HouseholdID != nil {
		return nil, errors.New("当前用户已加入一个家")
	}

	name := in.Name
	if name == "" {
		name = "我们家"
	}

	code, err := uniqueInviteCode()
	if err != nil {
		return nil, err
	}

	household := &model.Household{
		Name:        name,
		InviteCode:  code,
		Description: in.Description,
		CreatedBy:   userID,
	}

	err = model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(household).Error; err != nil {
			return fmt.Errorf("创建家失败：%w", err)
		}
		if err := tx.Model(&model.User{}).Where("id = ?", userID).
			Update("household_id", household.ID).Error; err != nil {
			return fmt.Errorf("绑定家失败：%w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return household, nil
}

// Get 取一个家详情 含成员
func (s *HouseholdService) Get(householdID uint) (*model.Household, error) {
	var h model.Household
	if err := model.DB.Preload("Members").First(&h, householdID).Error; err != nil {
		return nil, err
	}
	return &h, nil
}

// JoinInput 加入入参
type JoinInput struct {
	Code string `json:"code" binding:"required"`
}

// Join 通过邀请码加入一个家
func (s *HouseholdService) Join(userID uint, in JoinInput) (*model.Household, error) {
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, err
	}
	if user.HouseholdID != nil {
		return nil, errors.New("你已加入一个家 请先退出")
	}

	var household model.Household
	if err := model.DB.Where("invite_code = ?", in.Code).First(&household).Error; err == nil {
		if err := model.DB.Model(&user).Update("household_id", household.ID).Error; err != nil {
			return nil, err
		}
		return &household, nil
	}

	var invite model.HouseholdInvite
	if err := model.DB.Where("code = ?", in.Code).First(&invite).Error; err != nil {
		return nil, errors.New("邀请码无效")
	}
	if !invite.Usable() {
		return nil, errors.New("邀请码已过期或失效")
	}

	if err := model.DB.First(&household, invite.HouseholdID).Error; err != nil {
		return nil, err
	}
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&user).Update("household_id", household.ID).Error; err != nil {
			return err
		}
		return tx.Model(&invite).Update("used_count", gorm.Expr("used_count + ?", 1)).Error
	})
	if err != nil {
		return nil, err
	}
	return &household, nil
}

// Leave 退出当前家
func (s *HouseholdService) Leave(userID uint) error {
	return model.DB.Model(&model.User{}).Where("id = ?", userID).Update("household_id", nil).Error
}

// InviteInput 生成邀请入参
type InviteInput struct {
	ExpiresIn int `json:"expires_in"`
	MaxUses   int `json:"max_uses"`
}

// CreateInvite 生成临时邀请记录 不暴露家本身的固定邀请码
func (s *HouseholdService) CreateInvite(userID, householdID uint, in InviteInput) (*model.HouseholdInvite, error) {
	code, err := uniqueInviteCode()
	if err != nil {
		return nil, err
	}
	invite := &model.HouseholdInvite{
		HouseholdID: householdID,
		Code:        code,
		CreatedBy:   userID,
		MaxUses:     in.MaxUses,
		IsActive:    true,
	}
	if in.ExpiresIn > 0 {
		exp := time.Now().Add(time.Duration(in.ExpiresIn) * time.Second)
		invite.ExpiresAt = &exp
	}
	if err := model.DB.Create(invite).Error; err != nil {
		return nil, err
	}
	return invite, nil
}

// ListInvites 列出一个家的邀请记录
func (s *HouseholdService) ListInvites(householdID uint) ([]model.HouseholdInvite, error) {
	var items []model.HouseholdInvite
	if err := model.DB.Where("household_id = ?", householdID).
		Order("created_at DESC").Find(&items).Error; err != nil {
		return nil, err
	}
	return items, nil
}

func uniqueInviteCode() (string, error) {
	for i := 0; i < 8; i++ {
		code, err := GenInviteCode(8)
		if err != nil {
			return "", err
		}
		var count int64
		if err := model.DB.Model(&model.Household{}).Where("invite_code = ?", code).Count(&count).Error; err != nil {
			return "", err
		}
		var inviteCount int64
		if err := model.DB.Model(&model.HouseholdInvite{}).Where("code = ?", code).Count(&inviteCount).Error; err != nil {
			return "", err
		}
		if count == 0 && inviteCount == 0 {
			return code, nil
		}
	}
	return "", errors.New("生成邀请码失败 请重试")
}
