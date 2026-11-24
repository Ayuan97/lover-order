package service

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
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
	_ = model.DB.Preload("Members").First(household, household.ID).Error
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
		NewNotificationService().NotifyHouseholdJoined(household.ID, userID, household.Name)
		GlobalCanvasHub().BroadcastHouseholdSync(household.ID, "household_changed", userID)
		_ = model.DB.Preload("Members").First(&household, household.ID).Error
		return &household, nil
	}

	// 限次邀请：校验与 used_count 自增必须同事务且行锁，避免并发 TOCTOU 超限
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		var invite model.HouseholdInvite
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("code = ?", in.Code).First(&invite).Error; err != nil {
			return errors.New("邀请码无效")
		}
		if !invite.Usable() {
			return errors.New("邀请码已过期或失效")
		}
		if err := tx.First(&household, invite.HouseholdID).Error; err != nil {
			return err
		}
		if err := tx.Model(&user).Update("household_id", household.ID).Error; err != nil {
			return err
		}
		// 条件自增：即便锁语义异常也保证 max_uses 不被突破
		res := tx.Model(&model.HouseholdInvite{}).
			Where("id = ?", invite.ID).
			Where("max_uses = 0 OR used_count < max_uses").
			Update("used_count", gorm.Expr("used_count + ?", 1))
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return errors.New("邀请码已过期或失效")
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	NewNotificationService().NotifyHouseholdJoined(household.ID, userID, household.Name)
	GlobalCanvasHub().BroadcastHouseholdSync(household.ID, "household_changed", userID)
	_ = model.DB.Preload("Members").First(&household, household.ID).Error
	return &household, nil
}

// Leave 退出当前家 创建者退出时转移家长或解散
func (s *HouseholdService) Leave(userID uint) error {
	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return err
	}
	if user.HouseholdID == nil {
		return nil
	}
	householdID := *user.HouseholdID

	var household model.Household
	if err := model.DB.First(&household, householdID).Error; err != nil {
		return err
	}

	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&model.User{}).Where("id = ?", userID).Update("household_id", nil).Error; err != nil {
			return err
		}
		if household.CreatedBy != userID {
			return nil
		}
		// 离开的是创建者 看还有没有别人
		var others []model.User
		if err := tx.Where("household_id = ?", householdID).Order("id ASC").Find(&others).Error; err != nil {
			return err
		}
		if len(others) == 0 {
			// 只剩创建者一人 解散这个家
			return tx.Delete(&model.Household{}, householdID).Error
		}
		// 还有别人 家长转给最早加入的成员
		return tx.Model(&model.Household{}).Where("id = ?", householdID).
			Update("created_by", others[0].ID).Error
	})
	if err != nil {
		return err
	}
	GlobalCanvasHub().EvictHouseholdMember(householdID, userID)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "household_changed", userID)
	return nil
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

// LaunchCanvasInput 家庭创建者发布/更新共享开屏画布入参
type LaunchCanvasInput struct {
	Document  *CanvasDocPayload `json:"document" binding:"required"`
	Motion    string            `json:"motion"`
	HoldSpeed string            `json:"hold_speed"`
}

// LaunchCanvasResponse 家庭共享开屏动画响应
type LaunchCanvasResponse struct {
	HasCustom       bool              `json:"has_custom"`
	HouseholdID     uint              `json:"household_id"`
	CreatorID       uint              `json:"creator_id"`
	CreatorNickname string            `json:"creator_nickname"`
	CanEdit         bool              `json:"can_edit"`
	Document        *CanvasDocPayload `json:"document,omitempty"`
	Motion          string            `json:"motion"`
	HoldSpeed       string            `json:"hold_speed"`
	UpdatedAt       *time.Time        `json:"updated_at,omitempty"`
}

func normalizeLaunchMotion(raw string) string {
	switch strings.TrimSpace(raw) {
	case "fadeZoom", "curtainUp", "softReveal", "bloom":
		return strings.TrimSpace(raw)
	case "polaroidDrop":
		return "softReveal"
	default:
		return "fadeZoom"
	}
}

func normalizeLaunchHoldSpeed(raw string) string {
	switch strings.TrimSpace(raw) {
	case "brisk", "standard", "leisurely":
		return strings.TrimSpace(raw)
	default:
		return "standard"
	}
}

// GetLaunchCanvas 读取当前家庭的共享开屏画布与创建者信息
func (s *HouseholdService) GetLaunchCanvas(householdID, userID uint) (*LaunchCanvasResponse, error) {
	var h model.Household
	if err := model.DB.First(&h, householdID).Error; err != nil {
		return nil, errors.New("家不存在")
	}

	creatorName := "创建者"
	var creator model.User
	if err := model.DB.Select("id, nickname").First(&creator, h.CreatedBy).Error; err == nil {
		if n := strings.TrimSpace(creator.Nickname); n != "" {
			creatorName = n
		}
	}

	resp := &LaunchCanvasResponse{
		HasCustom:       false,
		HouseholdID:     h.ID,
		CreatorID:       h.CreatedBy,
		CreatorNickname: creatorName,
		CanEdit:         h.CreatedBy == userID,
		Motion:          "fadeZoom",
		HoldSpeed:       "standard",
	}

	var rec model.HouseholdLaunchCanvas
	err := model.DB.Where("household_id = ?", householdID).First(&rec).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return resp, nil
	}
	if err != nil {
		return nil, err
	}

	var doc CanvasDocPayload
	if len(rec.Document) > 0 {
		if err := json.Unmarshal(rec.Document, &doc); err != nil {
			return nil, err
		}
		resp.Document = normalizeCanvasDoc(&doc)
		resp.HasCustom = true
	}
	resp.Motion = normalizeLaunchMotion(rec.Motion)
	resp.HoldSpeed = normalizeLaunchHoldSpeed(rec.HoldSpeed)
	t := rec.UpdatedAt
	resp.UpdatedAt = &t
	return resp, nil
}

// SaveLaunchCanvas 仅允许家庭创建者发布/更新共享开屏动画
func (s *HouseholdService) SaveLaunchCanvas(householdID, userID uint, in LaunchCanvasInput) (*LaunchCanvasResponse, error) {
	var h model.Household
	if err := model.DB.First(&h, householdID).Error; err != nil {
		return nil, errors.New("家不存在")
	}
	if h.CreatedBy != userID {
		return nil, errors.New("只有家庭创建者可以设置共享开屏动画")
	}
	if in.Document == nil {
		return nil, errors.New("画布内容不能为空")
	}

	normalized := normalizeCanvasDoc(in.Document)
	rawBytes, err := json.Marshal(normalized)
	if err != nil {
		return nil, err
	}
	motion := normalizeLaunchMotion(in.Motion)
	holdSpeed := normalizeLaunchHoldSpeed(in.HoldSpeed)
	now := time.Now()

	rec := model.HouseholdLaunchCanvas{
		HouseholdID: householdID,
		Document:    model.JSON(rawBytes),
		Motion:      motion,
		HoldSpeed:   holdSpeed,
		UpdatedBy:   userID,
		UpdatedAt:   now,
	}
	if err := model.DB.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "household_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"document", "motion", "hold_speed", "updated_by", "updated_at"}),
	}).Create(&rec).Error; err != nil {
		return nil, err
	}

	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "launch_canvas_changed", userID)
	return s.GetLaunchCanvas(householdID, userID)
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
