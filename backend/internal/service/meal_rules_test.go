package service

import (
	"testing"

	"lover-order-backend/internal/model"
)

func TestErrIfCannotConfirm(t *testing.T) {
	if err := errIfCannotConfirm(model.MealStatusPlanning, 1); err != nil {
		t.Fatalf("planning+1 dish should allow: %v", err)
	}
	if err := errIfCannotConfirm(model.MealStatusPlanning, 0); err == nil {
		t.Fatal("planning+0 dish must reject")
	}
	if err := errIfCannotConfirm(model.MealStatusConfirmed, 2); err == nil {
		t.Fatal("already confirmed must reject")
	}
	if err := errIfCannotConfirm(model.MealStatusCompleted, 1); err == nil {
		t.Fatal("completed must reject")
	}
}

func TestErrIfCannotComplete(t *testing.T) {
	if err := errIfCannotComplete(model.MealStatusConfirmed, 1); err != nil {
		t.Fatalf("confirmed+1 should allow: %v", err)
	}
	if err := errIfCannotComplete(model.MealStatusPlanning, 1); err == nil {
		t.Fatal("planning must reject complete (no skip)")
	}
	if err := errIfCannotComplete(model.MealStatusConfirmed, 0); err == nil {
		t.Fatal("confirmed+0 dish must reject")
	}
}

func TestErrIfCannotRemoveDish(t *testing.T) {
	if err := errIfCannotRemoveDish(model.MealStatusPlanning, 1); err != nil {
		t.Fatalf("planning can remove last: %v", err)
	}
	if err := errIfCannotRemoveDish(model.MealStatusConfirmed, 1); err == nil {
		t.Fatal("confirmed cannot remove last dish")
	}
	if err := errIfCannotRemoveDish(model.MealStatusConfirmed, 2); err != nil {
		t.Fatalf("confirmed with 2 can remove one: %v", err)
	}
	if err := errIfCannotRemoveDish(model.MealStatusCompleted, 2); err == nil {
		t.Fatal("completed cannot remove")
	}
}

func TestCreateScene(t *testing.T) {
	for _, scene := range []string{model.SceneCouple, model.SceneFuture, model.SceneFamily} {
		if !isCreateScene(scene) {
			t.Fatalf("%s should be accepted when creating an explicit record", scene)
		}
	}
	if isProductScene(model.SceneFamily) {
		t.Fatal("family must remain outside the current-meal entry")
	}
}
