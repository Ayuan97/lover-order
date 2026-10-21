package service

import (
	"errors"

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

func (s *StickerFavoriteService) List(userID uint) ([]model.StickerFavorite, error) {
	items := make([]model.StickerFavorite, 0)
	err := model.DB.Where("user_id = ?", userID).Order("id DESC").Find(&items).Error
	return items, err
}

func (s *StickerFavoriteService) Create(userID uint, in StickerFavoriteInput) (*model.StickerFavorite, error) {
	item := model.StickerFavorite{UserID: userID, Image: in.Image}
	if err := model.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&item).Error; err != nil {
		return nil, err
	}
	err := model.DB.Where("user_id = ? AND image = ?", userID, in.Image).First(&item).Error
	return &item, err
}

func (s *StickerFavoriteService) Delete(userID, id uint) error {
	res := model.DB.Where("id = ? AND user_id = ?", id, userID).Delete(&model.StickerFavorite{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("这张贴图已不在收藏中")
	}
	return nil
}
