<template>
  <view class="login-page">
    <!-- 背景装饰 -->
    <view class="bg-decoration">
      <view class="bg-circle circle-1"></view>
      <view class="bg-circle circle-2"></view>
      <view class="bg-circle circle-3"></view>
    </view>

    <!-- 主要内容 -->
    <view class="login-content">
      <!-- Logo区域 -->
      <view class="logo-section">
        <view class="logo-icon">🏠</view>
        <text class="app-name">Love Order</text>
        <text class="app-desc">温馨家庭，美味共享</text>
      </view>

      <!-- 功能介绍 -->
      <view class="features-section">
        <view class="feature-item">
          <text class="feature-icon">👨‍👩‍👧‍👦</text>
          <text class="feature-text">家庭成员共同管理</text>
        </view>
        <view class="feature-item">
          <text class="feature-icon">📖</text>
          <text class="feature-text">丰富的菜谱库</text>
        </view>
        <view class="feature-item">
          <text class="feature-icon">🛒</text>
          <text class="feature-text">便捷的点餐体验</text>
        </view>
      </view>

      <!-- 登录按钮 -->
      <view class="login-section">
        <button
          class="login-btn"
          :class="{ loading: isLoading }"
          :disabled="isLoading"
          @click="handleWechatLogin"
        >
          <text class="login-icon" v-if="!isLoading">👤</text>
          <text class="login-text">
            {{ isLoading ? '登录中...' : '微信授权登录' }}
          </text>
        </button>
        
        <view class="login-tips">
          <text class="tips-text">登录即表示同意</text>
          <text class="tips-link" @click="showPrivacyPolicy">《隐私政策》</text>
          <text class="tips-text">和</text>
          <text class="tips-link" @click="showUserAgreement">《用户协议》</text>
        </view>
      </view>
    </view>

    <!-- 版本信息 -->
    <view class="version-info">
      <text class="version-text">Version 1.0.0</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { AuthService } from '@/api/auth'

// 响应式数据
const isLoading = ref(false)

// 微信登录处理
const handleWechatLogin = async () => {
  if (isLoading.value) return

  isLoading.value = true

  try {
    // 检查是否在微信小程序环境
    // #ifdef MP-WEIXIN

    let result
    try {
      // 首先尝试完整登录流程：登录 + 获取用户信息
      result = await AuthService.wechatMiniLoginWithUserInfo()
    } catch (error: any) {
      console.log('完整登录失败，尝试简化登录:', error.message)
      // 如果获取用户信息失败，使用简化登录
      if (error.message.includes('getUserProfile') ||
          error.message.includes('用户拒绝') ||
          error.message.includes('user deny')) {
        uni.showToast({
          title: '使用简化登录模式',
          icon: 'none'
        })
        result = await AuthService.wechatMiniLogin()
      } else {
        throw error
      }
    }

    uni.showToast({
      title: '登录成功',
      icon: 'success'
    })

    // 登录成功后跳转到首页
    setTimeout(() => {
      uni.switchTab({
        url: '/pages/index/index'
      })
    }, 1500)

    // #endif

    // #ifndef MP-WEIXIN
    // H5环境下的处理
    uni.showToast({
      title: '请在微信小程序中使用',
      icon: 'none'
    })
    return
    // #endif

  } catch (error: any) {
    console.error('登录失败:', error)

    // 提供更详细的错误信息
    let errorMessage = '登录过程中出现错误，请重试'

    if (error.message.includes('网络')) {
      errorMessage = '网络连接失败，请检查网络设置'
    } else if (error.message.includes('code')) {
      errorMessage = '微信登录授权失败，请重试'
    } else if (error.message.includes('40029')) {
      errorMessage = '登录凭证无效，请重试'
    }

    uni.showModal({
      title: '登录失败',
      content: errorMessage,
      showCancel: true,
      cancelText: '取消',
      confirmText: '重试',
      success: (res) => {
        if (res.confirm) {
          // 用户选择重试
          setTimeout(() => {
            handleWechatLogin()
          }, 500)
        }
      }
    })
  } finally {
    isLoading.value = false
  }
}

// 获取用户信息（可选的独立功能）
const handleGetUserInfo = async () => {
  try {
    // #ifdef MP-WEIXIN
    const userInfo = await AuthService.getUserInfo()
    console.log('用户信息:', userInfo)

    uni.showToast({
      title: '获取用户信息成功',
      icon: 'success'
    })
    // #endif

    // #ifndef MP-WEIXIN
    uni.showToast({
      title: '请在微信小程序中使用',
      icon: 'none'
    })
    // #endif
  } catch (error: any) {
    console.error('获取用户信息失败:', error)

    uni.showModal({
      title: '获取用户信息失败',
      content: error.message || '获取用户信息时出现错误',
      showCancel: false
    })
  }
}

// 显示隐私政策
const showPrivacyPolicy = () => {
  uni.showModal({
    title: '隐私政策',
    content: '我们重视您的隐私保护，详细的隐私政策请访问我们的官网查看。',
    showCancel: false
  })
}

// 显示用户协议
const showUserAgreement = () => {
  uni.showModal({
    title: '用户协议',
    content: '使用本应用即表示您同意我们的用户协议，详细内容请访问官网查看。',
    showCancel: false
  })
}
</script>

<style lang="scss" scoped>
.login-page {
  min-height: 100vh;
  background: linear-gradient(135deg, #FF8A65, #F8BBD9);
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 40rpx;
  box-sizing: border-box;
}

.bg-decoration {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  overflow: hidden;
  
  .bg-circle {
    position: absolute;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.1);
    
    &.circle-1 {
      width: 200rpx;
      height: 200rpx;
      top: 10%;
      right: 10%;
      animation: float 6s ease-in-out infinite;
    }
    
    &.circle-2 {
      width: 150rpx;
      height: 150rpx;
      bottom: 20%;
      left: 15%;
      animation: float 8s ease-in-out infinite reverse;
    }
    
    &.circle-3 {
      width: 100rpx;
      height: 100rpx;
      top: 30%;
      left: 20%;
      animation: float 10s ease-in-out infinite;
    }
  }
}

@keyframes float {
  0%, 100% {
    transform: translateY(0px);
  }
  50% {
    transform: translateY(-20px);
  }
}

.login-content {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 600rpx;
  margin-top: 120rpx;
  margin-bottom: 60rpx;
}

.logo-section {
  text-align: center;
  margin-bottom: 80rpx;
  
  .logo-icon {
    font-size: 120rpx;
    margin-bottom: 24rpx;
    display: block;
  }
  
  .app-name {
    display: block;
    font-size: 48rpx;
    font-weight: bold;
    color: white;
    margin-bottom: 16rpx;
  }
  
  .app-desc {
    font-size: 28rpx;
    color: rgba(255, 255, 255, 0.8);
  }
}

.features-section {
  margin-bottom: 80rpx;
  
  .feature-item {
    display: flex;
    align-items: center;
    margin-bottom: 32rpx;
    padding: 24rpx;
    background: rgba(255, 255, 255, 0.15);
    border-radius: 16rpx;
    backdrop-filter: blur(10px);
    
    .feature-icon {
      font-size: 40rpx;
      margin-right: 24rpx;
    }
    
    .feature-text {
      font-size: 28rpx;
      color: white;
      flex: 1;
    }
  }
}

.login-section {
  .login-btn {
    width: 100%;
    height: 96rpx;
    background: white;
    color: #FF8A65;
    border: none;
    border-radius: 48rpx;
    font-size: 32rpx;
    font-weight: bold;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 8rpx 24rpx rgba(0, 0, 0, 0.15);
    transition: all 0.3s ease;
    margin-bottom: 32rpx;
    
    &:not(.loading):active {
      transform: scale(0.98);
    }
    
    &.loading {
      opacity: 0.7;
    }
    
    .login-icon {
      font-size: 28rpx;
      margin-right: 12rpx;
    }
  }
  
  .login-tips {
    text-align: center;

    .tips-text {
      font-size: 24rpx;
      color: rgba(255, 255, 255, 0.8);
    }

    .tips-link {
      font-size: 24rpx;
      color: white;
      text-decoration: underline;
    }
  }
}

.version-info {
  position: relative;
  z-index: 1;
  text-align: center;
  padding-bottom: 40rpx;

  .version-text {
    font-size: 20rpx;
    color: rgba(255, 255, 255, 0.6);
  }
}
</style>
