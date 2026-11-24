package service

import (
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"lover-order-backend/internal/model"
)

type StickerFavoriteService struct{}

func NewStickerFavoriteService() *StickerFavoriteService {
	return &StickerFavoriteService{}
}

type StickerFavoriteInput struct {
	Image string `json:"image" binding:"required,max=512"`
}

func userHouseholdID(userID uint) *uint {
	var u model.User
	if err := model.DB.Select("household_id").First(&u, userID).Error; err != nil {
		return nil
	}
	if u.HouseholdID == nil || *u.HouseholdID == 0 {
		return nil
	}
	hid := *u.HouseholdID
	return &hid
}

func (s *StickerFavoriteService) List(userID uint) ([]model.StickerFavorite, error) {
	items := make([]model.StickerFavorite, 0)
	if hid := userHouseholdID(userID); hid != nil {
		var rows []model.StickerFavorite
		memberIDs := model.DB.Model(&model.User{}).Select("id").Where("household_id = ?", *hid)
		if err := model.DB.Where("household_id = ? OR user_id IN (?)", *hid, memberIDs).
			Order("id DESC").Find(&rows).Error; err != nil {
			return nil, err
		}
		seen := make(map[string]struct{}, len(rows))
		for _, row := range rows {
			if _, ok := seen[row.Image]; ok {
				continue
			}
			seen[row.Image] = struct{}{}
			items = append(items, row)
		}
		return items, nil
	}
	err := model.DB.Where("user_id = ?", userID).Order("id DESC").Find(&items).Error
	return items, err
}

func (s *StickerFavoriteService) Create(userID uint, in StickerFavoriteInput) (*model.StickerFavorite, error) {
	hid := userHouseholdID(userID)
	if hid != nil {
		var existing model.StickerFavorite
		memberIDs := model.DB.Model(&model.User{}).Select("id").Where("household_id = ?", *hid)
		err := model.DB.Where("(household_id = ? OR user_id IN (?)) AND image = ?", *hid, memberIDs, in.Image).
			Order("id DESC").First(&existing).Error
		if err == nil {
			if existing.HouseholdID == nil {
				_ = model.DB.Model(&existing).Update("household_id", *hid).Error
				existing.HouseholdID = hid
			}
			return &existing, nil
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
	}

	item := model.StickerFavorite{UserID: userID, HouseholdID: hid, Image: in.Image}
	if err := model.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&item).Error; err != nil {
		return nil, err
	}
	if err := model.DB.Where("user_id = ? AND image = ?", userID, in.Image).First(&item).Error; err != nil {
		return nil, err
	}
	if hid != nil {
		GlobalCanvasHub().BroadcastHouseholdSync(*hid, "sticker_favorites_changed", userID)
	}
	return &item, nil
}

func (s *StickerFavoriteService) Delete(userID, id uint) error {
	var target model.StickerFavorite
	if err := model.DB.First(&target, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("这张贴图已不在收藏中")
		}
		return err
	}

	hid := userHouseholdID(userID)
	allowed := target.UserID == userID
	if !allowed && hid != nil {
		if target.HouseholdID != nil && *target.HouseholdID == *hid {
			allowed = true
		} else {
			var cnt int64
			model.DB.Model(&model.User{}).Where("id = ? AND household_id = ?", target.UserID, *hid).Count(&cnt)
			allowed = cnt > 0
		}
	}
	if !allowed {
		return errors.New("这张贴图已不在收藏中")
	}

	if hid != nil {
		memberIDs := model.DB.Model(&model.User{}).Select("id").Where("household_id = ?", *hid)
		res := model.DB.Where("(household_id = ? OR user_id IN (?)) AND image = ?", *hid, memberIDs, target.Image).
			Delete(&model.StickerFavorite{})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return errors.New("这张贴图已不在收藏中")
		}
		GlobalCanvasHub().BroadcastHouseholdSync(*hid, "sticker_favorites_changed", userID)
		return nil
	}

	res := model.DB.Where("id = ? AND user_id = ?", id, userID).Delete(&model.StickerFavorite{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("这张贴图已不在收藏中")
	}
	return nil
}
