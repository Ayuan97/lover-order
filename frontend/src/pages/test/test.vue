<template>
  <view class="test-page">
    <view class="test-header">
      <text class="title">API测试页面</text>
    </view>
    
    <view class="test-section">
      <text class="section-title">分类数据测试</text>
      <button class="test-btn" @click="testCategories">测试分类API</button>
      <view class="result-box">
        <text class="result-text">{{ categoryResult }}</text>
      </view>
    </view>
    
    <view class="test-section">
      <text class="section-title">菜谱数据测试</text>
      <button class="test-btn" @click="testRecipes">测试菜谱API</button>
      <view class="result-box">
        <text class="result-text">{{ recipeResult }}</text>
      </view>
    </view>
    
    <view class="test-section">
      <text class="section-title">直接网络请求测试</text>
      <button class="test-btn" @click="testDirectRequest">直接请求测试</button>
      <view class="result-box">
        <text class="result-text">{{ directResult }}</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { CategoryService, RecipeService } from '@/api/recipe'

const categoryResult = ref('未测试')
const recipeResult = ref('未测试')
const directResult = ref('未测试')

const testCategories = async () => {
  categoryResult.value = '测试中...'
  try {
    const result = await CategoryService.getCategoryList()
    categoryResult.value = `成功！获取到 ${result?.length || 0} 个分类`
    console.log('分类测试结果:', result)
  } catch (error: any) {
    categoryResult.value = `失败：${error.message || error}`
    console.error('分类测试失败:', error)
  }
}

const testRecipes = async () => {
  recipeResult.value = '测试中...'
  try {
    const result = await RecipeService.getRecipeList({ page: 1, page_size: 10 })
    recipeResult.value = `成功！获取到 ${result.recipes?.length || 0} 道菜谱`
    console.log('菜谱测试结果:', result)
  } catch (error: any) {
    recipeResult.value = `失败：${error.message || error}`
    console.error('菜谱测试失败:', error)
  }
}

const testDirectRequest = async () => {
  directResult.value = '测试中...'
  try {
    const response = await uni.request({
      url: 'http://192.168.4.15:8081/api/v1/dev/categories',
      method: 'GET',
      timeout: 10000
    })
    
    if (response.statusCode === 200) {
      const data = response.data as any
      directResult.value = `成功！状态码: ${response.statusCode}, 数据: ${JSON.stringify(data).substring(0, 100)}...`
    } else {
      directResult.value = `失败：状态码 ${response.statusCode}`
    }
    console.log('直接请求结果:', response)
  } catch (error: any) {
    directResult.value = `失败：${error.message || error}`
    console.error('直接请求失败:', error)
  }
}
</script>

<style lang="scss" scoped>
.test-page {
  padding: 40rpx;
  background-color: #f5f5f5;
  min-height: 100vh;
}

.test-header {
  text-align: center;
  margin-bottom: 60rpx;
  
  .title {
    font-size: 48rpx;
    font-weight: bold;
    color: #333;
  }
}

.test-section {
  background: white;
  border-radius: 16rpx;
  padding: 40rpx;
  margin-bottom: 40rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
  
  .section-title {
    display: block;
    font-size: 32rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 24rpx;
  }
  
  .test-btn {
    width: 100%;
    height: 80rpx;
    background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
    color: white;
    border: none;
    border-radius: 12rpx;
    font-size: 28rpx;
    font-weight: bold;
    margin-bottom: 24rpx;
    
    &:active {
      transform: scale(0.98);
    }
  }
  
  .result-box {
    background: #f8f8f8;
    border-radius: 12rpx;
    padding: 24rpx;
    min-height: 120rpx;
    
    .result-text {
      font-size: 24rpx;
      color: #666;
      line-height: 1.5;
      word-break: break-all;
    }
  }
}
</style>
