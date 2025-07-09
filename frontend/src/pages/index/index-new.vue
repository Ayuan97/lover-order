<template>
  <view class="merchant-page">
    <!-- 加载状态 -->
    <view class="page-loading" v-if="isPageLoading">
      <view class="loading-content">
        <text class="loading-icon">🍳</text>
        <text class="loading-text">正在准备美味...</text>
      </view>
    </view>

    <!-- 无家庭状态 -->
    <view class="no-family-welcome" v-else-if="!hasFamily">
      <view class="welcome-header">
        <view class="welcome-bg"></view>
        <view class="welcome-content">
          <text class="welcome-icon">🏠</text>
          <text class="welcome-title">欢迎来到 Love Order</text>
          <text class="welcome-subtitle">温馨家庭，美味共享</text>
          <text class="welcome-desc">创建或加入家庭，开启美好的用餐时光</text>

          <view class="welcome-actions">
            <button class="welcome-btn primary" @click="goToFamily">
              <text class="btn-icon">✨</text>
              <text class="btn-text">开始使用</text>
            </button>
          </view>
        </view>
      </view>

      <view class="welcome-features">
        <view class="feature-card">
          <text class="feature-icon">👨‍👩‍👧‍👦</text>
          <text class="feature-title">家庭管理</text>
          <text class="feature-desc">邀请家人加入，共同管理家庭菜谱</text>
        </view>
        <view class="feature-card">
          <text class="feature-icon">📖</text>
          <text class="feature-title">菜谱分享</text>
          <text class="feature-desc">记录美味菜谱，与家人分享烹饪心得</text>
        </view>
        <view class="feature-card">
          <text class="feature-icon">🛒</text>
          <text class="feature-title">便捷点餐</text>
          <text class="feature-desc">家人可以轻松点餐，享受贴心服务</text>
        </view>
      </view>
    </view>

    <!-- 有家庭状态 - 简化版本 -->
    <view class="family-home" v-else>
      <view class="home-header">
        <text class="home-title">{{ merchantInfo.name }}</text>
        <text class="home-desc">{{ merchantInfo.description }}</text>
      </view>
      
      <view class="home-stats">
        <view class="stat-item">
          <text class="stat-number">{{ recipes.length }}</text>
          <text class="stat-label">道菜谱</text>
        </view>
        <view class="stat-item">
          <text class="stat-number">{{ categories.length }}</text>
          <text class="stat-label">个分类</text>
        </view>
        <view class="stat-item">
          <text class="stat-number">4.8</text>
          <text class="stat-label">评分</text>
        </view>
      </view>
      
      <view class="quick-actions">
        <button class="action-btn" @click="goToRecipes">
          <text class="btn-icon">📖</text>
          <text class="btn-text">浏览菜谱</text>
        </button>
        <button class="action-btn" @click="goToFamily">
          <text class="btn-icon">🏠</text>
          <text class="btn-text">家庭管理</text>
        </button>
      </view>
      
      <view class="recent-recipes" v-if="recipes.length > 0">
        <text class="section-title">最新菜谱</text>
        <view class="recipe-list">
          <view 
            class="recipe-item" 
            v-for="recipe in recipes.slice(0, 4)" 
            :key="recipe.id"
          >
            <text class="recipe-name">{{ recipe.name }}</text>
            <text class="recipe-category">{{ recipe.category_name }}</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RecipeService, CategoryService, type Recipe, type Category } from '@/api/recipe'
import { processRecipeList, getRecipeDisplayInfo } from '@/utils/recipe'
import { FamilyService } from '@/api/family'

// 页面状态
const isPageLoading = ref(true)
const hasFamily = ref(false)

// 商家信息
const merchantInfo = ref({
  name: '温馨家庭厨房',
  description: '用心烹饪，温暖每一餐',
  rating: 4.8,
  reviewCount: 128,
  minOrder: 0,
  deliveryFee: 0,
  deliveryTime: 30,
  logo: '',
  backgroundImage: ''
})

// 菜谱和分类数据
const recipes = ref<Recipe[]>([])
const categories = ref<Category[]>([])
const loading = ref(false)

// 前往家庭管理
const goToFamily = () => {
  uni.navigateTo({
    url: '/pages/family/index'
  })
}

// 前往菜谱页面
const goToRecipes = () => {
  uni.navigateTo({
    url: '/pages/recipes/index'
  })
}

// 加载分类数据
const loadCategories = async () => {
  try {
    console.log('开始加载分类...')
    const result = await CategoryService.getCategoryList()
    console.log('分类加载成功:', result)
    categories.value = result || []
  } catch (error: any) {
    console.error('加载分类失败:', error)
    categories.value = []
  }
}

// 加载菜谱数据
const loadRecipes = async () => {
  try {
    console.log('开始加载菜谱...')
    const result = await RecipeService.getRecipeList({
      page: 1,
      page_size: 100
    })
    console.log('菜谱加载成功:', result)
    recipes.value = result.recipes || []
  } catch (error: any) {
    console.error('加载菜谱失败:', error)
    
    if (error.statusCode === 403) {
      console.log('用户没有菜谱访问权限，设置空菜谱列表')
      recipes.value = []
    } else {
      uni.showToast({
        title: '加载菜谱失败',
        icon: 'none',
        duration: 2000
      })
      recipes.value = []
    }
  }
}

// 初始化数据
const initData = async () => {
  loading.value = true
  try {
    console.log('开始并行加载分类和菜谱...')
    
    const [categoriesResult, recipesResult] = await Promise.allSettled([
      loadCategories(),
      loadRecipes()
    ])
    
    if (categoriesResult.status === 'rejected') {
      console.error('加载分类失败:', categoriesResult.reason)
    }
    
    if (recipesResult.status === 'rejected') {
      console.error('加载菜谱失败:', recipesResult.reason)
    }
    
    console.log('数据加载完成')
  } catch (error) {
    console.error('初始化数据失败:', error)
  } finally {
    loading.value = false
  }
}

// 检查家庭状态
const checkFamilyStatus = async () => {
  try {
    console.log('开始检查家庭状态...')
    hasFamily.value = FamilyService.hasFamily()
    console.log('家庭状态检查结果:', hasFamily.value)
    
    const userInfo = uni.getStorageSync('user_info')
    console.log('用户信息:', userInfo)
    
    if (userInfo && userInfo.family_id) {
      console.log('用户有家庭ID:', userInfo.family_id)
      hasFamily.value = true
    } else {
      console.log('用户没有家庭ID')
      hasFamily.value = false
    }
  } catch (error) {
    console.error('检查家庭状态失败:', error)
    hasFamily.value = false
  }
}

// 页面加载时的初始化
onMounted(async () => {
  try {
    console.log('首页开始初始化...')
    isPageLoading.value = true
    
    console.log('检查家庭状态...')
    await checkFamilyStatus()
    console.log('家庭状态检查完成:', hasFamily.value)
    
    if (hasFamily.value) {
      console.log('开始加载数据...')
      await initData()
      console.log('数据加载完成')
    } else {
      console.log('用户没有家庭，跳过数据加载')
    }
  } catch (error) {
    console.error('页面初始化失败:', error)
    uni.showToast({
      title: '页面加载失败',
      icon: 'error'
    })
  } finally {
    console.log('设置页面加载完成')
    isPageLoading.value = false
  }
})
</script>
