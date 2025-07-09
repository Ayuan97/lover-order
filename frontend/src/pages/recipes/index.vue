<template>
  <view class="recipes-page">
    <view class="page-header">
      <text class="page-title">菜谱管理</text>
    </view>

    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading">
      <text class="loading-text">加载中...</text>
    </view>

    <!-- 无家庭状态 -->
    <view class="no-family-state" v-else-if="!hasFamily">
      <text class="state-icon">🏠</text>
      <text class="state-title">需要先加入家庭</text>
      <text class="state-desc">菜谱功能需要在家庭中使用，请先创建或加入一个家庭</text>
      <button class="btn btn-primary" @click="goToFamily">
        前往家庭管理
      </button>
    </view>

    <!-- 菜谱列表 -->
    <view class="content" v-else>
      <!-- 空状态 -->
      <view class="empty-state" v-if="recipes.length === 0">
        <text class="empty-icon">📖</text>
        <text class="empty-text">暂无菜谱</text>
        <text class="empty-desc">快来添加第一个菜谱吧</text>
        <button class="btn btn-primary" @click="addRecipe">
          添加菜谱
        </button>
      </view>

      <!-- 菜谱列表 -->
      <view class="recipes-list" v-else>
        <view
          class="recipe-item card"
          v-for="recipe in recipes"
          :key="recipe.id"
          @click="viewRecipe(recipe)"
        >
          <image
            class="recipe-image"
            :src="recipe.image || defaultRecipeImage"
            mode="aspectFill"
          />
          <view class="recipe-info">
            <text class="recipe-name">{{ recipe.name }}</text>
            <text class="recipe-desc">{{ recipe.description || '暂无描述' }}</text>
            <view class="recipe-meta">
              <text class="recipe-category">{{ recipe.category_name }}</text>
              <text class="recipe-time">{{ recipe.cooking_time }}分钟</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 添加按钮 -->
      <view class="fab-container">
        <button class="fab" @click="addRecipe">
          <text class="fab-icon">+</text>
        </button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { FamilyService } from '@/api/family'

// 响应式数据
const isLoading = ref(true)
const hasFamily = ref(false)
const recipes = ref([])

// 默认菜谱图片
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 页面加载
onMounted(async () => {
  await checkFamilyStatus()
})

// 检查家庭状态
const checkFamilyStatus = async () => {
  try {
    isLoading.value = true
    hasFamily.value = FamilyService.hasFamily()

    if (hasFamily.value) {
      await loadRecipes()
    }
  } catch (error) {
    console.error('检查家庭状态失败:', error)
  } finally {
    isLoading.value = false
  }
}

// 加载菜谱列表
const loadRecipes = async () => {
  try {
    // TODO: 实现菜谱列表API调用
    // const recipeList = await RecipeService.getRecipeList()
    // recipes.value = recipeList

    // 临时数据
    recipes.value = []
  } catch (error) {
    console.error('加载菜谱失败:', error)
    uni.showToast({
      title: '加载失败',
      icon: 'error'
    })
  }
}

// 前往家庭管理
const goToFamily = () => {
  uni.navigateTo({
    url: '/pages/family/index'
  })
}

// 添加菜谱
const addRecipe = () => {
  uni.navigateTo({
    url: '/pages/recipes/add'
  })
}

// 查看菜谱详情
const viewRecipe = (recipe: any) => {
  uni.navigateTo({
    url: `/pages/recipes/detail?id=${recipe.id}`
  })
}
</script>

<style lang="scss" scoped>
.recipes-page {
  padding: 24rpx;
  min-height: 100vh;
  background-color: #FAFAFA;
}

.page-header {
  margin-bottom: 32rpx;
}

.page-title {
  font-size: 36rpx;
  font-weight: bold;
  color: #424242;
}

.card {
  background-color: #fff;
  border-radius: 12rpx;
  box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.1);
  margin-bottom: 24rpx;
}

// 加载状态
.loading-state {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 120rpx 40rpx;

  .loading-text {
    font-size: 28rpx;
    color: #666;
  }
}

// 无家庭状态
.no-family-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 120rpx 40rpx;
  text-align: center;

  .state-icon {
    font-size: 120rpx;
    margin-bottom: 32rpx;
  }

  .state-title {
    font-size: 32rpx;
    font-weight: bold;
    color: #424242;
    margin-bottom: 16rpx;
  }

  .state-desc {
    font-size: 28rpx;
    color: #757575;
    line-height: 1.6;
    margin-bottom: 48rpx;
  }
}

.content {
  flex: 1;
  position: relative;
}

// 空状态
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 80rpx 32rpx;
  text-align: center;

  .empty-icon {
    font-size: 120rpx;
    margin-bottom: 32rpx;
    opacity: 0.6;
  }

  .empty-text {
    font-size: 32rpx;
    color: #424242;
    font-weight: bold;
    margin-bottom: 16rpx;
  }

  .empty-desc {
    font-size: 28rpx;
    color: #666;
    line-height: 1.5;
    margin-bottom: 48rpx;
  }
}

// 菜谱列表
.recipes-list {
  .recipe-item {
    padding: 24rpx;
    display: flex;
    align-items: center;

    .recipe-image {
      width: 120rpx;
      height: 120rpx;
      border-radius: 12rpx;
      margin-right: 24rpx;
    }

    .recipe-info {
      flex: 1;

      .recipe-name {
        display: block;
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
        margin-bottom: 8rpx;
      }

      .recipe-desc {
        display: block;
        font-size: 24rpx;
        color: #666;
        margin-bottom: 12rpx;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .recipe-meta {
        display: flex;
        align-items: center;
        gap: 16rpx;

        .recipe-category {
          font-size: 20rpx;
          color: #FF8A65;
          background-color: #FFF3E0;
          padding: 4rpx 12rpx;
          border-radius: 12rpx;
        }

        .recipe-time {
          font-size: 20rpx;
          color: #999;
        }
      }
    }
  }
}

// 浮动添加按钮
.fab-container {
  position: fixed;
  bottom: 120rpx;
  right: 40rpx;
  z-index: 100;

  .fab {
    width: 112rpx;
    height: 112rpx;
    border-radius: 56rpx;
    background-color: #FF8A65;
    border: none;
    box-shadow: 0 8rpx 24rpx rgba(255, 138, 101, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;

    .fab-icon {
      font-size: 48rpx;
      color: white;
      font-weight: bold;
    }
  }
}

// 按钮样式
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 16rpx 32rpx;
  border-radius: 12rpx;
  font-size: 28rpx;
  font-weight: bold;
  border: none;
  transition: all 0.2s;

  &.btn-primary {
    background-color: #FF8A65;
    color: white;
  }
}
</style>
