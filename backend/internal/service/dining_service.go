package service

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
)

// DiningService 聚餐模式 临时多人参与某一顿点菜 不改变参与者的 household 归属
type DiningService struct{}

// NewDiningService 构造
func NewDiningService() *DiningService {
	return &DiningService{}
}

const diningTTL = 3 * time.Hour

// Open host 在自己家的某一顿上开聚餐 生成房间号
func (s *DiningService) Open(householdID, mealID uint) (*model.MealSession, error) {
	var m model.MealSession
	if err := model.DB.Where("id = ? AND household_id = ?", mealID, householdID).First(&m).Error; err != nil {
		return nil, errors.New("这一顿不存在")
	}
	if m.Status == model.MealStatusCompleted || m.Status == model.MealStatusCancelled {
		return nil, errors.New("这一顿已结束 无法开聚餐")
	}
	code, err := genUniqueRoomCode()
	if err != nil {
		return nil, err
	}
	expires := time.Now().Add(diningTTL)
	if err := model.DB.Model(&m).Updates(map[string]any{"room_code": code, "room_expires_at": expires}).Error; err != nil {
		return nil, err
	}
	return s.detail(m.ID)
}

// Close host 关闭聚餐 房间号作废 参与者随之失效
func (s *DiningService) Close(householdID, mealID uint) error {
	res := model.DB.Model(&model.MealSession{}).
		Where("id = ? AND household_id = ?", mealID, householdID).
		Updates(map[string]any{"room_code": "", "room_expires_at": nil})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("这一顿不存在")
	}
	return nil
}

// Join 访客按房间号加入聚餐 仅记一条参与 不动 household
func (s *DiningService) Join(userID uint, roomCode string) (*model.MealSession, error) {
	var m model.MealSession
	if err := model.DB.Where("room_code = ?", roomCode).First(&m).Error; err != nil {
		return nil, errors.New("房间号无效")
	}
	if !roomAlive(&m) {
		return nil, errors.New("聚餐已结束")
	}
	var existing model.MealParticipant
	err := model.DB.Where("meal_session_id = ? AND user_id = ?", m.ID, userID).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		p := &model.MealParticipant{MealSessionID: m.ID, UserID: userID, JoinedAt: time.Now()}
		if err := model.DB.Create(p).Error; err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}
	return s.detail(m.ID)
}

// Leave 访客离开聚餐
func (s *DiningService) Leave(userID, mealID uint) error {
	return model.DB.Where("meal_session_id = ? AND user_id = ?", mealID, userID).
		Delete(&model.MealParticipant{}).Error
}

// Current 访客当前参与中的聚餐 没有或已过期返回 nil
func (s *DiningService) Current(userID uint) (*model.MealSession, error) {
	var p model.MealParticipant
	if err := model.DB.Where("user_id = ?", userID).Order("joined_at DESC").First(&p).Error; err != nil {
		return nil, nil
	}
	m, err := s.detail(p.MealSessionID)
	if err != nil {
		return nil, nil
	}
	if !roomAlive(m) {
		return nil, nil
	}
	return m, nil
}

// AddDish 聚餐里点菜 host 家成员或参与者均可
func (s *DiningService) AddDish(userID, mealID uint, in DishInput) (*model.MealSession, error) {
	var m model.MealSession
	if err := model.DB.First(&m, mealID).Error; err != nil {
		return nil, errors.New("聚餐不存在")
	}
	if !roomAlive(&m) {
		return nil, errors.New("聚餐已结束")
	}
	if !s.canParticipate(userID, &m) {
		return nil, errors.New("你不在这个聚餐里")
	}
	dish := &model.MealDish{
		MealSessionID: m.ID,
		RecipeID:      in.RecipeID,
		RecipeName:    in.Name,
		RecipeImage:   in.Image,
		Note:          in.Note,
		AddedBy:       userID,
	}
	if in.RecipeID != nil {
		var r model.Recipe
		if err := model.DB.Where("id = ? AND household_id = ?", *in.RecipeID, m.HouseholdID).First(&r).Error; err == nil {
			dish.RecipeName = r.Name
			dish.RecipeImage = r.CoverImage
		}
	}
	if err := model.DB.Create(dish).Error; err != nil {
		return nil, err
	}
	return s.detail(m.ID)
}

// RemoveDish 聚餐里移除自己加的菜
func (s *DiningService) RemoveDish(userID, mealID, dishID uint) error {
	res := model.DB.Where("id = ? AND meal_session_id = ? AND added_by = ?", dishID, mealID, userID).
		Delete(&model.MealDish{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("只能移除自己点的菜")
	}
	return nil
}

// Recipes 聚餐可点的菜 即召集者家的菜单 所有参与者共用同一份
func (s *DiningService) Recipes(userID, mealID uint, keyword string) ([]model.Recipe, error) {
	var m model.MealSession
	if err := model.DB.First(&m, mealID).Error; err != nil {
		return nil, errors.New("聚餐不存在")
	}
	if !roomAlive(&m) {
		return nil, errors.New("聚餐已结束")
	}
	if !s.canParticipate(userID, &m) {
		return nil, errors.New("你不在这个聚餐里")
	}
	q := model.DB.Where("household_id = ?", m.HouseholdID)
	if keyword != "" {
		q = q.Where("name LIKE ?", "%"+keyword+"%")
	}
	recipes := []model.Recipe{}
	if err := q.Order("id DESC").Find(&recipes).Error; err != nil {
		return nil, err
	}
	return recipes, nil
}

// canParticipate host 家成员或已加入的参与者
func (s *DiningService) canParticipate(userID uint, m *model.MealSession) bool {
	var u model.User
	if err := model.DB.First(&u, userID).Error; err == nil {
		if u.HouseholdID != nil && *u.HouseholdID == m.HouseholdID {
			return true
		}
	}
	var cnt int64
	model.DB.Model(&model.MealParticipant{}).
		Where("meal_session_id = ? AND user_id = ?", m.ID, userID).Count(&cnt)
	return cnt > 0
}

func (s *DiningService) detail(mealID uint) (*model.MealSession, error) {
	var m model.MealSession
	if err := model.DB.
		Preload("Dishes.Adder").
		Preload("Participants.User").
		Preload("Creator").
		First(&m, mealID).Error; err != nil {
		return nil, err
	}
	return &m, nil
}

func roomAlive(m *model.MealSession) bool {
	return m.RoomCode != "" && m.RoomExpiresAt != nil && m.RoomExpiresAt.After(time.Now())
}

func genUniqueRoomCode() (string, error) {
	for i := 0; i < 8; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(1000000))
		if err != nil {
			return "", err
		}
		code := fmt.Sprintf("%06d", n.Int64())
		var cnt int64
		if err := model.DB.Model(&model.MealSession{}).
			Where("room_code = ?", code).Count(&cnt).Error; err != nil {
			return "", err
		}
		if cnt == 0 {
			return code, nil
		}
	}
	return "", errors.New("生成房间号失败 请重试")
}
