<template>
  <view class="test-page">
    <view class="header">
      <text class="title">API连接测试</text>
    </view>
    
    <view class="test-section">
      <view class="test-item">
        <text class="test-label">后端健康检查:</text>
        <button class="test-btn" @click="testHealth">测试</button>
        <text class="test-result" :class="{ success: healthStatus === 'success', error: healthStatus === 'error' }">
          {{ healthResult }}
        </text>
      </view>
      
      <view class="test-item">
        <text class="test-label">获取分类列表:</text>
        <button class="test-btn" @click="testCategories">测试</button>
        <text class="test-result" :class="{ success: categoriesStatus === 'success', error: categoriesStatus === 'error' }">
          {{ categoriesResult }}
        </text>
      </view>
      
      <view class="test-item">
        <text class="test-label">获取菜谱列表:</text>
        <button class="test-btn" @click="testRecipes">测试</button>
        <text class="test-result" :class="{ success: recipesStatus === 'success', error: recipesStatus === 'error' }">
          {{ recipesResult }}
        </text>
      </view>

      <view class="test-item">
        <text class="test-label">微信登录测试:</text>
        <button class="test-btn" @click="testWechatLogin">测试</button>
        <text class="test-result" :class="{ success: wechatStatus === 'success', error: wechatStatus === 'error' }">
          {{ wechatResult }}
        </text>
      </view>

      <view class="test-item">
        <text class="test-label">获取用户信息测试:</text>
        <button class="test-btn" @click="testGetUserInfo">测试</button>
        <text class="test-result">
          点击测试获取用户昵称、头像等信息
        </text>
      </view>

      <view class="test-item">
        <text class="test-label">获取用户资料测试:</text>
        <button class="test-btn" @click="testGetUserProfile">测试</button>
        <text class="test-result">
          点击测试从服务器获取用户资料
        </text>
      </view>
    </view>
    
    <view class="data-section" v-if="testData">
      <text class="section-title">测试数据:</text>
      <scroll-view class="data-content" scroll-y="true">
        <text class="data-text">{{ JSON.stringify(testData, null, 2) }}</text>
      </scroll-view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { request } from '@/api/request'
import { CategoryService, RecipeService } from '@/api/recipe'
import { AuthService } from '@/api/auth'
import { API_CONFIG } from '@/api/config'

// 测试状态
const healthStatus = ref('')
const healthResult = ref('未测试')
const categoriesStatus = ref('')
const categoriesResult = ref('未测试')
const recipesStatus = ref('')
const recipesResult = ref('未测试')
const wechatStatus = ref('')
const wechatResult = ref('未测试')
const testData = ref(null)

// 测试后端健康检查
const testHealth = async () => {
  healthStatus.value = 'loading'
  healthResult.value = '测试中...'

  try {
    // 使用配置的API地址
    const baseUrl = API_CONFIG.BASE_URL.replace('/api/v1', '')
    const response = await request.request(`${baseUrl}/health`)
    healthStatus.value = 'success'
    healthResult.value = `成功: ${response.data.message}`
    testData.value = response.data
  } catch (error: any) {
    healthStatus.value = 'error'
    healthResult.value = `失败: ${error.message}`
    testData.value = error
  }
}

// 测试分类API
const testCategories = async () => {
  categoriesStatus.value = 'loading'
  categoriesResult.value = '测试中...'
  
  try {
    const categories = await CategoryService.getCategoryList()
    categoriesStatus.value = 'success'
    categoriesResult.value = `成功: 获取到 ${categories.length} 个分类`
    testData.value = categories
  } catch (error: any) {
    categoriesStatus.value = 'error'
    categoriesResult.value = `失败: ${error.message}`
    testData.value = error
  }
}

// 测试菜谱API
const testRecipes = async () => {
  recipesStatus.value = 'loading'
  recipesResult.value = '测试中...'

  try {
    const result = await RecipeService.getRecipeList({ page: 1, page_size: 10 })
    recipesStatus.value = 'success'
    recipesResult.value = `成功: 获取到 ${result.recipes.length} 个菜谱`
    testData.value = result
  } catch (error: any) {
    recipesStatus.value = 'error'
    recipesResult.value = `失败: ${error.message}`
    testData.value = error
  }
}

// 测试微信登录（官方推荐流程）
const testWechatLogin = async () => {
  wechatStatus.value = 'loading'
  wechatResult.value = '测试中...'

  try {
    // #ifdef MP-WEIXIN
    // 按照官方推荐流程：直接登录
    const result = await AuthService.wechatMiniLogin()
    wechatStatus.value = 'success'
    wechatResult.value = `成功: 登录用户 OpenID ${result.user.openid.substring(0, 8)}...`
    testData.value = result
    // #endif

    // #ifndef MP-WEIXIN
    wechatStatus.value = 'error'
    wechatResult.value = '仅在微信小程序环境下可用'
    // #endif
  } catch (error: any) {
    wechatStatus.value = 'error'
    wechatResult.value = `失败: ${error.message}`
    testData.value = error
  }
}

// 测试获取用户信息（独立功能）
const testGetUserInfo = async () => {
  try {
    // #ifdef MP-WEIXIN
    const userInfo = await AuthService.getUserInfo()
    uni.showModal({
      title: '用户信息获取成功',
      content: `昵称: ${userInfo.nickname}\n性别: ${userInfo.gender === 1 ? '男' : userInfo.gender === 2 ? '女' : '未知'}`,
      showCancel: false
    })
    // #endif

    // #ifndef MP-WEIXIN
    uni.showToast({
      title: '请在微信小程序中使用',
      icon: 'none'
    })
    // #endif
  } catch (error: any) {
    uni.showModal({
      title: '获取用户信息失败',
      content: error.message,
      showCancel: false
    })
  }
}

// 测试获取用户资料（从服务器）
const testGetUserProfile = async () => {
  try {
    if (!AuthService.isLoggedIn()) {
      uni.showToast({
        title: '请先登录',
        icon: 'none'
      })
      return
    }

    const userProfile = await AuthService.getUserProfile()
    uni.showModal({
      title: '用户资料获取成功',
      content: `ID: ${userProfile.id}\n昵称: ${userProfile.nickname || '未设置'}\n角色: ${userProfile.role}`,
      showCancel: false
    })
  } catch (error: any) {
    uni.showModal({
      title: '获取用户资料失败',
      content: error.message,
      showCancel: false
    })
  }
}
</script>

<style lang="scss" scoped>
.test-page {
  padding: 24rpx;
  min-height: 100vh;
  background-color: #FAFAFA;
}

.header {
  text-align: center;
  margin-bottom: 32rpx;
  
  .title {
    font-size: 36rpx;
    font-weight: bold;
    color: #424242;
  }
}

.test-section {
  margin-bottom: 32rpx;
}

.test-item {
  background-color: white;
  padding: 24rpx;
  margin-bottom: 16rpx;
  border-radius: 12rpx;
  box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.1);
  
  .test-label {
    display: block;
    font-size: 28rpx;
    font-weight: bold;
    margin-bottom: 16rpx;
    color: #424242;
  }
  
  .test-btn {
    background-color: #FF8A65;
    color: white;
    border: none;
    padding: 12rpx 24rpx;
    border-radius: 8rpx;
    font-size: 24rpx;
    margin-right: 16rpx;
  }
  
  .test-result {
    font-size: 24rpx;
    
    &.success {
      color: #4CAF50;
    }
    
    &.error {
      color: #F44336;
    }
  }
}

.data-section {
  background-color: white;
  border-radius: 12rpx;
  padding: 24rpx;
  box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.1);
  
  .section-title {
    display: block;
    font-size: 28rpx;
    font-weight: bold;
    margin-bottom: 16rpx;
    color: #424242;
  }
  
  .data-content {
    height: 400rpx;
    background-color: #F5F5F5;
    border-radius: 8rpx;
    padding: 16rpx;
    
    .data-text {
      font-size: 20rpx;
      font-family: monospace;
      color: #666;
      line-height: 1.4;
      white-space: pre-wrap;
    }
  }
}
</style>
