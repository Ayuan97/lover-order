<template>
  <view class="favorites-page">
    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading">
      <text class="loading-text">加载中...</text>
    </view>

    <!-- 收藏列表 -->
    <view class="favorites-list" v-else-if="favoriteRecipes.length > 0">
      <view
        class="recipe-card"
        v-for="recipe in favoriteRecipes"
        :key="recipe.id"
        @click="viewRecipeDetail(recipe)"
      >
        <image
          v-if="recipe.image"
          class="recipe-image"
          :src="recipe.image"
          mode="aspectFill"
        />
        <view v-else class="recipe-image placeholder">
          <text class="placeholder-emoji">🍽️</text>
        </view>

        <view class="recipe-info">
          <text class="recipe-name">{{ recipe.name }}</text>
          <text class="recipe-desc" v-if="recipe.description">{{ recipe.description }}</text>

          <view class="recipe-meta">
            <view class="meta-item" v-if="recipe.cooking_time">
              <text class="meta-icon">⏱️</text>
              <text class="meta-text">{{ recipe.cooking_time }}分钟</text>
            </view>
            <view class="meta-item" v-if="recipe.difficulty">
              <text class="meta-icon">📊</text>
              <text class="meta-text">{{ getDifficultyText(recipe.difficulty) }}</text>
            </view>
          </view>
        </view>

        <view class="recipe-actions">
          <button class="action-btn unfavorite" @click.stop="toggleFavorite(recipe)">
            <text class="btn-icon">❤️</text>
          </button>
          <button class="action-btn add-cart" @click.stop="addToCart(recipe)">
            <text class="btn-icon">🛒</text>
          </button>
        </view>
      </view>
    </view>

    <!-- 空状态 -->
    <view class="empty-state" v-else>
      <text class="empty-icon">❤️</text>
      <text class="empty-title">还没有收藏</text>
      <text class="empty-desc">去菜谱页面收藏喜欢的菜品吧～</text>
      <button class="browse-btn" @click="goToRecipes">
        <text class="btn-text">浏览菜谱</text>
      </button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { RecipeService, type Recipe } from '@/api/recipe'

// 状态
const isLoading = ref(true)
const favoriteRecipes = ref<Recipe[]>([])

// 页面加载
onMounted(async () => {
  await loadFavorites()
})

// 页面显示时刷新
onShow(async () => {
  if (!isLoading.value) {
    await loadFavorites()
  }
})

// 加载收藏列表
const loadFavorites = async () => {
  try {
    isLoading.value = true
    const response = await RecipeService.getFavoriteRecipes()
    favoriteRecipes.value = response.list || []
  } catch (error) {
    console.error('加载收藏失败:', error)
    uni.showToast({
      title: '加载失败',
      icon: 'none'
    })
  } finally {
    isLoading.value = false
  }
}

// 查看菜谱详情
const viewRecipeDetail = (recipe: Recipe) => {
  uni.navigateTo({
    url: `/pages/recipes/detail?id=${recipe.id}`
  })
}

// 取消收藏
const toggleFavorite = async (recipe: Recipe) => {
  try {
    await RecipeService.toggleFavorite(recipe.id)
    // 从列表中移除
    favoriteRecipes.value = favoriteRecipes.value.filter(r => r.id !== recipe.id)
    uni.showToast({
      title: '已取消收藏',
      icon: 'success'
    })
  } catch (error) {
    console.error('取消收藏失败:', error)
    uni.showToast({
      title: '操作失败',
      icon: 'none'
    })
  }
}

// 加入购物车
const addToCart = (recipe: Recipe) => {
  try {
    // 获取本地购物车
    const cartData = uni.getStorageSync('shopping_cart') || []

    // 检查是否已在购物车
    const existingIndex = cartData.findIndex((item: any) => item.recipe_id === recipe.id)

    if (existingIndex >= 0) {
      // 已存在，增加数量
      cartData[existingIndex].quantity += 1
    } else {
      // 不存在，添加新项
      cartData.push({
        recipe_id: recipe.id,
        recipe_name: recipe.name,
        recipe_image: recipe.image || '',
        quantity: 1,
        unit_price: recipe.price || 0
      })
    }

    uni.setStorageSync('shopping_cart', cartData)
    uni.showToast({
      title: '已加入购物车',
      icon: 'success'
    })
  } catch (error) {
    console.error('加入购物车失败:', error)
    uni.showToast({
      title: '操作失败',
      icon: 'none'
    })
  }
}

// 获取难度文本
const getDifficultyText = (difficulty: string) => {
  const map: Record<string, string> = {
    easy: '简单',
    medium: '中等',
    hard: '困难'
  }
  return map[difficulty] || difficulty
}

// 跳转到菜谱页面
const goToRecipes = () => {
  uni.switchTab({
    url: '/pages/recipes/index'
  })
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.favorites-page {
  min-height: 100vh;
  background: $bg-page;
  padding: 24rpx;
  padding-bottom: calc(24rpx + env(safe-area-inset-bottom));
}

// 加载状态
.loading-state {
  @include flex-center;
  padding: 120rpx;

  .loading-text {
    font-size: $font-size-base;
    color: $text-tertiary;
  }
}

// 收藏列表
.favorites-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

// 菜谱卡片
.recipe-card {
  display: flex;
  gap: 16rpx;
  background: white;
  border-radius: $radius-lg;
  padding: 16rpx;
  box-shadow: $shadow-base;

  .recipe-image {
    width: 160rpx;
    height: 160rpx;
    border-radius: $radius-md;
    flex-shrink: 0;

    &.placeholder {
      background: $bg-section;
      @include flex-center;

      .placeholder-emoji {
        font-size: 48rpx;
      }
    }
  }

  .recipe-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;

    .recipe-name {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
      margin-bottom: 8rpx;
      @include text-ellipsis(1);
    }

    .recipe-desc {
      font-size: $font-size-sm;
      color: $text-secondary;
      margin-bottom: 12rpx;
      @include text-ellipsis(2);
    }

    .recipe-meta {
      display: flex;
      gap: 16rpx;
      margin-top: auto;

      .meta-item {
        display: flex;
        align-items: center;
        gap: 4rpx;

        .meta-icon {
          font-size: 24rpx;
        }

        .meta-text {
          font-size: $font-size-xs;
          color: $text-tertiary;
        }
      }
    }
  }

  .recipe-actions {
    display: flex;
    flex-direction: column;
    gap: 12rpx;
    justify-content: center;

    .action-btn {
      width: 64rpx;
      height: 64rpx;
      border-radius: 50%;
      border: none;
      @include flex-center;
      transition: all $duration-fast;

      &.unfavorite {
        background: rgba($error, 0.1);
      }

      &.add-cart {
        background: rgba($primary, 0.1);
      }

      &:active {
        transform: scale(0.9);
      }

      .btn-icon {
        font-size: 28rpx;
      }
    }
  }
}

// 空状态
.empty-state {
  @include flex-center;
  flex-direction: column;
  padding: 120rpx 40rpx;
  text-align: center;

  .empty-icon {
    font-size: 120rpx;
    margin-bottom: 24rpx;
    opacity: 0.5;
  }

  .empty-title {
    font-size: $font-size-xl;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: 12rpx;
  }

  .empty-desc {
    font-size: $font-size-base;
    color: $text-secondary;
    margin-bottom: 32rpx;
  }

  .browse-btn {
    padding: 16rpx 48rpx;
    background: $gradient-primary;
    color: white;
    border: none;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    box-shadow: $shadow-primary;

    &:active {
      transform: scale(0.95);
    }
  }
}
</style>
