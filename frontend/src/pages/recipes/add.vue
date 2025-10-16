<template>
  <view class="add-recipe-page">
    <!-- 页面头部 -->
    <view class="page-header">
      <text class="page-title">添加菜谱</text>
      <text class="page-subtitle">分享您的拿手好菜</text>
    </view>

    <!-- 表单内容 -->
    <view class="form-container">
      <!-- 菜谱图片 -->
      <view class="form-section">
        <text class="section-title">菜谱图片</text>
        <view class="image-upload">
          <image
            v-if="form.image"
            class="preview-image"
            :src="form.image"
            mode="aspectFill"
            @click="chooseImage"
          />
          <view v-else class="upload-placeholder" @click="chooseImage">
            <text class="upload-icon">📸</text>
            <text class="upload-text">点击上传图片</text>
          </view>
        </view>
      </view>

      <!-- 基本信息 -->
      <view class="form-section">
        <text class="section-title">基本信息</text>

        <view class="form-item">
          <text class="form-label">菜名 <text class="required">*</text></text>
          <input
            class="form-input"
            v-model="form.name"
            placeholder="给您的菜品起个好听的名字"
            maxlength="50"
          />
        </view>

        <view class="form-item">
          <text class="form-label">描述</text>
          <textarea
            class="form-textarea"
            v-model="form.description"
            placeholder="简单描述一下这道菜的特色（可选）"
            maxlength="200"
            :show-confirm-bar="false"
          />
        </view>

        <view class="form-item">
          <text class="form-label">分类 <text class="required">*</text></text>
          <view class="category-selector" @click="showCategoryPicker = true">
            <text class="selected-value" :class="{ placeholder: !form.category_id }">
              {{ selectedCategoryName || '请选择分类' }}
            </text>
            <text class="arrow">></text>
          </view>
        </view>

        <view class="form-row">
          <view class="form-item half">
            <text class="form-label">烹饪时间 <text class="required">*</text></text>
            <view class="input-with-unit">
              <input
                class="form-input small"
                v-model="form.cooking_time"
                type="number"
                placeholder="30"
              />
              <text class="unit">分钟</text>
            </view>
          </view>

          <view class="form-item half">
            <text class="form-label">难度 <text class="required">*</text></text>
            <view class="difficulty-selector">
              <view
                class="difficulty-item"
                :class="{ active: form.difficulty === 1 }"
                @click="form.difficulty = 1"
              >
                <text class="difficulty-text">简单</text>
              </view>
              <view
                class="difficulty-item"
                :class="{ active: form.difficulty === 2 }"
                @click="form.difficulty = 2"
              >
                <text class="difficulty-text">中等</text>
              </view>
              <view
                class="difficulty-item"
                :class="{ active: form.difficulty === 3 }"
                @click="form.difficulty = 3"
              >
                <text class="difficulty-text">困难</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- 食材列表 -->
      <view class="form-section">
        <view class="section-header">
          <text class="section-title">食材列表</text>
          <text class="section-tip">（可选）</text>
        </view>

        <view class="ingredients-list">
          <view
            class="ingredient-item"
            v-for="(ingredient, index) in form.ingredients"
            :key="index"
          >
            <input
              class="ingredient-input name"
              v-model="ingredient.name"
              placeholder="食材名称"
              maxlength="30"
            />
            <input
              class="ingredient-input amount"
              v-model="ingredient.amount"
              placeholder="用量"
              maxlength="20"
            />
            <view class="delete-btn" @click="removeIngredient(index)">
              <text class="delete-icon">✕</text>
            </view>
          </view>
        </view>

        <button class="add-item-btn" @click="addIngredient">
          <text class="btn-icon">+</text>
          <text class="btn-text">添加食材</text>
        </button>
      </view>

      <!-- 烹饪步骤 -->
      <view class="form-section">
        <view class="section-header">
          <text class="section-title">烹饪步骤</text>
          <text class="section-tip">（可选）</text>
        </view>

        <view class="steps-list">
          <view
            class="step-item"
            v-for="(step, index) in form.steps"
            :key="index"
          >
            <view class="step-number">
              <text class="number-text">{{ index + 1 }}</text>
            </view>
            <textarea
              class="step-input"
              v-model="step.content"
              :placeholder="`第${index + 1}步：详细描述操作步骤`"
              maxlength="200"
              :show-confirm-bar="false"
            />
            <view class="delete-btn" @click="removeStep(index)">
              <text class="delete-icon">✕</text>
            </view>
          </view>
        </view>

        <button class="add-item-btn" @click="addStep">
          <text class="btn-icon">+</text>
          <text class="btn-text">添加步骤</text>
        </button>
      </view>
    </view>

    <!-- 底部操作按钮 -->
    <view class="footer-actions">
      <button class="action-btn cancel-btn" @click="handleCancel">
        取消
      </button>
      <button
        class="action-btn submit-btn"
        :disabled="!isFormValid || isSubmitting"
        @click="handleSubmit"
      >
        {{ isSubmitting ? '保存中...' : '保存菜谱' }}
      </button>
    </view>

    <!-- 分类选择器弹窗 -->
    <view class="category-modal" v-if="showCategoryPicker" @click="showCategoryPicker = false">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="modal-title">选择分类</text>
          <text class="modal-close" @click="showCategoryPicker = false">✕</text>
        </view>
        <view class="category-list">
          <view
            class="category-option"
            :class="{ active: form.category_id === category.id }"
            v-for="category in categories"
            :key="category.id"
            @click="selectCategory(category)"
          >
            <text class="category-name">{{ category.name }}</text>
            <text class="check-icon" v-if="form.category_id === category.id">✓</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RecipeService, CategoryService } from '@/api/recipe'

// 表单数据
const form = ref({
  name: '',
  description: '',
  category_id: null as number | null,
  cooking_time: '' as string | number,
  difficulty: 1,
  image: '',
  ingredients: [] as Array<{ name: string; amount: string }>,
  steps: [] as Array<{ content: string }>
})

// 分类数据
const categories = ref<any[]>([])
const showCategoryPicker = ref(false)
const isSubmitting = ref(false)

// 计算选中的分类名称
const selectedCategoryName = computed(() => {
  if (!form.value.category_id) return ''
  const category = categories.value.find(c => c.id === form.value.category_id)
  return category ? category.name : ''
})

// 表单验证
const isFormValid = computed(() => {
  return (
    form.value.name.trim() !== '' &&
    form.value.category_id !== null &&
    form.value.cooking_time !== '' &&
    Number(form.value.cooking_time) > 0
  )
})

// 页面加载
onMounted(async () => {
  await loadCategories()
})

// 加载分类列表
const loadCategories = async () => {
  try {
    console.log('加载分类列表...')
    const result = await CategoryService.getCategoryList()
    categories.value = result || []
    console.log('分类加载成功:', categories.value.length)
  } catch (error: any) {
    console.error('加载分类失败:', error)
    uni.showToast({
      title: '加载分类失败',
      icon: 'error'
    })
  }
}

// 选择图片
const chooseImage = () => {
  uni.chooseImage({
    count: 1,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: (res) => {
      form.value.image = res.tempFilePaths[0]
    },
    fail: (err) => {
      console.error('选择图片失败:', err)
    }
  })
}

// 选择分类
const selectCategory = (category: any) => {
  form.value.category_id = category.id
  showCategoryPicker.value = false
}

// 添加食材
const addIngredient = () => {
  form.value.ingredients.push({ name: '', amount: '' })
}

// 删除食材
const removeIngredient = (index: number) => {
  form.value.ingredients.splice(index, 1)
}

// 添加步骤
const addStep = () => {
  form.value.steps.push({ content: '' })
}

// 删除步骤
const removeStep = (index: number) => {
  form.value.steps.splice(index, 1)
}

// 取消
const handleCancel = () => {
  uni.showModal({
    title: '确认取消',
    content: '确定要取消添加菜谱吗？已填写的内容将不会保存',
    confirmText: '确认取消',
    cancelText: '继续编辑',
    success: (res) => {
      if (res.confirm) {
        uni.navigateBack()
      }
    }
  })
}

// 提交表单
const handleSubmit = async () => {
  if (!isFormValid.value || isSubmitting.value) {
    return
  }

  try {
    isSubmitting.value = true

    // 过滤空的食材和步骤
    const ingredients = form.value.ingredients.filter(
      item => item.name.trim() !== ''
    )
    const steps = form.value.steps.filter(
      item => item.content.trim() !== ''
    )

    // 构建提交数据
    const submitData = {
      name: form.value.name.trim(),
      description: form.value.description.trim(),
      category_id: form.value.category_id!,
      cooking_time: Number(form.value.cooking_time),
      difficulty: form.value.difficulty,
      image: form.value.image,
      ingredients: ingredients.length > 0 ? JSON.stringify(ingredients) : undefined,
      steps: steps.length > 0 ? JSON.stringify(steps) : undefined
    }

    console.log('提交菜谱数据:', submitData)

    // 调用API创建菜谱
    const result = await RecipeService.createRecipe(submitData)
    console.log('菜谱创建成功:', result)

    uni.showToast({
      title: '保存成功',
      icon: 'success',
      duration: 1500
    })

    // 延迟返回，让用户看到成功提示
    setTimeout(() => {
      uni.navigateBack()
    }, 1500)

  } catch (error: any) {
    console.error('保存菜谱失败:', error)
    uni.showToast({
      title: error.message || '保存失败',
      icon: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.add-recipe-page {
  min-height: 100vh;
  background-color: $bg-page;
  padding-bottom: 160rpx;
}

// 页面头部
.page-header {
  background: $gradient-primary;
  padding: 48rpx $spacing-base 40rpx;
  color: white;

  .page-title {
    display: block;
    font-size: $font-size-xl;
    font-weight: $font-weight-bold;
    margin-bottom: 8rpx;
  }

  .page-subtitle {
    display: block;
    font-size: $font-size-sm;
    opacity: 0.9;
  }
}

// 表单容器
.form-container {
  padding: $spacing-base;
}

// 表单区块
.form-section {
  background-color: $bg-card;
  border-radius: $radius-lg;
  padding: $spacing-lg;
  margin-bottom: $spacing-base;
  box-shadow: $shadow-base;

  .section-header {
    display: flex;
    align-items: center;
    margin-bottom: $spacing-base;

    .section-tip {
      font-size: $font-size-xs;
      color: $text-tertiary;
      margin-left: $spacing-xs;
    }
  }

  .section-title {
    display: block;
    font-size: $font-size-md;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: $spacing-base;
  }
}

// 图片上传
.image-upload {
  width: 100%;
  height: 400rpx;
  border-radius: $radius-md;
  overflow: hidden;

  .preview-image {
    width: 100%;
    height: 100%;
  }

  .upload-placeholder {
    width: 100%;
    height: 100%;
    background-color: $bg-section;
    border: 2rpx dashed $border-base;
    border-radius: $radius-md;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    transition: all $duration-base $ease-out;

    &:active {
      background-color: $bg-hover;
    }

    .upload-icon {
      font-size: 80rpx;
      margin-bottom: $spacing-md;
      opacity: 0.6;
    }

    .upload-text {
      font-size: $font-size-sm;
      color: $text-secondary;
    }
  }
}

// 表单项
.form-item {
  margin-bottom: $spacing-lg;

  &:last-child {
    margin-bottom: 0;
  }

  .form-label {
    display: block;
    font-size: $font-size-sm;
    color: $text-primary;
    font-weight: $font-weight-medium;
    margin-bottom: $spacing-sm;

    .required {
      color: $danger;
    }
  }

  .form-input {
    width: 100%;
    padding: $spacing-base;
    background-color: $bg-section;
    border: 2rpx solid transparent;
    border-radius: $radius-base;
    font-size: $font-size-base;
    color: $text-primary;
    transition: all $duration-base $ease-out;

    &:focus {
      background-color: white;
      border-color: $primary;
      box-shadow: 0 2rpx 8rpx rgba(255, 138, 101, 0.15);
    }

    &::placeholder {
      color: $text-placeholder;
    }

    &.small {
      padding: $spacing-md;
    }
  }

  .form-textarea {
    width: 100%;
    min-height: 160rpx;
    padding: $spacing-base;
    background-color: $bg-section;
    border: 2rpx solid transparent;
    border-radius: $radius-base;
    font-size: $font-size-base;
    color: $text-primary;
    line-height: $line-height-base;
    transition: all $duration-base $ease-out;

    &:focus {
      background-color: white;
      border-color: $primary;
      box-shadow: 0 2rpx 8rpx rgba(255, 138, 101, 0.15);
    }

    &::placeholder {
      color: $text-placeholder;
    }
  }
}

// 表单行（两列）
.form-row {
  display: flex;
  gap: $spacing-md;

  .form-item.half {
    flex: 1;
  }
}

// 带单位的输入框
.input-with-unit {
  display: flex;
  align-items: center;
  gap: $spacing-sm;

  .form-input {
    flex: 1;
  }

  .unit {
    font-size: $font-size-sm;
    color: $text-secondary;
  }
}

// 分类选择器
.category-selector {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: $spacing-base;
  background-color: $bg-section;
  border-radius: $radius-base;
  transition: all $duration-base $ease-out;

  &:active {
    background-color: $bg-hover;
  }

  .selected-value {
    font-size: $font-size-base;
    color: $text-primary;

    &.placeholder {
      color: $text-placeholder;
    }
  }

  .arrow {
    font-size: $font-size-sm;
    color: $text-tertiary;
  }
}

// 难度选择器
.difficulty-selector {
  display: flex;
  gap: $spacing-sm;

  .difficulty-item {
    flex: 1;
    padding: $spacing-md;
    background-color: $bg-section;
    border: 2rpx solid transparent;
    border-radius: $radius-base;
    text-align: center;
    transition: all $duration-base $ease-out;

    &.active {
      background-color: $primary-light;
      border-color: $primary;

      .difficulty-text {
        color: white;
        font-weight: $font-weight-bold;
      }
    }

    .difficulty-text {
      font-size: $font-size-sm;
      color: $text-secondary;
    }
  }
}

// 食材列表
.ingredients-list {
  margin-bottom: $spacing-md;

  .ingredient-item {
    display: flex;
    align-items: center;
    gap: $spacing-sm;
    margin-bottom: $spacing-sm;

    .ingredient-input {
      padding: $spacing-md;
      background-color: $bg-section;
      border: 2rpx solid transparent;
      border-radius: $radius-base;
      font-size: $font-size-sm;
      color: $text-primary;
      transition: all $duration-base $ease-out;

      &:focus {
        background-color: white;
        border-color: $primary;
      }

      &.name {
        flex: 2;
      }

      &.amount {
        flex: 1;
      }
    }

    .delete-btn {
      width: 56rpx;
      height: 56rpx;
      background-color: $bg-section;
      border-radius: $radius-base;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all $duration-base $ease-out;

      &:active {
        background-color: $danger-light;
      }

      .delete-icon {
        font-size: $font-size-md;
        color: $danger;
      }
    }
  }
}

// 步骤列表
.steps-list {
  margin-bottom: $spacing-md;

  .step-item {
    display: flex;
    align-items: flex-start;
    gap: $spacing-sm;
    margin-bottom: $spacing-md;

    .step-number {
      width: 48rpx;
      height: 48rpx;
      background: $gradient-primary;
      border-radius: 24rpx;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      margin-top: $spacing-sm;

      .number-text {
        font-size: $font-size-xs;
        color: white;
        font-weight: $font-weight-bold;
      }
    }

    .step-input {
      flex: 1;
      min-height: 120rpx;
      padding: $spacing-md;
      background-color: $bg-section;
      border: 2rpx solid transparent;
      border-radius: $radius-base;
      font-size: $font-size-sm;
      color: $text-primary;
      line-height: $line-height-base;
      transition: all $duration-base $ease-out;

      &:focus {
        background-color: white;
        border-color: $primary;
      }
    }

    .delete-btn {
      width: 56rpx;
      height: 56rpx;
      background-color: $bg-section;
      border-radius: $radius-base;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      margin-top: $spacing-sm;
      transition: all $duration-base $ease-out;

      &:active {
        background-color: $danger-light;
      }

      .delete-icon {
        font-size: $font-size-md;
        color: $danger;
      }
    }
  }
}

// 添加项目按钮
.add-item-btn {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: $spacing-xs;
  padding: $spacing-md;
  background-color: transparent;
  border: 2rpx dashed $border-base;
  border-radius: $radius-base;
  color: $primary;
  font-size: $font-size-sm;
  transition: all $duration-base $ease-out;

  &:active {
    background-color: $bg-section;
    border-color: $primary;
  }

  .btn-icon {
    font-size: $font-size-lg;
    font-weight: $font-weight-bold;
  }

  .btn-text {
    font-weight: $font-weight-medium;
  }
}

// 底部操作按钮
.footer-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  gap: $spacing-md;
  padding: $spacing-base;
  background-color: white;
  border-top: 1rpx solid $border-light;
  box-shadow: 0 -4rpx 12rpx rgba(0, 0, 0, 0.05);
  z-index: 100;

  .action-btn {
    flex: 1;
    height: 88rpx;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    border: none;
    transition: all $duration-base $ease-out;

    &:active {
      transform: scale(0.96);
    }

    &.cancel-btn {
      background-color: $bg-section;
      color: $text-secondary;

      &:active {
        background-color: $bg-disabled;
      }
    }

    &.submit-btn {
      background: $gradient-primary;
      color: white;
      box-shadow: $shadow-primary;

      &:disabled {
        opacity: 0.6;
        transform: none;
      }

      &:active:not(:disabled) {
        box-shadow: $shadow-primary-hover;
      }
    }
  }
}

// 分类选择弹窗
.category-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;

  .modal-content {
    width: 600rpx;
    max-height: 70vh;
    background-color: white;
    border-radius: $radius-xl;
    overflow: hidden;
    box-shadow: 0 16rpx 48rpx rgba(0, 0, 0, 0.2);

    .modal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: $spacing-lg $spacing-lg $spacing-base;
      border-bottom: 1rpx solid $border-light;

      .modal-title {
        font-size: $font-size-lg;
        font-weight: $font-weight-bold;
        color: $text-primary;
      }

      .modal-close {
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background-color: $bg-section;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: $font-size-base;
        color: $text-secondary;
        transition: all $duration-base $ease-out;

        &:active {
          background-color: $bg-disabled;
        }
      }
    }

    .category-list {
      max-height: 500rpx;
      overflow-y: auto;
      padding: $spacing-md;

      .category-option {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: $spacing-base;
        border-radius: $radius-base;
        margin-bottom: $spacing-xs;
        transition: all $duration-base $ease-out;

        &:active {
          background-color: $bg-section;
        }

        &.active {
          background-color: rgba(255, 138, 101, 0.1);

          .category-name {
            color: $primary;
            font-weight: $font-weight-bold;
          }
        }

        .category-name {
          font-size: $font-size-base;
          color: $text-primary;
        }

        .check-icon {
          font-size: $font-size-md;
          color: $primary;
          font-weight: $font-weight-bold;
        }
      }
    }
  }
}
</style>
