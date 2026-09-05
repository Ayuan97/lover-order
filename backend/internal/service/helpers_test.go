package service

import (
	"testing"

	"lover-order-backend/internal/model"
)

func TestIsValidScene(t *testing.T) {
	if !isValidScene(model.SceneHousehold) || !isValidScene(model.SceneDining) {
		t.Fatal("household must be valid")
	}
	// 历史行仍可解码校验，但不算产品可选
	if !isValidScene(model.SceneDining) {
		t.Fatal("dining remains valid")
	}
	if isValidScene("party") {
		t.Fatal("unknown scene invalid")
	}
}

func TestIsProductScene(t *testing.T) {
	if !isProductScene(model.SceneHousehold) {
		t.Fatal("household are product scenes")
	}
	if isProductScene(model.SceneDining) {
		t.Fatal("dining must not be a product-selectable scene")
	}
}

// Current 在进库前就拒绝 dining，不依赖 DB
func TestCurrentRejectsDiningScene(t *testing.T) {
	s := NewMealService()
	_, err := s.Current(1, 1, model.SceneDining, model.MoodEasy)
	if err == nil {
		t.Fatal("Current must reject dining scene")
	}
	if err.Error() != "scene 不合法" {
		t.Fatalf("want scene 不合法, got %v", err)
	}
}

// applyRecipeJSON 的 scene_tags 校验：dining 不可写入
func TestRecipeSceneTagsRejectDining(t *testing.T) {
	r := &model.Recipe{}
	in := RecipeInput{SceneTags: []string{model.SceneDining}}
	err := applyRecipeJSON(r, in)
	if err == nil {
		t.Fatal("scene_tags must reject family on write")
	}
}
