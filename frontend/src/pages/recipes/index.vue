<template>
  <view class="recipes-page">
    <!-- 顶部搜索栏 -->
    <view class="top-search-bar">
      <view class="search-input-wrapper">
        <text class="search-icon">🔍</text>
        <input
          class="search-input"
          v-model="searchKeyword"
          placeholder="搜索菜谱..."
          @input="onSearch"
        />
        <text class="clear-icon" v-if="searchKeyword" @click="clearSearch">✕</text>
      </view>
      <view class="filter-btn" @click="showFilterModal = true">
        <text class="filter-icon">🎛️</text>
      </view>
    </view>

    <!-- 分类标签栏 -->
    <scroll-view class="categories-bar" scroll-x :show-scrollbar="false" v-if="hasFamily">
      <view
        class="category-chip"
        :class="{ active: activeCategory === null }"
        @click="selectCategory(null)"
      >
        <text class="chip-text">全部</text>
      </view>
      <view
        class="category-chip"
        :class="{ active: activeCategory === category.id }"
        v-for="category in categories"
        :key="category.id"
        @click="selectCategory(category.id)"
      >
        <text class="chip-text">{{ category.name }}</text>
      </view>
    </scroll-view>

    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading && recipes.length === 0">
      <view class="loading-spinner"></view>
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

    <!-- 菜谱网格（Pinterest 风格） -->
    <scroll-view
      class="recipes-grid-scroll"
      scroll-y
      refresher-enabled
      :refresher-triggered="isRefreshing"
      @refresherrefresh="onRefresh"
      v-else
    >
      <!-- 空状态 -->
      <view class="empty-state" v-if="filteredRecipes.length === 0">
        <text class="empty-icon">📖</text>
        <text class="empty-text">{{ emptyText }}</text>
        <text class="empty-desc">{{ emptyDesc }}</text>
        <button class="btn btn-primary" @click="addRecipe" v-if="recipes.length === 0">
          添加第一个菜谱
        </button>
      </view>

      <!-- Pinterest 风格网格 -->
      <view class="recipes-grid" v-else>
        <view
          class="recipe-card"
          v-for="recipe in filteredRecipes"
          :key="recipe.id"
          @click="viewRecipe(recipe)"
        >
          <!-- 菜品图片 -->
          <view class="card-image-wrapper">
            <image
              class="card-image"
              :src="recipe.image || defaultRecipeImage"
              mode="aspectFill"
            />
            <!-- 浮动标签 -->
            <view class="image-badges">
              <view class="badge difficulty">{{ getDifficultyText(recipe.difficulty) }}</view>
              <view class="badge time">⏱️ {{ recipe.cooking_time }}分钟</view>
            </view>
          </view>

          <!-- 卡片内容 -->
          <view class="card-content">
            <!-- 标题 -->
            <text class="card-title">{{ recipe.name }}</text>

            <!-- 描述 -->
            <text class="card-desc" v-if="recipe.description">{{ recipe.description }}</text>

            <!-- 分类标签 -->
            <view class="card-tags">
              <text class="tag-item">{{ recipe.category_name }}</text>
            </view>

            <!-- 互动栏 -->
            <view class="card-interactions">
              <view class="interaction-left">
                <view class="creator-info">
                  <view class="creator-avatar">
                    <text class="avatar-text">{{ recipe.creator_name?.charAt(0) || '?' }}</text>
                  </view>
                  <text class="creator-name">{{ recipe.creator_name || '匿名' }}</text>
                </view>
              </view>
              <view class="interaction-right">
                <view class="action-btn" @click.stop="toggleFavorite(recipe)">
                  <text class="action-icon">{{ recipe.is_favorite ? '❤️' : '🤍' }}</text>
                </view>
                <view class="action-btn" @click.stop="addToCart(recipe)">
                  <text class="action-icon">🛒</text>
                </view>
              </view>
            </view>
          </view>
        </view>
      </view>
    </scroll-view>

    <!-- 浮动按钮组 -->
    <view class="fab-container" v-if="hasFamily">
      <!-- 购物车按钮 -->
      <view class="fab fab-cart" @click="showCartModal = true" v-if="cartItemCount > 0">
        <text class="fab-icon">🛒</text>
        <view class="cart-badge">{{ cartItemCount }}</view>
      </view>
      <!-- 添加菜谱按钮 -->
      <button class="fab fab-add" @click="addRecipe">
        <text class="fab-icon">+</text>
      </button>
    </view>

    <!-- 购物车弹窗 -->
    <view class="cart-modal-mask" v-if="showCartModal" @click="showCartModal = false">
      <view class="cart-modal" @click.stop>
        <!-- 弹窗头部 -->
        <view class="cart-header">
          <text class="cart-title">🛒 我的购物车</text>
          <view class="cart-actions">
            <text class="clear-btn" @click="clearCart" v-if="cartItems.length > 0">清空</text>
            <text class="close-btn" @click="showCartModal = false">✕</text>
          </view>
        </view>

        <!-- 购物车内容 -->
        <scroll-view class="cart-content" scroll-y v-if="cartItems.length > 0">
          <view class="cart-item" v-for="item in cartItems" :key="item.id">
            <image class="item-image" :src="item.image || defaultRecipeImage" mode="aspectFill" />
            <view class="item-info">
              <text class="item-name">{{ item.name }}</text>
              <text class="item-time">⏱️ {{ item.cooking_time }}分钟</text>
            </view>
            <view class="item-quantity">
              <view class="qty-btn" @click="decreaseQty(item)">
                <text>-</text>
              </view>
              <text class="qty-num">{{ item.quantity }}</text>
              <view class="qty-btn" @click="increaseQty(item)">
                <text>+</text>
              </view>
            </view>
            <view class="item-delete" @click="removeFromCart(item)">
              <text>🗑️</text>
            </view>
          </view>
        </scroll-view>

        <!-- 空购物车 -->
        <view class="cart-empty" v-else>
          <text class="empty-icon">🛒</text>
          <text class="empty-text">购物车是空的</text>
          <text class="empty-desc">去添加一些想吃的菜吧～</text>
        </view>

        <!-- 底部操作栏 -->
        <view class="cart-footer" v-if="cartItems.length > 0">
          <view class="cart-summary">
            <text class="summary-label">共 {{ cartItemCount }} 道菜</text>
            <text class="summary-time">预计 {{ totalCookingTime }} 分钟</text>
          </view>
          <button class="checkout-btn" @click="goToCheckout">
            去下单
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { FamilyService } from '@/api/family'
import { RecipeService, CategoryService, type Recipe } from '@/api/recipe'

// 响应式数据
const isLoading = ref(true)
const isRefreshing = ref(false)
const hasFamily = ref(false)
const recipes = ref<Recipe[]>([])
const categories = ref<any[]>([])

// 搜索和筛选
const searchKeyword = ref('')
const activeCategory = ref<number | null>(null)
const showFilterModal = ref(false)

// 购物车相关
const showCartModal = ref(false)
const cartItems = ref<any[]>([])

// 购物车计算属性
const cartItemCount = computed(() => {
  return cartItems.value.reduce((sum, item) => sum + item.quantity, 0)
})

const totalCookingTime = computed(() => {
  return cartItems.value.reduce((sum, item) => sum + (item.cooking_time || 0) * item.quantity, 0)
})

// 默认菜谱图片
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 计算属性 - 筛选后的菜谱
const filteredRecipes = computed(() => {
  let result = recipes.value

  // 分类筛选
  if (activeCategory.value !== null) {
    result = result.filter(r => r.category_id === activeCategory.value)
  }

  // 关键词搜索
  if (searchKeyword.value.trim()) {
    const keyword = searchKeyword.value.toLowerCase()
    result = result.filter(r =>
      r.name.toLowerCase().includes(keyword) ||
      r.description?.toLowerCase().includes(keyword)
    )
  }

  return result
})

// 空状态文本
const emptyText = computed(() => {
  if (searchKeyword.value) {
    return '没有找到相关菜谱'
  }
  if (activeCategory.value !== null) {
    return '这个分类还没有菜谱'
  }
  return '暂无菜谱'
})

const emptyDesc = computed(() => {
  if (searchKeyword.value) {
    return '试试其他关键词吧'
  }
  if (activeCategory.value !== null) {
    return '快来添加第一个菜谱'
  }
  return '快来添加第一个菜谱吧'
})

// 页面加载
onMounted(async () => {
  loadCart()
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

// 加载分类数据
const loadCategories = async () => {
  try {
    console.log('开始加载分类...')
    const result = await CategoryService.getCategoryList()
    categories.value = result || []
    console.log('分类加载成功:', categories.value.length)
  } catch (error: any) {
    console.error('加载分类失败:', error)
    categories.value = []
  }
}

// 加载菜谱列表
const loadRecipes = async () => {
  try {
    console.log('开始加载菜谱列表...')

    // 并行加载分类和菜谱
    const [categoriesResult, recipesResult] = await Promise.allSettled([
      loadCategories(),
      RecipeService.getRecipeList({
        page: 1,
        page_size: 100
      })
    ])

    // 处理分类加载结果
    if (categoriesResult.status === 'rejected') {
      console.error('加载分类失败:', categoriesResult.reason)
    }

    // 处理菜谱加载结果
    if (recipesResult.status === 'fulfilled') {
      recipes.value = recipesResult.value.recipes || []
      console.log('菜谱加载成功:', recipes.value.length, '道菜品')

      // 为每个菜谱添加分类名称
      recipes.value.forEach((recipe: any) => {
        const category = categories.value.find(c => c.id === recipe.category_id)
        recipe.category_name = category ? category.name : '未分类'
      })
    } else {
      console.error('加载菜谱失败:', recipesResult.reason)
      recipes.value = []

      // 如果是权限问题，不显示错误提示（用户可能没有菜谱）
      const error = recipesResult.reason as any
      if (error?.statusCode !== 403 && error?.statusCode !== 400) {
        uni.showToast({
          title: '加载失败',
          icon: 'error'
        })
      }
    }
  } catch (error: any) {
    console.error('加载菜谱失败:', error)
    recipes.value = []

    // 只在非权限错误时显示错误提示
    if (error?.statusCode !== 403 && error?.statusCode !== 400) {
      uni.showToast({
        title: '加载失败',
        icon: 'error'
      })
    }
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

// 搜索
const onSearch = () => {
  // 搜索逻辑在 computed 中处理
}

// 清空搜索
const clearSearch = () => {
  searchKeyword.value = ''
}

// 选择分类
const selectCategory = (categoryId: number | null) => {
  activeCategory.value = categoryId
}

// 下拉刷新
const onRefresh = async () => {
  isRefreshing.value = true
  await loadRecipes()
  setTimeout(() => {
    isRefreshing.value = false
    uni.showToast({
      title: '刷新成功',
      icon: 'success',
      duration: 1000
    })
  }, 500)
}

// 收藏/取消收藏
const toggleFavorite = async (recipe: any) => {
  try {
    if (recipe.is_favorite) {
      // 取消收藏
      await RecipeService.unfavoriteRecipe(recipe.id)
      recipe.is_favorite = false
      uni.showToast({
        title: '已取消收藏',
        icon: 'none',
        duration: 800
      })
    } else {
      // 收藏
      await RecipeService.favoriteRecipe(recipe.id)
      recipe.is_favorite = true
      uni.showToast({
        title: '已收藏',
        icon: 'success',
        duration: 800
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

// 添加到购物车
const addToCart = (recipe: any) => {
  try {
    // 检查是否已存在
    const existingItem = cartItems.value.find((item: any) => item.id === recipe.id)

    if (existingItem) {
      // 已存在，增加数量
      existingItem.quantity += 1
      uni.showToast({
        title: `${recipe.name} +1`,
        icon: 'success',
        duration: 800
      })
    } else {
      // 新添加
      cartItems.value.push({
        id: recipe.id,
        name: recipe.name,
        description: recipe.description,
        image: recipe.image,
        cooking_time: recipe.cooking_time,
        difficulty: recipe.difficulty,
        quantity: 1
      })
      uni.showToast({
        title: `已添加 ${recipe.name}`,
        icon: 'success',
        duration: 800
      })
    }

    // 保存购物车
    saveCart()
  } catch (error) {
    console.error('添加到购物车失败:', error)
    uni.showToast({
      title: '添加失败',
      icon: 'error'
    })
  }
}

// 增加数量
const increaseQty = (item: any) => {
  item.quantity += 1
  saveCart()
}

// 减少数量
const decreaseQty = (item: any) => {
  if (item.quantity > 1) {
    item.quantity -= 1
    saveCart()
  } else {
    removeFromCart(item)
  }
}

// 从购物车移除
const removeFromCart = (item: any) => {
  const index = cartItems.value.findIndex((i: any) => i.id === item.id)
  if (index > -1) {
    cartItems.value.splice(index, 1)
    saveCart()
    uni.showToast({
      title: '已移除',
      icon: 'none',
      duration: 800
    })
  }
}

// 清空购物车
const clearCart = () => {
  uni.showModal({
    title: '清空购物车',
    content: '确定要清空购物车吗？',
    success: (res) => {
      if (res.confirm) {
        cartItems.value = []
        saveCart()
        uni.showToast({
          title: '已清空',
          icon: 'none',
          duration: 800
        })
      }
    }
  })
}

// 保存购物车到本地存储
const saveCart = () => {
  uni.setStorageSync('shopping_cart', cartItems.value)
}

// 加载购物车
const loadCart = () => {
  const cart = uni.getStorageSync('shopping_cart') || []
  cartItems.value = cart
}

// 去下单
const goToCheckout = () => {
  showCartModal.value = false
  uni.navigateTo({
    url: '/pages/orders/create'
  })
}

// 获取难度文本
const getDifficultyText = (difficulty: number) => {
  const difficultyMap: { [key: number]: string } = {
    1: '简单',
    2: '中等',
    3: '困难'
  }
  return difficultyMap[difficulty] || '未知'
}

// 页面显示时刷新数据（从详情页返回时）
onShow(async () => {
  console.log('菜谱页面显示，检查是否需要刷新...')

  // 加载购物车（从下单页返回时可能已清空）
  loadCart()

  // 如果正在初始加载，跳过
  if (isLoading.value) {
    console.log('页面正在初始加载，跳过 onShow 刷新')
    return
  }

  // 如果有家庭，刷新菜谱列表
  if (hasFamily.value) {
    console.log('刷新菜谱列表...')
    await loadRecipes()
  }
})
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.recipes-page {
  min-height: 100vh;
  background: linear-gradient(180deg, #FAFAFA 0%, #FFFFFF 100%);
  padding-bottom: 40rpx;
}

// 顶部搜索栏
.top-search-bar {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10rpx);
  border-bottom: 1rpx solid rgba(0, 0, 0, 0.05);
  padding: 20rpx 24rpx;
  display: flex;
  align-items: center;
  gap: 12rpx;

  .search-input-wrapper {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
    background: $bg-section;
    border-radius: 40rpx;
    padding: 12rpx 20rpx;

    .search-icon {
      font-size: 28rpx;
      margin-right: 12rpx;
    }

    .search-input {
      flex: 1;
      font-size: $font-size-sm;
      color: $text-primary;
      background: transparent;
      border: none;

      &::placeholder {
        color: $text-placeholder;
      }
    }

    .clear-icon {
      width: 32rpx;
      height: 32rpx;
      border-radius: 16rpx;
      background: $text-tertiary;
      color: white;
      font-size: 20rpx;
      @include flex-center;
      transition: all $duration-fast;

      &:active {
        transform: scale(0.9);
      }
    }
  }

  .filter-btn {
    width: 56rpx;
    height: 56rpx;
    border-radius: 28rpx;
    background: $bg-section;
    @include flex-center;
    transition: all $duration-fast;

    &:active {
      transform: scale(0.9);
      background: $bg-hover;
    }

    .filter-icon {
      font-size: 28rpx;
    }
  }
}

// 分类标签栏
.categories-bar {
  padding: 20rpx 24rpx;
  border-bottom: 1rpx solid rgba(0, 0, 0, 0.05);
  white-space: nowrap;
  background: white;

  .category-chip {
    display: inline-flex;
    align-items: center;
    padding: 12rpx 24rpx;
    margin-right: 16rpx;
    border-radius: 40rpx;
    background: $bg-section;
    transition: all $duration-base;

    &.active {
      background: $gradient-primary;
      box-shadow: $shadow-primary;

      .chip-text {
        color: white;
        font-weight: $font-weight-bold;
      }
    }

    .chip-text {
      font-size: $font-size-sm;
      color: $text-secondary;
      transition: all $duration-base;
    }

    &:active {
      transform: scale(0.95);
    }
  }
}

// 加载状态
.loading-state {
  @include flex-center;
  flex-direction: column;
  padding: 120rpx 40rpx;

  .loading-spinner {
    width: 60rpx;
    height: 60rpx;
    border-radius: 50%;
    border: 4rpx solid $bg-section;
    border-top-color: $primary;
    animation: spin 0.8s linear infinite;
    margin-bottom: 20rpx;
  }

  .loading-text {
    font-size: $font-size-sm;
    color: $text-tertiary;
  }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

// 无家庭状态
.no-family-state {
  @include flex-center;
  flex-direction: column;
  padding: 120rpx 40rpx;
  text-align: center;

  .state-icon {
    font-size: 120rpx;
    margin-bottom: $spacing-xl;
    opacity: 0.8;
  }

  .state-title {
    font-size: $font-size-lg;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: $spacing-md;
  }

  .state-desc {
    font-size: $font-size-sm;
    color: $text-secondary;
    line-height: $line-height-base;
    margin-bottom: $spacing-xxl;
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
    margin-bottom: $spacing-lg;
    opacity: 0.6;
  }

  .empty-text {
    font-size: $font-size-lg;
    color: $text-primary;
    font-weight: $font-weight-bold;
    margin-bottom: $spacing-sm;
  }

  .empty-desc {
    font-size: $font-size-sm;
    color: $text-secondary;
    line-height: $line-height-base;
    margin-bottom: $spacing-xl;
  }
}

// 菜谱网格滚动区
.recipes-grid-scroll {
  height: calc(100vh - 240rpx);
  padding: 20rpx 12rpx;
}

// Pinterest 风格网格
.recipes-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16rpx;

  .recipe-card {
    background: white;
    border-radius: $radius-lg;
    overflow: hidden;
    box-shadow: $shadow-base;
    transition: all $duration-base;
    break-inside: avoid;

    &:active {
      transform: scale(0.98);
      box-shadow: $shadow-md;
    }

    // 图片区域
    .card-image-wrapper {
      position: relative;
      width: 100%;
      height: 280rpx;
      overflow: hidden;

      .card-image {
        width: 100%;
        height: 100%;
      }

      // 浮动标签
      .image-badges {
        position: absolute;
        top: 12rpx;
        left: 12rpx;
        right: 12rpx;
        display: flex;
        justify-content: space-between;

        .badge {
          padding: 6rpx 12rpx;
          border-radius: 20rpx;
          font-size: $font-size-xxs;
          font-weight: $font-weight-bold;
          backdrop-filter: blur(8rpx);
          box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.1);

          &.difficulty {
            background: rgba(255, 255, 255, 0.9);
            color: $text-primary;
          }

          &.time {
            background: rgba(255, 138, 101, 0.9);
            color: white;
          }
        }
      }
    }

    // 卡片内容
    .card-content {
      padding: 16rpx;

      .card-title {
        display: block;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        color: $text-primary;
        margin-bottom: 8rpx;
        @include text-ellipsis(2);
      }

      .card-desc {
        display: block;
        font-size: $font-size-xs;
        color: $text-secondary;
        line-height: $line-height-base;
        margin-bottom: 12rpx;
        @include text-ellipsis(2);
      }

      .card-tags {
        display: flex;
        flex-wrap: wrap;
        gap: 8rpx;
        margin-bottom: 12rpx;

        .tag-item {
          font-size: $font-size-xxs;
          color: $primary;
          background: rgba(255, 138, 101, 0.1);
          padding: 4rpx 12rpx;
          border-radius: 20rpx;
        }
      }

      // 互动栏
      .card-interactions {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding-top: 12rpx;
        border-top: 1rpx solid $border-light;

        .interaction-left {
          flex: 1;
          min-width: 0;

          .creator-info {
            display: flex;
            align-items: center;
            gap: 8rpx;

            .creator-avatar {
              width: 32rpx;
              height: 32rpx;
              border-radius: 50%;
              background: $gradient-primary;
              @include flex-center;
              flex-shrink: 0;

              .avatar-text {
                font-size: $font-size-xxs;
                color: white;
                font-weight: $font-weight-bold;
              }
            }

            .creator-name {
              font-size: $font-size-xs;
              color: $text-tertiary;
              @include text-ellipsis(1);
            }
          }
        }

        .interaction-right {
          display: flex;
          gap: 8rpx;

          .action-btn {
            width: 48rpx;
            height: 48rpx;
            border-radius: 24rpx;
            background: $bg-section;
            @include flex-center;
            transition: all $duration-fast;

            &:active {
              transform: scale(0.9);
              background: $bg-hover;
            }

            .action-icon {
              font-size: 28rpx;
            }
          }
        }
      }
    }
  }
}

// 浮动添加按钮
.fab-container {
  position: fixed;
  bottom: calc(100rpx + env(safe-area-inset-bottom));
  right: 32rpx;
  z-index: 200;
  display: flex;
  flex-direction: column;
  gap: 16rpx;

  .fab {
    width: 96rpx;
    height: 96rpx;
    border-radius: 50%;
    background: $gradient-primary;
    @include flex-center;
    box-shadow: 0 8rpx 24rpx rgba(255, 138, 101, 0.4);
    transition: all $duration-base;
    border: none;
    position: relative;

    &:active {
      transform: scale(0.9);
    }

    .fab-icon {
      font-size: 48rpx;
      font-weight: bold;
      color: white;
    }

    &.fab-cart {
      width: 88rpx;
      height: 88rpx;
      background: white;
      box-shadow: $shadow-md;

      .fab-icon {
        font-size: 40rpx;
        color: $primary;
      }
    }

    .cart-badge {
      position: absolute;
      top: -8rpx;
      right: -8rpx;
      min-width: 36rpx;
      height: 36rpx;
      padding: 0 8rpx;
      background: $error;
      border-radius: 18rpx;
      font-size: $font-size-xxs;
      color: white;
      font-weight: $font-weight-bold;
      @include flex-center;
    }
  }
}

// 购物车弹窗遮罩
.cart-modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
  animation: fadeIn 0.2s ease-out;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

// 购物车弹窗
.cart-modal {
  width: 100%;
  max-height: 70vh;
  background: white;
  border-radius: 32rpx 32rpx 0 0;
  display: flex;
  flex-direction: column;
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

// 弹窗头部
.cart-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 32rpx 32rpx 24rpx;
  border-bottom: 1rpx solid $border-light;

  .cart-title {
    font-size: $font-size-lg;
    font-weight: $font-weight-bold;
    color: $text-primary;
  }

  .cart-actions {
    display: flex;
    align-items: center;
    gap: 24rpx;

    .clear-btn {
      font-size: $font-size-sm;
      color: $text-tertiary;

      &:active {
        color: $error;
      }
    }

    .close-btn {
      width: 48rpx;
      height: 48rpx;
      border-radius: 24rpx;
      background: $bg-section;
      @include flex-center;
      font-size: $font-size-sm;
      color: $text-secondary;

      &:active {
        background: $bg-hover;
      }
    }
  }
}

// 购物车内容
.cart-content {
  flex: 1;
  max-height: 400rpx;
  padding: 16rpx 32rpx;
}

// 购物车项目
.cart-item {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 16rpx 0;
  border-bottom: 1rpx solid $border-light;

  &:last-child {
    border-bottom: none;
  }

  .item-image {
    width: 100rpx;
    height: 100rpx;
    border-radius: $radius-base;
    flex-shrink: 0;
  }

  .item-info {
    flex: 1;
    min-width: 0;

    .item-name {
      display: block;
      font-size: $font-size-base;
      font-weight: $font-weight-medium;
      color: $text-primary;
      @include text-ellipsis(1);
      margin-bottom: 8rpx;
    }

    .item-time {
      font-size: $font-size-xs;
      color: $text-tertiary;
    }
  }

  .item-quantity {
    display: flex;
    align-items: center;
    gap: 12rpx;

    .qty-btn {
      width: 48rpx;
      height: 48rpx;
      border-radius: 24rpx;
      background: $bg-section;
      @include flex-center;
      font-size: $font-size-lg;
      color: $text-secondary;
      transition: all $duration-fast;

      &:active {
        transform: scale(0.9);
        background: $bg-hover;
      }
    }

    .qty-num {
      min-width: 40rpx;
      text-align: center;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .item-delete {
    width: 48rpx;
    height: 48rpx;
    @include flex-center;
    font-size: 28rpx;
    opacity: 0.6;
    transition: all $duration-fast;

    &:active {
      opacity: 1;
      transform: scale(1.1);
    }
  }
}

// 空购物车
.cart-empty {
  @include flex-center;
  flex-direction: column;
  padding: 60rpx 40rpx;

  .empty-icon {
    font-size: 80rpx;
    opacity: 0.4;
    margin-bottom: 20rpx;
  }

  .empty-text {
    font-size: $font-size-base;
    color: $text-secondary;
    margin-bottom: 8rpx;
  }

  .empty-desc {
    font-size: $font-size-sm;
    color: $text-tertiary;
  }
}

// 底部操作栏
.cart-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx 32rpx;
  padding-bottom: calc(24rpx + env(safe-area-inset-bottom));
  border-top: 1rpx solid $border-light;
  background: white;

  .cart-summary {
    .summary-label {
      display: block;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      color: $text-primary;
      margin-bottom: 4rpx;
    }

    .summary-time {
      font-size: $font-size-xs;
      color: $text-tertiary;
    }
  }

  .checkout-btn {
    padding: 20rpx 48rpx;
    background: $gradient-primary;
    color: white;
    border: none;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    box-shadow: $shadow-primary;

    &:active {
      transform: scale(0.96);
    }
  }
}

// 按钮样式
.btn {
  padding: $spacing-base $spacing-xl;
  background: $gradient-primary;
  color: white;
  border: none;
  border-radius: $radius-button;
  font-size: $font-size-base;
  font-weight: $font-weight-bold;
  box-shadow: $shadow-primary;

  &:active {
    transform: scale(0.96);
  }
}
</style>
