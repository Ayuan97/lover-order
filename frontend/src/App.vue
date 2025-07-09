<template>
  <view id="app">
    <!-- 应用内容 -->
  </view>
</template>

<script setup lang="ts">
import { onLaunch, onShow, onHide } from '@dcloudio/uni-app'
import { checkPageAccess, autoLoginCheck } from '@/utils/auth'

onLaunch(async () => {
  console.log('App Launch')

  // 应用启动时进行自动登录检查
  try {
    const isLoggedIn = await autoLoginCheck()
    console.log('自动登录检查结果:', isLoggedIn)

    // 如果没有登录，跳转到登录页
    if (!isLoggedIn) {
      uni.reLaunch({
        url: '/pages/login/index'
      })
    }
  } catch (error) {
    console.error('应用启动登录检查失败:', error)
  }
})

onShow(() => {
  console.log('App Show')

  // 应用从后台回到前台时，检查登录状态
  const pages = getCurrentPages()
  if (pages.length > 0) {
    const currentPage = pages[pages.length - 1]
    const currentPath = `/${currentPage.route}`

    checkPageAccess(currentPath).catch(error => {
      console.error('页面访问权限检查失败:', error)
    })
  }
})

onHide(() => {
  console.log('App Hide')
})
</script>

<style>
/* 全局样式 */
page {
  background-color: #FAFAFA;
  color: #424242;
  font-size: 28rpx;
  line-height: 1.6;
}

#app {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
}

/* 通用工具类 */
.flex {
  display: flex;
}

.flex-column {
  display: flex;
  flex-direction: column;
}

.flex-center {
  display: flex;
  align-items: center;
  justify-content: center;
}

.flex-between {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.text-center {
  text-align: center;
}

.text-primary {
  color: #FF8A65;
}

.card {
  background-color: #fff;
  border-radius: 12rpx;
  box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.1);
  padding: 24rpx;
  margin-bottom: 24rpx;
}

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 16rpx 24rpx;
  border-radius: 12rpx;
  font-size: 28rpx;
  transition: all 0.2s;
  border: none;
  cursor: pointer;
}

.btn-primary {
  background-color: #FF8A65;
  color: #fff;
}
</style>
