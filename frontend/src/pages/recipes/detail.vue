<template>
  <view class="recipe-detail-page">
    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading">
      <text class="loading-text">加载中...</text>
    </view>

    <!-- 详情内容 -->
    <view class="detail-content" v-else-if="recipe">
      <!-- 菜谱图片 -->
      <view class="recipe-image-container">
        <image
          class="recipe-image"
          :src="recipe.image || defaultRecipeImage"
          mode="aspectFill"
        />
        <view class="image-overlay">
          <view class="recipe-category-badge">
            <text class="badge-text">{{ categoryName }}</text>
          </view>
        </view>
      </view>

      <!-- 菜谱基本信息 -->
      <view class="recipe-info card">
        <text class="recipe-name">{{ recipe.name }}</text>
        <text class="recipe-desc" v-if="recipe.description">{{ recipe.description }}</text>

        <view class="recipe-meta">
          <view class="meta-item">
            <text class="meta-icon">⏰</text>
            <text class="meta-label">烹饪时间</text>
            <text class="meta-value">{{ recipe.cooking_time }}分钟</text>
          </view>
          <view class="meta-divider"></view>
          <view class="meta-item">
            <text class="meta-icon">📊</text>
            <text class="meta-label">难度</text>
            <text class="meta-value">{{ difficultyText }}</text>
          </view>
          <view class="meta-divider"></view>
          <view class="meta-item">
            <text class="meta-icon">👨‍🍳</text>
            <text class="meta-label">创建者</text>
            <text class="meta-value">{{ recipe.creator_name || '未知' }}</text>
          </view>
        </view>
      </view>

      <!-- 食材列表 -->
      <view class="ingredients-section card" v-if="ingredients.length > 0">
        <view class="section-header">
          <text class="section-icon">🥕</text>
          <text class="section-title">食材清单</text>
        </view>

        <view class="ingredients-list">
          <view
            class="ingredient-item"
            v-for="(ingredient, index) in ingredients"
            :key="index"
          >
            <view class="ingredient-bullet"></view>
            <text class="ingredient-name">{{ ingredient.name }}</text>
            <text class="ingredient-amount">{{ ingredient.amount }}</text>
          </view>
        </view>
      </view>

      <!-- 烹饪步骤 -->
      <view class="steps-section card" v-if="steps.length > 0">
        <view class="section-header">
          <text class="section-icon">📝</text>
          <text class="section-title">烹饪步骤</text>
        </view>

        <view class="steps-list">
          <view
            class="step-item"
            v-for="(step, index) in steps"
            :key="index"
          >
            <view class="step-number">
              <text class="number-text">{{ index + 1 }}</text>
            </view>
            <view class="step-content">
              <text class="step-text">{{ step.content }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 创建时间 -->
      <view class="recipe-meta-info card">
        <view class="meta-info-item">
          <text class="info-label">创建时间</text>
          <text class="info-value">{{ formatDate(recipe.created_at) }}</text>
        </view>
        <view class="meta-info-item" v-if="recipe.updated_at !== recipe.created_at">
          <text class="info-label">更新时间</text>
          <text class="info-value">{{ formatDate(recipe.updated_at) }}</text>
        </view>
      </view>
    </view>

    <!-- 错误状态 -->
    <view class="error-state" v-else>
      <text class="error-icon">😞</text>
      <text class="error-text">菜谱加载失败</text>
      <button class="btn btn-primary" @click="loadRecipeDetail">
        重新加载
      </button>
    </view>

    <!-- 底部操作栏 -->
    <view class="footer-actions" v-if="recipe">
      <button class="action-btn favorite-btn" :class="{ active: isFavorite }" @click="toggleFavorite">
        <text class="btn-icon">{{ isFavorite ? '❤️' : '🤍' }}</text>
        <text class="btn-text">{{ isFavorite ? '已收藏' : '收藏' }}</text>
      </button>

      <button class="action-btn add-to-cart-btn" @click="addToCart">
        <text class="btn-icon">🛒</text>
        <text class="btn-text">加入订单</text>
      </button>

      <!-- 编辑和删除按钮（仅创建者可见） -->
      <button
        v-if="isCreator"
        class="action-btn edit-btn"
        @click="editRecipe"
      >
        <text class="btn-icon">✏️</text>
      </button>

      <button
        v-if="isCreator"
        class="action-btn delete-btn"
        @click="deleteRecipe"
      >
        <text class="btn-icon">🗑️</text>
      </button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { RecipeService, CategoryService, type Recipe } from '@/api/recipe'
import { AuthService } from '@/api/auth'

// 页面参数
const recipeId = ref<number>(0)

// 响应式数据
const isLoading = ref(true)
const recipe = ref<Recipe | null>(null)
const categories = ref<any[]>([])
const isFavorite = ref(false)

// 默认菜谱图片
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 计算属性
const categoryName = computed(() => {
  if (!recipe.value || !recipe.value.category_id) return '未分类'
  const category = categories.value.find(c => c.id === recipe.value.category_id)
  return category ? category.name : '未分类'
})

const difficultyText = computed(() => {
  if (!recipe.value) return '未知'
  const difficultyMap: { [key: number]: string } = {
    1: '简单',
    2: '中等',
    3: '困难'
  }
  return difficultyMap[recipe.value.difficulty] || '未知'
})

const ingredients = computed(() => {
  if (!recipe.value || !recipe.value.ingredients) return []
  try {
    return JSON.parse(recipe.value.ingredients)
  } catch (e) {
    console.error('解析食材失败:', e)
    return []
  }
})

const steps = computed(() => {
  if (!recipe.value || !recipe.value.steps) return []
  try {
    return JSON.parse(recipe.value.steps)
  } catch (e) {
    console.error('解析步骤失败:', e)
    return []
  }
})

const isCreator = computed(() => {
  if (!recipe.value) return false
  const currentUser = AuthService.getCurrentUser()
  return currentUser && currentUser.id === recipe.value.creator_id
})

// 页面加载
onLoad((options: any) => {
  console.log('菜谱详情页面加载，参数:', options)

  if (options.id) {
    recipeId.value = Number(options.id)
    loadRecipeDetail()
    loadCategories()
  } else {
    console.error('缺少菜谱ID参数')
    uni.showToast({
      title: '参数错误',
      icon: 'error'
    })
  }
})

// 加载分类数据
const loadCategories = async () => {
  try {
    const result = await CategoryService.getCategoryList()
    categories.value = result || []
  } catch (error: any) {
    console.error('加载分类失败:', error)
  }
}

// 加载菜谱详情
const loadRecipeDetail = async () => {
  try {
    isLoading.value = true
    console.log('加载菜谱详情，ID:', recipeId.value)

    const result = await RecipeService.getRecipeDetail(recipeId.value)
    recipe.value = result
    console.log('菜谱详情加载成功:', result)

    // TODO: 检查是否已收藏
    // isFavorite.value = await RecipeService.checkFavorite(recipeId.value)

  } catch (error: any) {
    console.error('加载菜谱详情失败:', error)
    uni.showToast({
      title: error.message || '加载失败',
      icon: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

// 格式化日期
const formatDate = (dateStr: string) => {
  const date = new Date(dateStr)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hour = String(date.getHours()).padStart(2, '0')
  const minute = String(date.getMinutes()).padStart(2, '0')
  return `${year}-${month}-${day} ${hour}:${minute}`
}

// 切换收藏
const toggleFavorite = async () => {
  try {
    if (isFavorite.value) {
      // TODO: 取消收藏
      // await RecipeService.removeFavorite(recipeId.value)
      isFavorite.value = false
      uni.showToast({
        title: '已取消收藏',
        icon: 'success'
      })
    } else {
      // TODO: 添加收藏
      // await RecipeService.addFavorite(recipeId.value)
      isFavorite.value = true
      uni.showToast({
        title: '收藏成功',
        icon: 'success'
      })
    }
  } catch (error: any) {
    console.error('收藏操作失败:', error)
    uni.showToast({
      title: error.message || '操作失败',
      icon: 'error'
    })
  }
}

// 加入购物车
const addToCart = () => {
  if (!recipe.value) return

  // 获取当前购物车
  let cart = uni.getStorageSync('shopping_cart') || []

  // 查找是否已存在
  const existingItem = cart.find((item: any) => item.id === recipe.value!.id)

  if (existingItem) {
    existingItem.quantity += 1
  } else {
    cart.push({
      ...recipe.value,
      quantity: 1,
      category_name: categoryName.value
    })
  }

  // 保存到本地存储
  uni.setStorageSync('shopping_cart', cart)

  uni.showToast({
    title: '已加入订单',
    icon: 'success',
    duration: 1500
  })
}

// 编辑菜谱
const editRecipe = () => {
  uni.navigateTo({
    url: `/pages/recipes/add?id=${recipeId.value}`
  })
}

// 删除菜谱
const deleteRecipe = () => {
  uni.showModal({
    title: '确认删除',
    content: '确定要删除这道菜谱吗？删除后无法恢复',
    confirmText: '确认删除',
    confirmColor: '#F44336',
    success: async (res) => {
      if (res.confirm) {
        try {
          await RecipeService.deleteRecipe(recipeId.value)

          uni.showToast({
            title: '删除成功',
            icon: 'success',
            duration: 1500
          })

          setTimeout(() => {
            uni.navigateBack()
          }, 1500)

        } catch (error: any) {
          console.error('删除菜谱失败:', error)
          uni.showToast({
            title: error.message || '删除失败',
            icon: 'error'
          })
        }
      }
    }
  })
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.recipe-detail-page {
  min-height: 100vh;
  background-color: $bg-page;
  padding-bottom: 160rpx;
}

// 加载状态
.loading-state {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 200rpx 40rpx;

  .loading-text {
    font-size: $font-size-base;
    color: $text-secondary;
  }
}

// 错误状态
.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 200rpx 40rpx;
  text-align: center;

  .error-icon {
    font-size: 120rpx;
    margin-bottom: $spacing-lg;
    opacity: 0.6;
  }

  .error-text {
    font-size: $font-size-lg;
    color: $text-primary;
    font-weight: $font-weight-bold;
    margin-bottom: $spacing-xl;
  }

  .btn {
    padding: $spacing-base $spacing-xl;
    background: $gradient-primary;
    color: white;
    border: none;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    box-shadow: $shadow-primary;
    transition: all $duration-base $ease-out;

    &:active {
      transform: scale(0.96);
    }
  }
}

// 详情内容
.detail-content {
  .card {
    background-color: $bg-card;
    border-radius: $radius-lg;
    padding: $spacing-lg;
    margin: 0 $spacing-base $spacing-base;
    box-shadow: $shadow-base;
  }
}

// 菜谱图片
.recipe-image-container {
  position: relative;
  width: 100%;
  height: 500rpx;
  overflow: hidden;

  .recipe-image {
    width: 100%;
    height: 100%;
  }

  .image-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(to bottom, rgba(0,0,0,0.1) 0%, transparent 50%);
    padding: $spacing-lg;
    display: flex;
    flex-direction: column;
    justify-content: space-between;

    .recipe-category-badge {
      align-self: flex-start;
      padding: $spacing-xs $spacing-md;
      background-color: rgba(255, 138, 101, 0.9);
      backdrop-filter: blur(10rpx);
      border-radius: $radius-button;

      .badge-text {
        font-size: $font-size-xs;
        color: white;
        font-weight: $font-weight-bold;
      }
    }
  }
}

// 菜谱基本信息
.recipe-info {
  .recipe-name {
    display: block;
    font-size: $font-size-xxl;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: $spacing-sm;
    line-height: $line-height-tight;
  }

  .recipe-desc {
    display: block;
    font-size: $font-size-base;
    color: $text-secondary;
    line-height: $line-height-base;
    margin-bottom: $spacing-lg;
  }

  .recipe-meta {
    display: flex;
    align-items: center;
    background-color: $bg-section;
    padding: $spacing-base;
    border-radius: $radius-md;

    .meta-item {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;

      .meta-icon {
        font-size: $font-size-lg;
        margin-bottom: $spacing-xs;
      }

      .meta-label {
        font-size: $font-size-xxs;
        color: $text-tertiary;
        margin-bottom: 4rpx;
      }

      .meta-value {
        font-size: $font-size-sm;
        color: $text-primary;
        font-weight: $font-weight-bold;
      }
    }

    .meta-divider {
      width: 1rpx;
      height: 60rpx;
      background-color: $border-light;
    }
  }
}

// 区块样式
.ingredients-section,
.steps-section {
  .section-header {
    display: flex;
    align-items: center;
    gap: $spacing-sm;
    margin-bottom: $spacing-lg;

    .section-icon {
      font-size: $font-size-xl;
    }

    .section-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }
}

// 食材列表
.ingredients-list {
  .ingredient-item {
    display: flex;
    align-items: center;
    padding: $spacing-md 0;
    border-bottom: 1rpx solid $border-light;

    &:last-child {
      border-bottom: none;
    }

    .ingredient-bullet {
      width: 8rpx;
      height: 8rpx;
      background-color: $primary;
      border-radius: 4rpx;
      margin-right: $spacing-md;
      flex-shrink: 0;
    }

    .ingredient-name {
      flex: 2;
      font-size: $font-size-base;
      color: $text-primary;
    }

    .ingredient-amount {
      flex: 1;
      font-size: $font-size-sm;
      color: $text-secondary;
      text-align: right;
    }
  }
}

// 步骤列表
.steps-list {
  .step-item {
    display: flex;
    align-items: flex-start;
    gap: $spacing-md;
    padding: $spacing-base 0;

    &:not(:last-child) {
      border-bottom: 1rpx solid $border-light;
      padding-bottom: $spacing-lg;
      margin-bottom: $spacing-base;
    }

    .step-number {
      width: 56rpx;
      height: 56rpx;
      background: $gradient-primary;
      border-radius: 28rpx;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      box-shadow: $shadow-primary;

      .number-text {
        font-size: $font-size-md;
        color: white;
        font-weight: $font-weight-bold;
      }
    }

    .step-content {
      flex: 1;
      padding-top: 8rpx;

      .step-text {
        font-size: $font-size-base;
        color: $text-primary;
        line-height: $line-height-relaxed;
      }
    }
  }
}

// 元信息
.recipe-meta-info {
  .meta-info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: $spacing-sm 0;

    &:not(:last-child) {
      border-bottom: 1rpx solid $border-light;
      padding-bottom: $spacing-md;
      margin-bottom: $spacing-sm;
    }

    .info-label {
      font-size: $font-size-sm;
      color: $text-secondary;
    }

    .info-value {
      font-size: $font-size-sm;
      color: $text-primary;
      font-family: 'Courier New', monospace;
    }
  }
}

// 底部操作栏
.footer-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  gap: $spacing-sm;
  padding: $spacing-base;
  background-color: white;
  border-top: 1rpx solid $border-light;
  box-shadow: 0 -4rpx 12rpx rgba(0, 0, 0, 0.05);
  z-index: 100;

  .action-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4rpx;
    height: 100rpx;
    border-radius: $radius-md;
    font-size: $font-size-xs;
    font-weight: $font-weight-medium;
    border: none;
    transition: all $duration-base $ease-out;

    &:active {
      transform: scale(0.96);
    }

    .btn-icon {
      font-size: $font-size-xl;
    }

    .btn-text {
      font-size: $font-size-xs;
    }

    &.favorite-btn {
      flex: 1;
      background-color: $bg-section;
      color: $text-secondary;

      &.active {
        background-color: rgba(255, 138, 101, 0.1);
        color: $primary;

        .btn-icon {
          animation: pulse 0.3s ease-out;
        }
      }

      &:active {
        background-color: $bg-disabled;
      }
    }

    &.add-to-cart-btn {
      flex: 2;
      background: $gradient-primary;
      color: white;
      box-shadow: $shadow-primary;
      flex-direction: row;
      gap: $spacing-xs;

      .btn-text {
        font-size: $font-size-base;
      }

      &:active {
        box-shadow: $shadow-primary-hover;
      }
    }

    &.edit-btn,
    &.delete-btn {
      width: 100rpx;
      background-color: $bg-section;

      .btn-icon {
        font-size: $font-size-lg;
      }

      &:active {
        background-color: $bg-disabled;
      }
    }

    &.delete-btn {
      .btn-icon {
        color: $danger;
      }

      &:active {
        background-color: rgba(244, 67, 54, 0.1);
      }
    }
  }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.2); }
}
</style>
