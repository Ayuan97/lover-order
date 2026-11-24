package service

import (
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"golang.org/x/crypto/bcrypt"
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

// DeviceLoginInput 基于设备唯一 ID 的登录/注册入参（进入只需昵称）
type DeviceLoginInput struct {
	DeviceID string `json:"device_id" binding:"required"`
	Nickname string `json:"nickname" binding:"required"`
}

// ErrDevicePasswordRequired 本机账号已设密码，需走昵称+密码验证登录
var ErrDevicePasswordRequired = errors.New("本机账号已设置密码，请用昵称和密码登录")

// PasswordLoginInput 昵称加密码登录入参（跨设备找回账号）
type PasswordLoginInput struct {
	Nickname string `json:"nickname" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// SetPasswordInput 设置或修改登录密码入参
type SetPasswordInput struct {
	OldPassword string `json:"old_password"`
	NewPassword string `json:"new_password" binding:"required"`
}

func checkPasswordNicknameAvailable(db *gorm.DB, excludeUserID uint, nickname string) error {
	var cnt int64
	if err := db.Model(&model.User{}).
		Where("id <> ? AND nickname = ? AND password_hash <> '' AND is_active = ?", excludeUserID, nickname, true).
		Count(&cnt).Error; err != nil {
		return fmt.Errorf("校验昵称失败：%w", err)
	}
	if cnt > 0 {
		return errors.New("这个昵称已被其他带密码账号占用，请换个昵称")
	}
	return nil
}

// LoginWithDevice 通过设备唯一标识绑定/创建用户（新设备自动注册，老设备直接进入并同步昵称）
func (s *UserService) LoginWithDevice(in DeviceLoginInput) (*LoginResult, error) {
	deviceID := strings.TrimSpace(in.DeviceID)
	if len(deviceID) < 8 || len(deviceID) > 128 {
		return nil, errors.New("设备标识不合法")
	}
	name := strings.TrimSpace(in.Nickname)
	nameLen := utf8.RuneCountInString(name)
	if nameLen < 1 || nameLen > 32 {
		return nil, errors.New("昵称需为 1–32 个字")
	}

	pseudoAppleID := "device:" + deviceID
	var user model.User
	err := model.DB.Where("device_id = ?", deviceID).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		err = model.DB.Where("apple_user_id = ?", pseudoAppleID).First(&user).Error
	}

	if errors.Is(err, gorm.ErrRecordNotFound) {
		now := time.Now()
		dev := deviceID
		user = model.User{
			AppleUserID: pseudoAppleID,
			DeviceID:    &dev,
			Nickname:    name,
			IsActive:    true,
			LastLoginAt: &now,
		}
		if createErr := model.DB.Create(&user).Error; createErr != nil {
			// 并发重复提交时回查同一 device_id
			var retry model.User
			if retryErr := model.DB.Where("device_id = ?", deviceID).First(&retry).Error; retryErr == nil {
				user = retry
			} else {
				return nil, fmt.Errorf("创建用户失败：%w", createErr)
			}
		}
	} else if err != nil {
		return nil, fmt.Errorf("查询用户失败：%w", err)
	} else {
		if !user.IsActive {
			return nil, errors.New("账号已停用")
		}
		if user.PasswordHash != "" {
			return nil, ErrDevicePasswordRequired
		}
		now := time.Now()
		updates := map[string]any{"last_login_at": now}
		if user.DeviceID == nil || *user.DeviceID == "" {
			updates["device_id"] = deviceID
		}
		if name != user.Nickname {
			updates["nickname"] = name
			user.Nickname = name
		}
		if err := model.DB.Model(&user).Updates(updates).Error; err != nil {
			return nil, fmt.Errorf("更新登录状态失败：%w", err)
		}
	}

	user.HasPassword = user.PasswordHash != ""
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

// LoginWithPassword 使用昵称与密码登录（跨设备找回已设密码的账号）
func (s *UserService) LoginWithPassword(in PasswordLoginInput) (*LoginResult, error) {
	name := strings.TrimSpace(in.Nickname)
	if name == "" || in.Password == "" {
		return nil, errors.New("请填写昵称和密码")
	}

	var candidates []model.User
	if err := model.DB.Where("nickname = ? AND password_hash <> '' AND is_active = ?", name, true).
		Find(&candidates).Error; err != nil {
		return nil, fmt.Errorf("查询账号失败：%w", err)
	}

	var matched *model.User
	for i := range candidates {
		if bcrypt.CompareHashAndPassword([]byte(candidates[i].PasswordHash), []byte(in.Password)) == nil {
			matched = &candidates[i]
			break
		}
	}
	if matched == nil {
		return nil, errors.New("昵称或密码不对")
	}

	now := time.Now()
	_ = model.DB.Model(matched).Update("last_login_at", now).Error
	matched.LastLoginAt = &now
	matched.HasPassword = true

	access, err := jwt.IssueAccess(matched.ID)
	if err != nil {
		return nil, err
	}
	refresh, err := jwt.IssueRefresh(matched.ID)
	if err != nil {
		return nil, err
	}
	return &LoginResult{User: matched, AccessToken: access, RefreshToken: refresh}, nil
}

// SetPassword 为当前账号设置或修改登录密码
func (s *UserService) SetPassword(userID uint, in SetPasswordInput) (*model.User, error) {
	if utf8.RuneCountInString(in.NewPassword) < 6 {
		return nil, errors.New("密码至少需要 6 位")
	}
	if len(in.NewPassword) > 72 {
		return nil, errors.New("密码长度不能超过 72 字节")
	}

	var updated model.User
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		var user model.User
		if err := tx.First(&user, userID).Error; err != nil {
			return errors.New("用户不存在")
		}
		if strings.TrimSpace(user.Nickname) == "" {
			return errors.New("请先在编辑资料中设置昵称后再设密码")
		}
		if user.PasswordHash != "" {
			if in.OldPassword == "" || bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.OldPassword)) != nil {
				return errors.New("当前密码不对")
			}
		}
		if err := checkPasswordNicknameAvailable(tx, user.ID, user.Nickname); err != nil {
			return errors.New("当前昵称已被其他带密码账号使用，请先在编辑资料中修改昵称后再设密码")
		}
		hashed, err := bcrypt.GenerateFromPassword([]byte(in.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			return fmt.Errorf("密码加密失败：%w", err)
		}
		if err := tx.Model(&user).Update("password_hash", string(hashed)).Error; err != nil {
			return fmt.Errorf("保存密码失败：%w", err)
		}
		user.PasswordHash = string(hashed)
		user.HasPassword = true
		updated = user
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &updated, nil
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
	var trimmedNickname string
	hasNickname := false
	if in.Nickname != nil {
		trimmed := strings.TrimSpace(*in.Nickname)
		n := utf8.RuneCountInString(trimmed)
		if n < 1 || n > 32 {
			return nil, errors.New("昵称需为 1–32 个字")
		}
		trimmedNickname = trimmed
		hasNickname = true
		updates["nickname"] = trimmed
	}
	if in.Avatar != nil {
		updates["avatar"] = *in.Avatar
	}
	if in.Gender != nil {
		updates["gender"] = *in.Gender
	}
	if in.DefaultScene != nil {
		// 默认餐次只允许日常 household。
		if *in.DefaultScene == model.SceneDining || !isValidScene(*in.DefaultScene) {
			return nil, errors.New("参数不合法")
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

	var user model.User
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if hasNickname {
			var cur model.User
			if err := tx.First(&cur, userID).Error; err != nil {
				return err
			}
			if cur.PasswordHash != "" && cur.Nickname != trimmedNickname {
				if err := checkPasswordNicknameAvailable(tx, userID, trimmedNickname); err != nil {
					return err
				}
			}
		}
		if len(updates) > 0 {
			if err := tx.Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error; err != nil {
				return fmt.Errorf("更新资料失败：%w", err)
			}
		}
		return tx.First(&user, userID).Error
	})
	if err != nil {
		return nil, err
	}
	user.HasPassword = user.PasswordHash != ""
	GlobalCanvasHub().RefreshUserActor(userID)
	if user.HouseholdID != nil {
		GlobalCanvasHub().BroadcastHouseholdSync(*user.HouseholdID, "household_changed", userID)
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
