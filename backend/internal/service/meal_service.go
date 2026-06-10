package service

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"lover-order-backend/internal/model"
)

// MealService 一顿的业务
type MealService struct{}

// NewMealService 构造
func NewMealService() *MealService {
	return &MealService{}
}

// MealInput 创建/更新一顿入参
type MealInput struct {
	Title     string     `json:"title"`
	Scene     string     `json:"scene"`
	Mood      string     `json:"mood"`
	PlannedAt *time.Time `json:"planned_at"`
	Note      string     `json:"note"`
}

// DishInput 加入菜入参
type DishInput struct {
	RecipeID *uint  `json:"recipe_id"`
	Name     string `json:"name"`
	Image    string `json:"image"`
	Note     string `json:"note"`
}

// ReviewInput 评价一顿入参
type ReviewInput struct {
	Rating      int               `json:"rating"`
	Comment     string            `json:"comment"`
	Photos      []string          `json:"photos"`
	DishReviews []DishReviewInput `json:"dish_reviews"`
}

// DishReviewInput 单道菜评价入参
type DishReviewInput struct {
	MealDishID uint   `json:"meal_dish_id"`
	Rating     int    `json:"rating"`
	Comment    string `json:"comment"`
}

// ListQuery 一顿列表筛选
type MealListQuery struct {
	Scene    string
	Status   string
	Page     int
	PageSize int
}

// MealList 列表结果
type MealList struct {
	Total int64               `json:"total"`
	Items []model.MealSession `json:"items"`
}

// Current 取或创建当前规划中的一顿
func (s *MealService) Current(householdID, userID uint, scene, mood string) (*model.MealSession, error) {
	if scene == "" {
		scene = model.SceneCouple
	}
	if !isValidScene(scene) {
		return nil, errors.New("scene 不合法")
	}
	if mood == "" {
		mood = model.MoodEasy
	}
	if !isValidMood(mood) {
		return nil, errors.New("mood 不合法")
	}

	var m model.MealSession
	err := model.DB.Where("household_id = ? AND scene = ? AND status IN ?",
		householdID, scene, []string{model.MealStatusPlanning, model.MealStatusConfirmed}).
		Preload("Dishes.Adder").Order("id DESC").First(&m).Error
	if err == nil {
		if m.Status == model.MealStatusConfirmed && len(m.Dishes) == 0 {
			m.Status = model.MealStatusPlanning
			m.ConfirmedAt = nil
			if err := model.DB.Save(&m).Error; err != nil {
				return nil, err
			}
		}
		return &m, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	m = model.MealSession{
		Scene:       scene,
		Mood:        mood,
		Status:      model.MealStatusPlanning,
		HouseholdID: householdID,
		CreatedBy:   userID,
	}
	if err := model.DB.Create(&m).Error; err != nil {
		return nil, err
	}
	return &m, nil
}

// Create 显式创建一顿
func (s *MealService) Create(householdID, userID uint, in MealInput) (*model.MealSession, error) {
	scene := in.Scene
	if scene == "" {
		scene = model.SceneCouple
	}
	if !isValidScene(scene) {
		return nil, errors.New("scene 不合法")
	}
	mood := in.Mood
	if mood == "" {
		mood = model.MoodEasy
	}
	if !isValidMood(mood) {
		return nil, errors.New("mood 不合法")
	}

	m := &model.MealSession{
		Title:       in.Title,
		Scene:       scene,
		Mood:        mood,
		PlannedAt:   in.PlannedAt,
		Note:        in.Note,
		Status:      model.MealStatusPlanning,
		HouseholdID: householdID,
		CreatedBy:   userID,
	}
	if err := model.DB.Create(m).Error; err != nil {
		return nil, fmt.Errorf("创建一顿失败：%w", err)
	}
	return m, nil
}

// Update 修改一顿基础信息 仅在 planning 状态可改
func (s *MealService) Update(householdID, id uint, in MealInput) (*model.MealSession, error) {
	m, err := s.load(householdID, id)
	if err != nil {
		return nil, err
	}
	if m.Status != model.MealStatusPlanning {
		return nil, errors.New("这一顿已定下 无法修改")
	}
	if in.Scene != "" {
		if !isValidScene(in.Scene) {
			return nil, errors.New("scene 不合法")
		}
		m.Scene = in.Scene
	}
	if in.Mood != "" {
		if !isValidMood(in.Mood) {
			return nil, errors.New("mood 不合法")
		}
		m.Mood = in.Mood
	}
	m.Title = in.Title
	m.PlannedAt = in.PlannedAt
	m.Note = in.Note
	if err := model.DB.Save(m).Error; err != nil {
		return nil, err
	}
	return m, nil
}

// Confirm 定下这一顿
func (s *MealService) Confirm(householdID, id uint) (*model.MealSession, error) {
	m, err := s.load(householdID, id)
	if err != nil {
		return nil, err
	}
	if m.Status == model.MealStatusConfirmed {
		// 两人同时点"定下"的撞车场景 让后点的人明白发生了什么
		return nil, errors.New("Ta 刚把这一顿定下啦")
	}
	if m.Status != model.MealStatusPlanning {
		return nil, errors.New("这一顿已经结束了")
	}
	if len(m.Dishes) == 0 {
		return nil, errors.New("至少选一道菜再定下")
	}
	now := time.Now()
	m.Status = model.MealStatusConfirmed
	m.ConfirmedAt = &now
	if err := model.DB.Save(m).Error; err != nil {
		return nil, err
	}
	return m, nil
}

// Complete 标记吃完
func (s *MealService) Complete(householdID, id uint) (*model.MealSession, error) {
	m, err := s.load(householdID, id)
	if err != nil {
		return nil, err
	}
	if m.Status == model.MealStatusCompleted || m.Status == model.MealStatusCancelled {
		return nil, errors.New("当前状态不能完成")
	}
	now := time.Now()
	m.Status = model.MealStatusCompleted
	m.CompletedAt = &now
	m.RoomCode = ""
	m.RoomExpiresAt = nil
	if err := model.DB.Save(m).Error; err != nil {
		return nil, err
	}
	return m, nil
}

// Cancel 取消
func (s *MealService) Cancel(householdID, id uint) error {
	m, err := s.load(householdID, id)
	if err != nil {
		return err
	}
	if m.Status == model.MealStatusCompleted {
		return errors.New("已完成的一顿无法取消")
	}
	m.Status = model.MealStatusCancelled
	m.RoomCode = ""
	m.RoomExpiresAt = nil
	return model.DB.Save(m).Error
}

// AddDish 加入一道菜
func (s *MealService) AddDish(householdID, userID, id uint, in DishInput) (*model.MealDish, error) {
	m, err := s.load(householdID, id)
	if err != nil {
		return nil, err
	}
	if m.Status != model.MealStatusPlanning && m.Status != model.MealStatusConfirmed {
		return nil, errors.New("这一顿已结束 无法再添加")
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
		if err := model.DB.Where("id = ? AND household_id = ?", *in.RecipeID, householdID).First(&r).Error; err == nil {
			dish.RecipeName = r.Name
			dish.RecipeImage = r.CoverImage
			_ = r.MarkUsed()
		} else {
			// 菜谱删了也不挡复刻往顿:退回用调用方带的快照 只断开关联
			dish.RecipeID = nil
		}
	}
	if dish.RecipeName == "" {
		return nil, errors.New("菜品名称不能为空")
	}
	if err := model.DB.Create(dish).Error; err != nil {
		return nil, err
	}
	return dish, nil
}

// RemoveDish 移除一道菜
func (s *MealService) RemoveDish(householdID, mealID, dishID uint) error {
	m, err := s.load(householdID, mealID)
	if err != nil {
		return err
	}
	if m.Status != model.MealStatusPlanning && m.Status != model.MealStatusConfirmed {
		return errors.New("这一顿已结束 无法修改")
	}
	res := model.DB.Where("id = ? AND meal_session_id = ?", dishID, mealID).Delete(&model.MealDish{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("这道菜不存在")
	}
	return nil
}

// AddReview 一顿吃完后留下评价
func (s *MealService) AddReview(householdID, userID, mealID uint, in ReviewInput) (*model.MealReview, error) {
	m, err := s.load(householdID, mealID)
	if err != nil {
		return nil, err
	}
	if m.Status != model.MealStatusCompleted {
		return nil, errors.New("吃完后才能留下评价")
	}
	if in.Rating < 1 || in.Rating > 5 {
		return nil, errors.New("评分必须在 1-5 之间")
	}

	photos, err := jsonMarshal(in.Photos)
	if err != nil {
		return nil, err
	}
	dishIDs := map[uint]bool{}
	for _, dish := range m.Dishes {
		dishIDs[dish.ID] = true
	}

	// 同一人重复提交视为修改 覆盖自己的旧评价 不堆多份
	var old model.MealReview
	hasOld := model.DB.Where("meal_session_id = ? AND user_id = ?", m.ID, userID).First(&old).Error == nil

	review := &model.MealReview{
		MealSessionID: m.ID,
		UserID:        userID,
		Rating:        in.Rating,
		Comment:       in.Comment,
		Photos:        photos,
	}
	if err := model.DB.Transaction(func(tx *gorm.DB) error {
		if hasOld {
			if err := tx.Unscoped().Where("meal_review_id = ?", old.ID).Delete(&model.MealDishReview{}).Error; err != nil {
				return err
			}
			if err := tx.Unscoped().Delete(&old).Error; err != nil {
				return err
			}
		}
		if err := tx.Create(review).Error; err != nil {
			return err
		}
		for _, item := range in.DishReviews {
			if item.MealDishID == 0 {
				continue
			}
			if !dishIDs[item.MealDishID] {
				return errors.New("菜品不属于这一顿")
			}
			if item.Rating < 1 || item.Rating > 5 {
				return errors.New("菜品评分必须在 1-5 之间")
			}
			dishReview := model.MealDishReview{
				MealReviewID:  review.ID,
				MealSessionID: m.ID,
				MealDishID:    item.MealDishID,
				UserID:        userID,
				Rating:        item.Rating,
				Comment:       item.Comment,
			}
			if err := tx.Create(&dishReview).Error; err != nil {
				return err
			}
			review.DishReviews = append(review.DishReviews, dishReview)
		}
		return nil
	}); err != nil {
		return nil, err
	}
	return review, nil
}

// List 一顿列表
func (s *MealService) List(householdID uint, q MealListQuery) (*MealList, error) {
	if q.Page <= 0 {
		q.Page = 1
	}
	if q.PageSize <= 0 || q.PageSize > 100 {
		q.PageSize = 20
	}

	tx := model.DB.Model(&model.MealSession{}).Where("household_id = ?", householdID)
	if q.Scene != "" {
		tx = tx.Where("scene = ?", q.Scene)
	}
	if q.Status != "" {
		tx = tx.Where("status = ?", q.Status)
	}

	var total int64
	if err := tx.Count(&total).Error; err != nil {
		return nil, err
	}

	var items []model.MealSession
	if err := tx.Preload("Dishes").Preload("Creator").
		Order("COALESCE(completed_at, confirmed_at, planned_at, created_at) DESC").
		Offset((q.Page - 1) * q.PageSize).Limit(q.PageSize).
		Find(&items).Error; err != nil {
		return nil, err
	}
	return &MealList{Total: total, Items: items}, nil
}

// ShoppingItem 购物清单项 同名食材聚合一行
type ShoppingItem struct {
	Name    string   `json:"name"`
	Amounts []string `json:"amounts"`
	From    []string `json:"from"`
}

// ShoppingList 一顿的食材清单
type ShoppingList struct {
	MealID uint           `json:"meal_id"`
	Items  []ShoppingItem `json:"items"`
}

// ShoppingList 聚合一顿里所有菜的食材
func (s *MealService) ShoppingList(householdID, mealID uint) (*ShoppingList, error) {
	m, err := s.load(householdID, mealID)
	if err != nil {
		return nil, err
	}

	indexByName := map[string]int{}
	items := []ShoppingItem{}

	for _, dish := range m.Dishes {
		if dish.RecipeID == nil {
			continue
		}
		var r model.Recipe
		if err := model.DB.First(&r, *dish.RecipeID).Error; err != nil {
			continue
		}
		for _, ing := range r.IngredientsList() {
			name, _ := ing["name"].(string)
			amount, _ := ing["amount"].(string)
			if name == "" {
				continue
			}
			if idx, ok := indexByName[name]; ok {
				if amount != "" {
					items[idx].Amounts = append(items[idx].Amounts, amount)
				}
				items[idx].From = append(items[idx].From, r.Name)
			} else {
				indexByName[name] = len(items)
				it := ShoppingItem{
					Name: name,
					From: []string{r.Name},
				}
				if amount != "" {
					it.Amounts = []string{amount}
				}
				items = append(items, it)
			}
		}
	}

	return &ShoppingList{MealID: mealID, Items: items}, nil
}

// HouseholdStats 一个家的累积统计
type HouseholdStats struct {
	TotalMeals     int64            `json:"total_meals"`
	TotalDishes    int64            `json:"total_dishes"`
	RecentDays     int              `json:"recent_days"`
	RecentMeals    int64            `json:"recent_meals"`
	TopDishes      []TopDishItem    `json:"top_dishes"`
	SceneBreakdown []SceneCountItem `json:"scene_breakdown"`
}

// TopDishItem 常吃 Top 项
type TopDishItem struct {
	Name  string `json:"name"`
	Image string `json:"image"`
	Count int64  `json:"count"`
}

// SceneCountItem 场景分布项
type SceneCountItem struct {
	Scene string `json:"scene"`
	Count int64  `json:"count"`
}

// Stats 计算一个家的累积统计
func (s *MealService) Stats(householdID uint) (*HouseholdStats, error) {
	stats := &HouseholdStats{
		RecentDays:     30,
		TopDishes:      []TopDishItem{},
		SceneBreakdown: []SceneCountItem{},
	}

	if err := model.DB.Model(&model.MealSession{}).
		Where("household_id = ? AND status = ?", householdID, model.MealStatusCompleted).
		Count(&stats.TotalMeals).Error; err != nil {
		return nil, err
	}

	if err := model.DB.Model(&model.MealDish{}).
		Joins("JOIN meal_sessions ON meal_sessions.id = meal_dishes.meal_session_id AND meal_sessions.deleted_at IS NULL").
		Where("meal_sessions.household_id = ? AND meal_sessions.status = ?", householdID, model.MealStatusCompleted).
		Count(&stats.TotalDishes).Error; err != nil {
		return nil, err
	}

	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	if err := model.DB.Model(&model.MealSession{}).
		Where("household_id = ? AND status = ? AND COALESCE(completed_at, confirmed_at, created_at) >= ?",
			householdID, model.MealStatusCompleted, thirtyDaysAgo).
		Count(&stats.RecentMeals).Error; err != nil {
		return nil, err
	}

	rows, err := model.DB.Table("meal_dishes").
		Select("meal_dishes.recipe_name AS name, MAX(meal_dishes.recipe_image) AS image, COUNT(*) AS cnt").
		Joins("JOIN meal_sessions ON meal_sessions.id = meal_dishes.meal_session_id AND meal_sessions.deleted_at IS NULL").
		Where("meal_sessions.household_id = ? AND meal_sessions.status = ?", householdID, model.MealStatusCompleted).
		Group("meal_dishes.recipe_name").
		Order("cnt DESC").
		Limit(5).
		Rows()
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var item TopDishItem
			var imagePtr *string
			if err := rows.Scan(&item.Name, &imagePtr, &item.Count); err == nil {
				if imagePtr != nil {
					item.Image = *imagePtr
				}
				stats.TopDishes = append(stats.TopDishes, item)
			}
		}
	}

	sceneRows, err := model.DB.Table("meal_sessions").
		Select("scene, COUNT(*) AS cnt").
		Where("household_id = ? AND status = ? AND deleted_at IS NULL", householdID, model.MealStatusCompleted).
		Group("scene").
		Rows()
	if err == nil {
		defer sceneRows.Close()
		for sceneRows.Next() {
			var item SceneCountItem
			if err := sceneRows.Scan(&item.Scene, &item.Count); err == nil {
				stats.SceneBreakdown = append(stats.SceneBreakdown, item)
			}
		}
	}

	return stats, nil
}

// Get 取一顿详情
func (s *MealService) Get(householdID, id uint) (*model.MealSession, error) {
	var m model.MealSession
	if err := model.DB.Where("id = ? AND household_id = ?", id, householdID).
		Preload("Dishes.Adder").Preload("Participants.User").Preload("Reviews.User").Preload("Reviews.DishReviews").Preload("Creator").
		First(&m).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("这一顿不存在")
		}
		return nil, err
	}
	return &m, nil
}

func (s *MealService) load(householdID, id uint) (*model.MealSession, error) {
	var m model.MealSession
	if err := model.DB.Where("id = ? AND household_id = ?", id, householdID).
		Preload("Dishes").First(&m).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("这一顿不存在")
		}
		return nil, err
	}
	return &m, nil
}
