package service

import (
	"testing"

	"lover-order-backend/internal/model"
)

func TestIsValidSceneLegacyFamilyStillDecodable(t *testing.T) {
	if !isValidScene(model.SceneCouple) || !isValidScene(model.SceneFuture) {
		t.Fatal("pair/future must be valid")
	}
	// 历史行仍可解码校验，但不算产品可选
	if !isValidScene(model.SceneFamily) {
		t.Fatal("family remains valid for legacy rows")
	}
	if isValidScene("party") {
		t.Fatal("unknown scene invalid")
	}
}

func TestIsProductSceneNoFamily(t *testing.T) {
	if !isProductScene(model.SceneCouple) || !isProductScene(model.SceneFuture) {
		t.Fatal("pair/future are product scenes")
	}
	if isProductScene(model.SceneFamily) {
		t.Fatal("family must not be a product-selectable scene")
	}
}

// Current 在进库前就拒绝 family，不依赖 DB
func TestCurrentRejectsFamilyScene(t *testing.T) {
	s := NewMealService()
	_, err := s.Current(1, 1, model.SceneFamily, model.MoodEasy)
	if err == nil {
		t.Fatal("Current must reject family scene")
	}
	if err.Error() != "scene 不合法" {
		t.Fatalf("want scene 不合法, got %v", err)
	}
}

// applyRecipeJSON 的 scene_tags 校验：family 不可写入
func TestRecipeSceneTagsRejectFamily(t *testing.T) {
	r := &model.Recipe{}
	in := RecipeInput{SceneTags: []string{model.SceneFamily}}
	err := applyRecipeJSON(r, in)
	if err == nil {
		t.Fatal("scene_tags must reject family on write")
	}
}
