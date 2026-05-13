package service

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
	"lover-order-backend/pkg/apple"
	"lover-order-backend/pkg/jwt"
)

// UserService 用户与登录相关业务
type UserService struct{}

// NewUserService 构造
func NewUserService() *UserService {
	return &UserService{}
}

// AppleLoginInput Apple Sign In 入参
type AppleLoginInput struct {
	IdentityToken string `json:"identity_token" binding:"required"`
	Nickname      string `json:"nickname"`
	Avatar        string `json:"avatar"`
}

// LoginResult 登录结果
type LoginResult struct {
	User         *model.User `json:"user"`
	AccessToken  string      `json:"access_token"`
	RefreshToken string      `json:"refresh_token"`
}

// DevLoginInput 开发期登录入参 通过昵称识别同一个用户
type DevLoginInput struct {
	Nickname string `json:"nickname" binding:"required"`
}

// LoginDev 开发期登录 仅在 server.mode != release 时启用
// 用昵称作为唯一标识 不验证密码 不连 Apple
func (s *UserService) LoginDev(in DevLoginInput) (*LoginResult, error) {
	name := in.Nickname
	if name == "" {
		return nil, errors.New("请填昵称")
	}

	pseudoAppleID := "dev:" + name

	var user model.User
	err := model.DB.Where("apple_user_id = ?", pseudoAppleID).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		now := time.Now()
		user = model.User{
			AppleUserID: pseudoAppleID,
			Nickname:    name,
			IsActive:    true,
			LastLoginAt: &now,
		}
		if err := model.DB.Create(&user).Error; err != nil {
			return nil, fmt.Errorf("创建开发用户失败：%w", err)
		}
	} else if err != nil {
		return nil, fmt.Errorf("查询用户失败：%w", err)
	} else {
		_ = model.DB.Model(&user).Update("last_login_at", time.Now()).Error
	}

	access, err := jwt.IssueAccess(user.ID)
	if err != nil {
		return nil, err
	}
	refresh, err := jwt.IssueRefresh(user.ID)
	if err != nil {
		return nil, err
	}
	return &LoginResult{User: &user, AccessToken: access, RefreshToken: refresh}, nil
}

// LoginWithApple Apple 登录或注册
func (s *UserService) LoginWithApple(in AppleLoginInput) (*LoginResult, error) {
	claims, err := apple.Verify(in.IdentityToken)
	if err != nil {
		return nil, err
	}

	var user model.User
	err = model.DB.Where("apple_user_id = ?", claims.Subject).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		now := time.Now()
		user = model.User{
			AppleUserID: claims.Subject,
			Email:       claims.Email,
			Nickname:    pickNickname(in.Nickname),
			Avatar:      in.Avatar,
			IsActive:    true,
			LastLoginAt: &now,
		}
		if err := model.DB.Create(&user).Error; err != nil {
			return nil, fmt.Errorf("创建用户失败：%w", err)
		}
	} else if err != nil {
		return nil, fmt.Errorf("查询用户失败：%w", err)
	} else {
		updates := map[string]any{"last_login_at": time.Now()}
		if in.Nickname != "" && user.Nickname == "" {
			updates["nickname"] = in.Nickname
		}
		if in.Avatar != "" && user.Avatar == "" {
			updates["avatar"] = in.Avatar
		}
		if claims.Email != "" && user.Email == "" {
			updates["email"] = claims.Email
		}
		if err := model.DB.Model(&user).Updates(updates).Error; err != nil {
			return nil, fmt.Errorf("更新登录信息失败：%w", err)
		}
	}

	access, err := jwt.IssueAccess(user.ID)
	if err != nil {
		return nil, err
	}
	refresh, err := jwt.IssueRefresh(user.ID)
	if err != nil {
		return nil, err
	}

	return &LoginResult{User: &user, AccessToken: access, RefreshToken: refresh}, nil
}

// Refresh 刷新访问令牌
func (s *UserService) Refresh(refreshToken string) (string, error) {
	claims, err := jwt.Parse(refreshToken)
	if err != nil {
		return "", err
	}
	if claims.Type != jwt.TokenTypeRefresh {
		return "", errors.New("令牌类型错误")
	}
	return jwt.IssueAccess(claims.UserID)
}

// UpdateProfileInput 更新资料入参
type UpdateProfileInput struct {
	Nickname     *string  `json:"nickname"`
	Avatar       *string  `json:"avatar"`
	Gender       *int8    `json:"gender"`
	DefaultScene *string  `json:"default_scene"`
	DefaultMood  *string  `json:"default_mood"`
	TastePrefs   []string `json:"taste_prefs"`
}

// UpdateProfile 更新当前用户资料
func (s *UserService) UpdateProfile(userID uint, in UpdateProfileInput) (*model.User, error) {
	updates := map[string]any{}
	if in.Nickname != nil {
		updates["nickname"] = *in.Nickname
	}
	if in.Avatar != nil {
		updates["avatar"] = *in.Avatar
	}
	if in.Gender != nil {
		updates["gender"] = *in.Gender
	}
	if in.DefaultScene != nil {
		if !isValidScene(*in.DefaultScene) {
			return nil, errors.New("场景不合法")
		}
		updates["default_scene"] = *in.DefaultScene
	}
	if in.DefaultMood != nil {
		if !isValidMood(*in.DefaultMood) {
			return nil, errors.New("心情不合法")
		}
		updates["default_mood"] = *in.DefaultMood
	}
	if in.TastePrefs != nil {
		data, err := jsonMarshal(in.TastePrefs)
		if err != nil {
			return nil, err
		}
		updates["taste_prefs"] = data
	}

	if len(updates) > 0 {
		if err := model.DB.Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error; err != nil {
			return nil, fmt.Errorf("更新资料失败：%w", err)
		}
	}

	var user model.User
	if err := model.DB.First(&user, userID).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

// GetUser 取用户 含一个家
func (s *UserService) GetUser(userID uint) (*model.User, error) {
	var user model.User
	if err := model.DB.Preload("Household").First(&user, userID).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func pickNickname(want string) string {
	if want != "" {
		return want
	}
	return "美食家"
}
