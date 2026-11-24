package service

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"lover-order-backend/internal/model"
)

// RecipeService 菜谱业务
type RecipeService struct{}

// NewRecipeService 构造
func NewRecipeService() *RecipeService {
	return &RecipeService{}
}

// RecipeInput 创建或更新菜谱入参
type RecipeInput struct {
	Name        string           `json:"name" binding:"required"`
	Description string           `json:"description"`
	CoverImage  string           `json:"cover_image"`
	CutoutImage *string          `json:"cutout_image"`
	Images      []string         `json:"images"`
	CategoryID  *uint            `json:"category_id"`
	CookingTime int              `json:"cooking_time"`
	Difficulty  string           `json:"difficulty"`
	Servings    int              `json:"servings"`
	Ingredients []map[string]any `json:"ingredients"`
	Steps       []map[string]any `json:"steps"`
	Tips        string           `json:"tips"`
	Tags        []string         `json:"tags"`
	MoodTags    []string         `json:"mood_tags"`
	SceneTags   []string         `json:"scene_tags"`
}

type RecipeUpdateInput struct {
	RecipeInput
	ExpectedUpdatedAt *time.Time `json:"expected_updated_at"`
	Force             bool       `json:"force"`
}

var ErrRecipeEditConflict = errors.New("这道菜谱已更新，当前修改还在表单里。请查看最新菜谱后再编辑")

// RecipeCoverInput 设置/自定义菜谱主图与透明贴图入参
type RecipeCoverInput struct {
	Image       string `json:"image"`
	CutoutImage string `json:"cutout_image"`
	AllowClear  bool   `json:"allow_clear"`
}

// BatchCategoryInput 批量修改菜谱分类入参（CategoryID 为 nil 表示移入「未分类」）
type BatchCategoryInput struct {
	RecipeIDs  []uint `json:"recipe_ids" binding:"required"`
	CategoryID *uint  `json:"category_id"`
}

// BatchDeleteInput 批量删除菜谱入参
type BatchDeleteInput struct {
	RecipeIDs []uint `json:"recipe_ids" binding:"required"`
}

// ListQuery 列表筛选
type ListQuery struct {
	CategoryID    *uint
	Uncategorized bool
	Mood          string
	Scene         string
	Keyword       string
	Favorite      bool
	UserID        uint
	Page          int
	PageSize      int
}

// ListResult 列表结果
type ListResult struct {
	Total int64          `json:"total"`
	Items []model.Recipe `json:"items"`
}

// List 列出菜谱
func (s *RecipeService) List(householdID uint, q ListQuery) (*ListResult, error) {
	if q.Page <= 0 {
		q.Page = 1
	}
	if q.PageSize <= 0 || q.PageSize > 100 {
		q.PageSize = 20
	}

	tx := model.DB.Model(&model.Recipe{}).
		Where("recipes.household_id = ? AND recipes.is_archived = ?", householdID, false)

	if q.Uncategorized {
		tx = tx.Where(
			"(recipes.category_id IS NULL OR NOT EXISTS (SELECT 1 FROM recipe_categories rc WHERE rc.id = recipes.category_id AND rc.household_id = ? AND rc.is_active = ? AND rc.deleted_at IS NULL))",
			householdID,
			true,
		)
	} else if q.CategoryID != nil {
		tx = tx.Where("recipes.category_id = ?", *q.CategoryID)
	}
	if q.Keyword != "" {
		kw := "%" + q.Keyword + "%"
		// 搜"鸡蛋"也该命中配料里有蛋的菜 不只搜名字
		tx = tx.Where("recipes.name LIKE ? OR recipes.description LIKE ? OR CAST(recipes.ingredients AS CHAR) LIKE ?", kw, kw, kw)
	}
	if q.Mood != "" {
		tx = tx.Where("JSON_CONTAINS(recipes.mood_tags, JSON_QUOTE(?))", q.Mood)
	}
	if q.Scene != "" {
		tx = tx.Where("JSON_CONTAINS(recipes.scene_tags, JSON_QUOTE(?))", q.Scene)
	}
	if q.Favorite && q.UserID > 0 {
		tx = tx.Joins("JOIN favorites ON favorites.recipe_id = recipes.id AND favorites.user_id = ?", q.UserID)
	}

	var total int64
	if err := tx.Count(&total).Error; err != nil {
		return nil, err
	}

	var items []model.Recipe
	if err := tx.Preload("Category").Preload("Creator").
		Order("last_used_at DESC, id DESC").
		Offset((q.Page - 1) * q.PageSize).Limit(q.PageSize).
		Find(&items).Error; err != nil {
		return nil, err
	}
	if q.UserID > 0 {
		fillFavored(q.UserID, items)
	}
	return &ListResult{Total: total, Items: items}, nil
}

// fillFavored 标记当前用户是否收藏 客户端据此渲染心形初始态
func fillFavored(userID uint, items []model.Recipe) {
	if len(items) == 0 {
		return
	}
	ids := make([]uint, 0, len(items))
	for i := range items {
		ids = append(ids, items[i].ID)
	}
	var favs []model.Favorite
	if err := model.DB.Where("user_id = ? AND recipe_id IN ?", userID, ids).Find(&favs).Error; err != nil {
		return
	}
	favored := make(map[uint]struct{}, len(favs))
	for _, f := range favs {
		favored[f.RecipeID] = struct{}{}
	}
	for i := range items {
		_, ok := favored[items[i].ID]
		items[i].IsFavored = ok
	}
}

// Get 取菜谱详情并自增浏览数
func (s *RecipeService) Get(householdID, userID, id uint) (*model.Recipe, error) {
	var r model.Recipe
	if err := model.DB.Where("id = ? AND household_id = ?", id, householdID).
		Preload("Category").First(&r).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("菜谱不存在")
		}
		return nil, err
	}
	_ = r.IncrViewCount()
	if userID > 0 {
		items := []model.Recipe{r}
		fillFavored(userID, items)
		r = items[0]
	}
	return &r, nil
}

// Create 新建菜谱
func (s *RecipeService) Create(householdID, userID uint, in RecipeInput) (*model.Recipe, error) {
	if err := ensureValidCategory(model.DB, householdID, in.CategoryID); err != nil {
		return nil, err
	}
	if in.Difficulty == "" {
		in.Difficulty = "easy"
	}
	if in.Servings == 0 {
		in.Servings = 2
	}
	r := &model.Recipe{
		Name:        in.Name,
		Description: in.Description,
		CoverImage:  in.CoverImage,
		CategoryID:  in.CategoryID,
		CookingTime: in.CookingTime,
		Difficulty:  in.Difficulty,
		Servings:    in.Servings,
		Tips:        in.Tips,
		HouseholdID: householdID,
		CreatedBy:   userID,
	}
	if in.CutoutImage != nil {
		r.CutoutImage = *in.CutoutImage
	}
	if err := applyRecipeJSON(r, in); err != nil {
		return nil, err
	}
	if r.CoverImage != "" {
		_ = r.UpsertGalleryPhotoMode(r.CoverImage, r.CutoutImage, time.Now().Format("2006-01-02"), true)
	}
	if err := model.DB.Create(r).Error; err != nil {
		return nil, fmt.Errorf("创建菜谱失败：%w", err)
	}
	_ = model.DB.Preload("Category").Preload("Creator").First(r, r.ID).Error
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "recipes_changed", userID)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "categories_changed", userID)
	return r, nil
}

// Update 更新菜谱
func (s *RecipeService) Update(householdID, id uint, in RecipeUpdateInput) (*model.Recipe, error) {
	var r model.Recipe
	var syncedDishes []syncedMealDishRef
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if err := ensureValidCategory(tx, householdID, in.CategoryID); err != nil {
			return err
		}
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ? AND household_id = ?", id, householdID).First(&r).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("菜谱不存在")
			}
			return err
		}
		if in.ExpectedUpdatedAt != nil && !in.Force && !r.UpdatedAt.Equal(*in.ExpectedUpdatedAt) {
			return ErrRecipeEditConflict
		}
		if err := applyRecipeJSON(&r, in.RecipeInput); err != nil {
			return err
		}

		oldName := r.Name
		oldCover := r.CoverImage
		oldCutout := r.CutoutImage

		r.Name = in.Name
		r.Description = in.Description
		if r.CoverImage != in.CoverImage {
			if r.CoverImage != "" && in.CoverImage != "" {
				if err := r.UpsertGalleryPhoto(r.CoverImage, r.CutoutImage, r.CreatedAt.Format("2006-01-02")); err != nil {
					return err
				}
			}
			r.CutoutImage = ""
		}
		r.CoverImage = in.CoverImage
		if in.CutoutImage != nil {
			r.CutoutImage = *in.CutoutImage
		}
		if r.CoverImage != "" && in.CutoutImage != nil {
			if err := r.UpsertGalleryPhotoMode(r.CoverImage, r.CutoutImage, time.Now().Format("2006-01-02"), true); err != nil {
				return err
			}
		}
		r.CategoryID = in.CategoryID
		r.CookingTime = in.CookingTime
		if in.Difficulty != "" {
			r.Difficulty = in.Difficulty
		}
		if in.Servings > 0 {
			r.Servings = in.Servings
		}
		r.Tips = in.Tips

		// 两次保存落在同一毫秒时也要推进更新时间，避免旧表单通过版本检查。
		nextTime := time.Now().Truncate(time.Millisecond)
		if !nextTime.After(r.UpdatedAt) {
			nextTime = r.UpdatedAt.Add(time.Millisecond)
		}
		if err := tx.Session(&gorm.Session{NowFunc: func() time.Time { return nextTime }}).Save(&r).Error; err != nil {
			return err
		}
		var syncErr error
		syncedDishes, syncErr = syncActiveMealDishesForRecipe(tx, householdID, r.ID, oldName, oldCover, oldCutout, &r)
		if syncErr != nil {
			return syncErr
		}
		return tx.Preload("Category").Preload("Creator").First(&r, id).Error
	})
	if err != nil {
		return nil, err
	}
	notifySyncedMealDishes(syncedDishes, 0)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "recipes_changed", 0)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "categories_changed", 0)
	return &r, nil
}

// Delete 软删
func (s *RecipeService) Delete(householdID, id uint) error {
	res := model.DB.Where("id = ? AND household_id = ?", id, householdID).Delete(&model.Recipe{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("菜谱不存在")
	}
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "recipes_changed", 0)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "categories_changed", 0)
	return nil
}

// BatchUpdateCategory 批量将菜谱归入指定分类或设为「未分类」
func (s *RecipeService) BatchUpdateCategory(householdID, actorUserID uint, in BatchCategoryInput) (int64, error) {
	ids := uniqueUintSlice(in.RecipeIDs)
	if len(ids) == 0 {
		return 0, errors.New("请先选择要操作的菜品")
	}
	var affected int64
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if in.CategoryID != nil {
			var cat model.RecipeCategory
			if err := tx.Where("id = ? AND household_id = ? AND is_active = ?", *in.CategoryID, householdID, true).First(&cat).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					return errors.New("目标分类不存在")
				}
				return err
			}
		}
		res := tx.Model(&model.Recipe{}).
			Where("household_id = ? AND id IN ?", householdID, ids).
			Updates(map[string]any{
				"category_id": in.CategoryID,
				"updated_at":  time.Now().Truncate(time.Millisecond),
			})
		if res.Error != nil {
			return res.Error
		}
		affected = res.RowsAffected
		return nil
	})
	if err != nil {
		return 0, err
	}
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "recipes_changed", actorUserID)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "categories_changed", actorUserID)
	return affected, nil
}

// BatchDelete 批量软删菜谱
func (s *RecipeService) BatchDelete(householdID, actorUserID uint, in BatchDeleteInput) (int64, error) {
	ids := uniqueUintSlice(in.RecipeIDs)
	if len(ids) == 0 {
		return 0, errors.New("请先选择要删除的菜品")
	}
	res := model.DB.Where("household_id = ? AND id IN ?", householdID, ids).Delete(&model.Recipe{})
	if res.Error != nil {
		return 0, res.Error
	}
	if res.RowsAffected > 0 {
		GlobalCanvasHub().BroadcastHouseholdSync(householdID, "recipes_changed", actorUserID)
		GlobalCanvasHub().BroadcastHouseholdSync(householdID, "categories_changed", actorUserID)
	}
	return res.RowsAffected, nil
}

// ToggleFavorite 切换收藏
func (s *RecipeService) ToggleFavorite(userID, householdID, recipeID uint) (bool, error) {
	var r model.Recipe
	if err := model.DB.Where("id = ? AND household_id = ?", recipeID, householdID).First(&r).Error; err != nil {
		return false, errors.New("菜谱不存在")
	}
	var existing model.Favorite
	err := model.DB.Where("user_id = ? AND recipe_id = ?", userID, recipeID).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		if err := model.DB.Create(&model.Favorite{UserID: userID, RecipeID: recipeID}).Error; err != nil {
			return false, err
		}
		return true, nil
	}
	if err != nil {
		return false, err
	}
	if err := model.DB.Unscoped().Delete(&existing).Error; err != nil {
		return false, err
	}
	return false, nil
}

// SetCover 把某次实拍或自定义主图/贴图设成菜谱默认封面（保留原主图到历次实拍图库中，避免丢失）
func (s *RecipeService) SetCover(householdID, actorUserID, id uint, in RecipeCoverInput) (*model.Recipe, error) {
	image := strings.TrimSpace(in.Image)
	cutout := strings.TrimSpace(in.CutoutImage)
	if image == "" && cutout == "" && !in.AllowClear {
		return nil, errors.New("图片地址不能为空")
	}

	var r model.Recipe
	var syncedDishes []syncedMealDishRef
	err := model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ? AND household_id = ?", id, householdID).
			First(&r).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("菜谱不存在")
			}
			return err
		}
		oldCover := r.CoverImage
		oldCutout := r.CutoutImage

		if r.CoverImage != "" && r.CoverImage != image {
			if err := r.UpsertGalleryPhoto(r.CoverImage, r.CutoutImage, r.CreatedAt.Format("2006-01-02")); err != nil {
				return err
			}
		}
		if image != "" {
			if err := r.UpsertGalleryPhotoMode(image, cutout, time.Now().Format("2006-01-02"), true); err != nil {
				return err
			}
		}
		r.CoverImage = image
		r.CutoutImage = cutout
		nextTime := time.Now().Truncate(time.Millisecond)
		if !nextTime.After(r.UpdatedAt) {
			nextTime = r.UpdatedAt.Add(time.Millisecond)
		}
		if err := tx.Session(&gorm.Session{NowFunc: func() time.Time { return nextTime }}).Save(&r).Error; err != nil {
			return err
		}
		var syncErr error
		syncedDishes, syncErr = syncActiveMealDishesForRecipe(tx, householdID, r.ID, r.Name, oldCover, oldCutout, &r)
		if syncErr != nil {
			return syncErr
		}
		return tx.Preload("Category").Preload("Creator").First(&r, id).Error
	})
	if err != nil {
		return nil, err
	}
	notifySyncedMealDishes(syncedDishes, actorUserID)
	GlobalCanvasHub().BroadcastHouseholdSync(householdID, "recipes_changed", actorUserID)
	return &r, nil
}

type syncedMealDishRef struct {
	MealID uint
	DishID uint
}

func ensureValidCategory(db *gorm.DB, householdID uint, categoryID *uint) error {
	if categoryID == nil {
		return nil
	}
	var cat model.RecipeCategory
	if err := db.Where("id = ? AND household_id = ? AND is_active = ?", *categoryID, householdID, true).First(&cat).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("目标分类不存在")
		}
		return err
	}
	return nil
}

func syncActiveMealDishesForRecipe(
	tx *gorm.DB,
	householdID, recipeID uint,
	oldName, oldCover, oldCutout string,
	updated *model.Recipe,
) ([]syncedMealDishRef, error) {
	if oldName == updated.Name && oldCover == updated.CoverImage && oldCutout == updated.CutoutImage {
		return nil, nil
	}
	var dishes []model.MealDish
	err := tx.Table("meal_dishes").
		Select("meal_dishes.*").
		Joins("JOIN meal_sessions ON meal_sessions.id = meal_dishes.meal_session_id AND meal_sessions.deleted_at IS NULL").
		Where("meal_sessions.household_id = ? AND meal_sessions.status IN ?", householdID, []string{model.MealStatusPlanning, model.MealStatusConfirmed}).
		Where("meal_dishes.recipe_id = ? AND meal_dishes.deleted_at IS NULL", recipeID).
		Find(&dishes).Error
	if err != nil || len(dishes) == 0 {
		return nil, err
	}

	var affected []syncedMealDishRef
	for _, d := range dishes {
		updates := map[string]any{}
		if d.RecipeName != updated.Name {
			updates["recipe_name"] = updated.Name
		}
		// 仅同步尚未被该顿单独实拍覆盖的餐次菜图，已完成的历史餐次绝不改动
		if d.RecipeImage == oldCover {
			if d.RecipeImage != updated.CoverImage {
				updates["recipe_image"] = updated.CoverImage
			}
			if d.RecipeCutoutImage != updated.CutoutImage {
				updates["recipe_cutout_image"] = updated.CutoutImage
			}
		}
		if len(updates) > 0 {
			if err := tx.Model(&model.MealDish{}).Where("id = ?", d.ID).Updates(updates).Error; err != nil {
				return nil, err
			}
			affected = append(affected, syncedMealDishRef{MealID: d.MealSessionID, DishID: d.ID})
		}
	}
	return affected, nil
}

func notifySyncedMealDishes(refs []syncedMealDishRef, actorUserID uint) {
	if len(refs) == 0 {
		return
	}
	mealSet := make(map[uint]struct{}, len(refs))
	for _, ref := range refs {
		GlobalCanvasHub().UpdateDishStickerImage(ref.MealID, ref.DishID, actorUserID)
		mealSet[ref.MealID] = struct{}{}
	}
	for mealID := range mealSet {
		GlobalCanvasHub().BroadcastMealSync(mealID, "dish_updated", actorUserID)
	}
}

func uniqueUintSlice(items []uint) []uint {
	if len(items) == 0 {
		return nil
	}
	seen := make(map[uint]struct{}, len(items))
	out := make([]uint, 0, len(items))
	for _, v := range items {
		if v == 0 {
			continue
		}
		if _, ok := seen[v]; !ok {
			seen[v] = struct{}{}
			out = append(out, v)
		}
	}
	return out
}

func applyRecipeJSON(r *model.Recipe, in RecipeInput) error {
	if in.Images != nil {
		if err := r.SetImages(in.Images); err != nil {
			return err
		}
	}
	if in.Tags != nil {
		if err := r.SetTags(in.Tags); err != nil {
			return err
		}
	}
	if in.MoodTags != nil {
		for _, m := range in.MoodTags {
			if !isValidMood(m) {
				return fmt.Errorf("mood_tags 含非法值：%s", m)
			}
		}
		if err := r.SetMoodTags(in.MoodTags); err != nil {
			return err
		}
	}
	if in.SceneTags != nil {
		// 菜谱标签只允许首页使用的 household。
		for _, sc := range in.SceneTags {
			if !isProductScene(sc) {
				return fmt.Errorf("scene_tags 含非法值：%s", sc)
			}
		}
		if err := r.SetSceneTags(in.SceneTags); err != nil {
			return err
		}
	}
	if in.Ingredients != nil {
		if err := r.SetIngredients(in.Ingredients); err != nil {
			return err
		}
	}
	if in.Steps != nil {
		if err := r.SetSteps(in.Steps); err != nil {
			return err
		}
	}
	return nil
}
