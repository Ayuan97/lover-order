package service

import (
	"errors"
	"fmt"
	"time"

	"love-order-backend/internal/model"
	"love-order-backend/pkg/jwt"
	"love-order-backend/pkg/wechat"

	"gorm.io/gorm"
)

// UserService 用户服务
type UserService struct {
	wechatClient *wechat.WechatClient
}

// NewUserService 创建用户服务
func NewUserService() *UserService {
	return &UserService{
		wechatClient: wechat.NewWechatClient(),
	}
}

// WechatUserInfo 微信用户信息
type WechatUserInfo struct {
	Nickname  string `json:"nickname"`
	AvatarURL string `json:"avatar_url"`
	Gender    int    `json:"gender"`
	City      string `json:"city"`
	Province  string `json:"province"`
	Country   string `json:"country"`
}

// WechatLoginRequest 微信登录请求
type WechatLoginRequest struct {
	Code          string          `json:"code" binding:"required"`
	UserInfo      *WechatUserInfo `json:"user_info"`
	EncryptedData string          `json:"encrypted_data"`
	IV            string          `json:"iv"`
	Signature     string          `json:"signature"`
	RawData       string          `json:"raw_data"`
}

// WechatLoginResponse 微信登录响应
type WechatLoginResponse struct {
	Token string      `json:"token"`
	User  *model.User `json:"user"`
}

// WechatLogin 微信登录
func (s *UserService) WechatLogin(req *WechatLoginRequest) (*WechatLoginResponse, error) {
	// 1. 通过code获取openid和session_key
	sessionResp, err := s.wechatClient.Code2Session(req.Code)
	if err != nil {
		return nil, fmt.Errorf("微信登录失败: %v", err)
	}

	// 2. 查找或创建用户
	var user model.User
	err = model.DB.Where("open_id = ?", sessionResp.OpenID).First(&user).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			// 创建新用户
			now := time.Now()
			user = model.User{
				OpenID:      sessionResp.OpenID,
				UnionID:     sessionResp.UnionID,
				Role:        "member",
				IsActive:    true,
				LastLoginAt: &now,
			}

			// 如果有用户信息，保存用户信息
			if req.UserInfo != nil {
				user.Nickname = req.UserInfo.Nickname
				user.Avatar = req.UserInfo.AvatarURL
				user.Gender = int8(req.UserInfo.Gender)
			}

			// 如果有加密的用户信息，也可以解析并保存
			if req.EncryptedData != "" && req.IV != "" {
				// 这里可以解密用户信息并保存
				// userInfo, err := s.wechatClient.DecryptUserInfo(req.EncryptedData, req.IV, sessionResp.SessionKey)
				// if err == nil {
				//     user.Nickname = userInfo.NickName
				//     user.Avatar = userInfo.AvatarUrl
				//     user.Gender = int8(userInfo.Gender)
				// }
			}

			if err := model.DB.Create(&user).Error; err != nil {
				return nil, fmt.Errorf("创建用户失败: %v", err)
			}
		} else {
			return nil, fmt.Errorf("查询用户失败: %v", err)
		}
	}

	// 3. 检查用户状态
	if !user.IsActive {
		return nil, errors.New("用户已被禁用")
	}

	// 4. 检查访客是否过期
	if user.IsGuest() && user.IsGuestExpired() {
		return nil, errors.New("访客权限已过期")
	}

	// 5. 如果有用户信息，更新用户信息（无论是新用户还是已存在用户）
	if req.UserInfo != nil {
		user.Nickname = req.UserInfo.Nickname
		user.Avatar = req.UserInfo.AvatarURL
		user.Gender = int8(req.UserInfo.Gender)
	}

	// 6. 更新最后登录时间
	now := time.Now()
	user.LastLoginAt = &now
	model.DB.Save(&user)

	// 7. 生成JWT token
	token, err := jwt.GenerateToken(user.ID, user.OpenID, user.Role, user.FamilyID)
	if err != nil {
		return nil, fmt.Errorf("生成token失败: %v", err)
	}

	// 8. 预加载关联数据
	model.DB.Preload("Family").First(&user, user.ID)

	return &WechatLoginResponse{
		Token: token,
		User:  &user,
	}, nil
}

// GetUserProfile 获取用户资料
func (s *UserService) GetUserProfile(userID uint) (*model.User, error) {
	var user model.User
	err := model.DB.Preload("Family").Where("id = ? AND is_active = ?", userID, true).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("用户不存在")
		}
		return nil, fmt.Errorf("查询用户失败: %v", err)
	}

	return &user, nil
}

// UpdateUserProfile 更新用户资料
func (s *UserService) UpdateUserProfile(userID uint, updates map[string]interface{}) error {
	// 过滤允许更新的字段
	allowedFields := map[string]bool{
		"nickname": true,
		"avatar":   true,
		"phone":    true,
		"gender":   true,
	}

	filteredUpdates := make(map[string]interface{})
	for key, value := range updates {
		if allowedFields[key] {
			filteredUpdates[key] = value
		}
	}

	if len(filteredUpdates) == 0 {
		return errors.New("没有可更新的字段")
	}

	filteredUpdates["updated_at"] = time.Now()

	err := model.DB.Model(&model.User{}).Where("id = ?", userID).Updates(filteredUpdates).Error
	if err != nil {
		return fmt.Errorf("更新用户资料失败: %v", err)
	}

	return nil
}

// RefreshToken 刷新token
func (s *UserService) RefreshToken(tokenString string) (string, error) {
	return jwt.RefreshToken(tokenString)
}

// GetFamilyMembers 获取家庭成员列表
func (s *UserService) GetFamilyMembers(familyID uint, includeGuests bool) ([]model.User, error) {
	var users []model.User
	query := model.DB.Where("family_id = ? AND is_active = ?", familyID, true)

	if !includeGuests {
		query = query.Where("role != ?", "guest")
	} else {
		// 只包含未过期的访客
		query = query.Where("role != 'guest' OR (role = 'guest' AND (guest_expires_at IS NULL OR guest_expires_at > ?))", time.Now())
	}

	err := query.Order("role ASC, created_at ASC").Find(&users).Error
	if err != nil {
		return nil, fmt.Errorf("查询家庭成员失败: %v", err)
	}

	return users, nil
}

// UpdateUserRole 更新用户角色（仅管理员可操作）
func (s *UserService) UpdateUserRole(adminUserID, targetUserID uint, newRole string) error {
	// 验证管理员权限
	var adminUser model.User
	if err := model.DB.First(&adminUser, adminUserID).Error; err != nil {
		return errors.New("管理员用户不存在")
	}

	if !adminUser.IsAdmin() {
		return errors.New("权限不足")
	}

	// 验证目标用户
	var targetUser model.User
	if err := model.DB.First(&targetUser, targetUserID).Error; err != nil {
		return errors.New("目标用户不存在")
	}

	// 验证是否在同一家庭
	if adminUser.FamilyID == nil || targetUser.FamilyID == nil || *adminUser.FamilyID != *targetUser.FamilyID {
		return errors.New("只能管理同一家庭的成员")
	}

	// 验证角色有效性
	validRoles := map[string]bool{
		"admin":  true,
		"member": true,
		"guest":  true,
	}

	if !validRoles[newRole] {
		return errors.New("无效的角色")
	}

	// 更新角色
	updates := map[string]interface{}{
		"role":       newRole,
		"updated_at": time.Now(),
	}

	// 如果设置为访客，设置过期时间
	if newRole == "guest" {
		expiresAt := time.Now().Add(24 * time.Hour) // 24小时后过期
		updates["guest_expires_at"] = expiresAt
	} else {
		updates["guest_expires_at"] = nil
	}

	err := model.DB.Model(&targetUser).Updates(updates).Error
	if err != nil {
		return fmt.Errorf("更新用户角色失败: %v", err)
	}

	return nil
}

// DeactivateUser 停用用户
func (s *UserService) DeactivateUser(adminUserID, targetUserID uint) error {
	// 验证管理员权限
	var adminUser model.User
	if err := model.DB.First(&adminUser, adminUserID).Error; err != nil {
		return errors.New("管理员用户不存在")
	}

	if !adminUser.IsAdmin() {
		return errors.New("权限不足")
	}

	// 不能停用自己
	if adminUserID == targetUserID {
		return errors.New("不能停用自己")
	}

	// 停用用户
	err := model.DB.Model(&model.User{}).Where("id = ?", targetUserID).Updates(map[string]interface{}{
		"is_active":  false,
		"updated_at": time.Now(),
	}).Error

	if err != nil {
		return fmt.Errorf("停用用户失败: %v", err)
	}

	return nil
}
