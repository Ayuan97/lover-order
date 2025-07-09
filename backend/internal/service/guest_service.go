package service

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"love-order-backend/internal/model"
	"love-order-backend/pkg/jwt"
	"love-order-backend/pkg/wechat"
)

// GuestService 访客服务
type GuestService struct {
	wechatClient *wechat.WechatClient
}

// NewGuestService 创建访客服务
func NewGuestService() *GuestService {
	return &GuestService{
		wechatClient: wechat.NewWechatClient(),
	}
}

// GenerateInviteCodeRequest 生成邀请码请求
type GenerateInviteCodeRequest struct {
	InviteType   string `json:"invite_type" binding:"required"` // member, guest
	ExpiresHours int    `json:"expires_hours" binding:"min=1"`  // 过期小时数
	MaxUses      int    `json:"max_uses" binding:"min=1"`       // 最大使用次数
	Note         string `json:"note"`                           // 邀请备注
}

// GuestRegisterRequest 访客注册请求
type GuestRegisterRequest struct {
	InviteCode    string `json:"invite_code" binding:"required"`
	Code          string `json:"code" binding:"required"` // 微信授权码
	Nickname      string `json:"nickname"`
	EncryptedData string `json:"encrypted_data"`
	IV            string `json:"iv"`
}

// GuestRegisterResponse 访客注册响应
type GuestRegisterResponse struct {
	Token     string      `json:"token"`
	User      *model.User `json:"user"`
	ExpiresAt time.Time   `json:"expires_at"`
}

// GenerateInviteCode 生成邀请码
func (s *GuestService) GenerateInviteCode(req *GenerateInviteCodeRequest, adminUserID, familyID uint) (*model.FamilyInvitation, error) {
	// 验证管理员权限
	var adminUser model.User
	if err := model.DB.First(&adminUser, adminUserID).Error; err != nil {
		return nil, errors.New("管理员用户不存在")
	}

	if !adminUser.IsAdmin() {
		return nil, errors.New("权限不足")
	}

	if adminUser.FamilyID == nil || *adminUser.FamilyID != familyID {
		return nil, errors.New("用户不属于该家庭")
	}

	// 生成邀请码
	inviteCode := generateRandomCode(8)

	// 计算过期时间
	expiresAt := time.Now().Add(time.Duration(req.ExpiresHours) * time.Hour)

	// 创建邀请记录
	invitation := &model.FamilyInvitation{
		FamilyID:   familyID,
		InviteCode: inviteCode,
		InvitedBy:  adminUserID,
		InviteType: req.InviteType,
		ExpiresAt:  expiresAt,
		MaxUses:    req.MaxUses,
		UsedCount:  0,
		Note:       req.Note,
		IsActive:   true,
	}

	if err := model.DB.Create(invitation).Error; err != nil {
		return nil, fmt.Errorf("创建邀请记录失败: %v", err)
	}

	// 预加载关联数据
	model.DB.Preload("Family").Preload("InvitedByUser").First(invitation, invitation.ID)

	return invitation, nil
}

// GuestRegister 访客注册
func (s *GuestService) GuestRegister(req *GuestRegisterRequest) (*GuestRegisterResponse, error) {
	// 1. 验证邀请码
	var invitation model.FamilyInvitation
	err := model.DB.Where("invite_code = ? AND is_active = ?", req.InviteCode, true).First(&invitation).Error
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

	// 2. 通过微信code获取openid
	sessionResp, err := s.wechatClient.Code2Session(req.Code)
	if err != nil {
		return nil, fmt.Errorf("微信登录失败: %v", err)
	}

	// 3. 检查用户是否已存在
	var existingUser model.User
	err = model.DB.Where("openid = ?", sessionResp.OpenID).First(&existingUser).Error
	if err == nil {
		// 用户已存在，检查是否已在该家庭
		if existingUser.FamilyID != nil && *existingUser.FamilyID == invitation.FamilyID {
			return nil, errors.New("用户已是该家庭成员")
		}
		// 如果用户在其他家庭，需要先退出
		if existingUser.FamilyID != nil {
			return nil, errors.New("用户已加入其他家庭，请先退出")
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("查询用户失败: %v", err)
	}

	// 4. 开始事务
	tx := model.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	var user model.User
	if errors.Is(err, gorm.ErrRecordNotFound) {
		// 创建新用户
		expiresAt := time.Now().Add(24 * time.Hour) // 访客默认24小时有效期
		user = model.User{
			OpenID:         sessionResp.OpenID,
			UnionID:        sessionResp.UnionID,
			Nickname:       req.Nickname,
			Role:           "guest",
			FamilyID:       &invitation.FamilyID,
			GuestExpiresAt: &expiresAt,
			IsActive:       true,
		}

		if err := tx.Create(&user).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("创建访客用户失败: %v", err)
		}
	} else {
		// 更新现有用户为访客
		expiresAt := time.Now().Add(24 * time.Hour)
		updates := map[string]interface{}{
			"role":              "guest",
			"family_id":         invitation.FamilyID,
			"guest_expires_at":  expiresAt,
			"is_active":         true,
			"updated_at":        time.Now(),
		}

		if req.Nickname != "" {
			updates["nickname"] = req.Nickname
		}

		if err := tx.Model(&existingUser).Updates(updates).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("更新用户为访客失败: %v", err)
		}

		user = existingUser
		user.Role = "guest"
		user.FamilyID = &invitation.FamilyID
		user.GuestExpiresAt = &expiresAt
	}

	// 5. 更新邀请码使用记录
	if err := invitation.AddUsedBy(user.ID); err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("更新邀请码使用记录失败: %v", err)
	}

	// 6. 提交事务
	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("提交事务失败: %v", err)
	}

	// 7. 生成JWT token
	token, err := jwt.GenerateToken(user.ID, user.OpenID, user.Role, user.FamilyID)
	if err != nil {
		return nil, fmt.Errorf("生成token失败: %v", err)
	}

	// 8. 重新加载用户数据
	model.DB.Preload("Family").First(&user, user.ID)

	return &GuestRegisterResponse{
		Token:     token,
		User:      &user,
		ExpiresAt: *user.GuestExpiresAt,
	}, nil
}

// GetGuestInfo 获取访客信息
func (s *GuestService) GetGuestInfo(userID uint) (*model.User, error) {
	var user model.User
	err := model.DB.Preload("Family").Where("id = ? AND role = 'guest' AND is_active = ?", userID, true).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("访客用户不存在")
		}
		return nil, fmt.Errorf("查询访客用户失败: %v", err)
	}

	return &user, nil
}

// ExtendGuestPermission 延长访客权限
func (s *GuestService) ExtendGuestPermission(guestUserID, adminUserID uint, hours int) error {
	// 验证管理员权限
	var adminUser model.User
	if err := model.DB.First(&adminUser, adminUserID).Error; err != nil {
		return errors.New("管理员用户不存在")
	}

	if !adminUser.IsAdmin() {
		return errors.New("权限不足")
	}

	// 查找访客用户
	var guestUser model.User
	if err := model.DB.First(&guestUser, guestUserID).Error; err != nil {
		return errors.New("访客用户不存在")
	}

	if !guestUser.IsGuest() {
		return errors.New("用户不是访客")
	}

	// 验证是否在同一家庭
	if adminUser.FamilyID == nil || guestUser.FamilyID == nil || *adminUser.FamilyID != *guestUser.FamilyID {
		return errors.New("只能管理同一家庭的访客")
	}

	// 延长权限
	newExpiresAt := time.Now().Add(time.Duration(hours) * time.Hour)
	err := model.DB.Model(&guestUser).Updates(map[string]interface{}{
		"guest_expires_at": newExpiresAt,
		"updated_at":       time.Now(),
	}).Error

	if err != nil {
		return fmt.Errorf("延长访客权限失败: %v", err)
	}

	return nil
}

// RevokeGuestPermission 撤销访客权限
func (s *GuestService) RevokeGuestPermission(guestUserID, adminUserID uint) error {
	// 验证管理员权限
	var adminUser model.User
	if err := model.DB.First(&adminUser, adminUserID).Error; err != nil {
		return errors.New("管理员用户不存在")
	}

	if !adminUser.IsAdmin() {
		return errors.New("权限不足")
	}

	// 查找访客用户
	var guestUser model.User
	if err := model.DB.First(&guestUser, guestUserID).Error; err != nil {
		return errors.New("访客用户不存在")
	}

	if !guestUser.IsGuest() {
		return errors.New("用户不是访客")
	}

	// 验证是否在同一家庭
	if adminUser.FamilyID == nil || guestUser.FamilyID == nil || *adminUser.FamilyID != *guestUser.FamilyID {
		return errors.New("只能管理同一家庭的访客")
	}

	// 撤销权限（设置为过期）
	pastTime := time.Now().Add(-1 * time.Hour)
	err := model.DB.Model(&guestUser).Updates(map[string]interface{}{
		"guest_expires_at": pastTime,
		"is_active":        false,
		"updated_at":       time.Now(),
	}).Error

	if err != nil {
		return fmt.Errorf("撤销访客权限失败: %v", err)
	}

	return nil
}

// GetFamilyGuests 获取家庭访客列表
func (s *GuestService) GetFamilyGuests(familyID uint, includeExpired bool) ([]model.User, error) {
	var guests []model.User
	query := model.DB.Where("family_id = ? AND role = 'guest'", familyID)

	if !includeExpired {
		query = query.Where("is_active = true AND (guest_expires_at IS NULL OR guest_expires_at > ?)", time.Now())
	}

	err := query.Order("created_at DESC").Find(&guests).Error
	if err != nil {
		return nil, fmt.Errorf("查询家庭访客失败: %v", err)
	}

	return guests, nil
}

// GetInvitationList 获取邀请码列表
func (s *GuestService) GetInvitationList(familyID uint, includeInactive bool) ([]model.FamilyInvitation, error) {
	var invitations []model.FamilyInvitation
	query := model.DB.Where("family_id = ?", familyID)

	if !includeInactive {
		query = query.Where("is_active = true AND expires_at > ?", time.Now())
	}

	err := query.Preload("InvitedByUser").Order("created_at DESC").Find(&invitations).Error
	if err != nil {
		return nil, fmt.Errorf("查询邀请码列表失败: %v", err)
	}

	return invitations, nil
}

// generateRandomCode 生成随机邀请码
func generateRandomCode(length int) string {
	bytes := make([]byte, length/2)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)[:length]
}
