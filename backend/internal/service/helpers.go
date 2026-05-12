package service

import (
	"crypto/rand"
	"encoding/json"
	"strings"

	"lover-order-backend/internal/model"
)

// 邀请码字符集 去掉容易混淆的 0/O/1/I
const inviteAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

// GenInviteCode 生成 n 位邀请码
func GenInviteCode(n int) (string, error) {
	if n <= 0 {
		n = 8
	}
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	var sb strings.Builder
	sb.Grow(n)
	for _, v := range b {
		sb.WriteByte(inviteAlphabet[int(v)%len(inviteAlphabet)])
	}
	return sb.String(), nil
}

func jsonMarshal(v any) (model.JSON, error) {
	data, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	return model.JSON(data), nil
}

func isValidScene(s string) bool {
	switch s {
	case model.SceneCouple, model.SceneFamily, model.SceneFuture:
		return true
	}
	return false
}

func isValidMood(s string) bool {
	switch s {
	case model.MoodEasy, model.MoodNormal, model.MoodSerious, model.MoodChange:
		return true
	}
	return false
}

func isValidMealStatus(s string) bool {
	switch s {
	case model.MealStatusPlanning, model.MealStatusConfirmed, model.MealStatusCompleted, model.MealStatusCancelled:
		return true
	}
	return false
}
