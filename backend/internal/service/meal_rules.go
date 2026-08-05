package service

import (
	"errors"

	"lover-order-backend/internal/model"
)

// 一顿主循环规则（可单测）——与产品宪法一致：就这些→吃完了，禁止跳步/空菜

func errIfCannotConfirm(status string, dishCount int) error {
	if status == model.MealStatusConfirmed {
		return errors.New("Ta 刚把这一顿定下啦")
	}
	if status != model.MealStatusPlanning {
		return errors.New("这一顿已经结束了")
	}
	if dishCount == 0 {
		return errors.New("至少选一道菜再定下")
	}
	return nil
}

func errIfCannotComplete(status string, dishCount int) error {
	if status != model.MealStatusConfirmed {
		return errors.New("请先定下这一顿再标记吃完")
	}
	if dishCount == 0 {
		return errors.New("至少留下一道菜再标记吃完")
	}
	return nil
}

// confirmed 至少留一道；要清光走取消
func errIfCannotRemoveDish(status string, dishCount int) error {
	if status != model.MealStatusPlanning && status != model.MealStatusConfirmed {
		return errors.New("这一顿已结束 无法修改")
	}
	if status == model.MealStatusConfirmed && dishCount <= 1 {
		return errors.New("定了至少留一道 要重选就点「算了 重选」")
	}
	return nil
}
