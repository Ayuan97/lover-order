<template>
  <view class="profile-page">
    <view class="profile-header">
      <view class="user-info card">
        <image
          class="avatar"
          :src="userInfo.avatar || defaultAvatar"
          mode="aspectFill"
          @error="handleAvatarError"
        />
        <view class="user-details">
          <text class="username">{{ userInfo.nickname || '未设置昵称' }}</text>
          <text class="user-role">{{ getRoleText(userInfo.role) }}</text>
        </view>
      </view>
    </view>
    
    <view class="menu-list">
      <view 
        class="menu-item card" 
        v-for="item in menuItems" 
        :key="item.id"
        @click="handleMenuClick(item)"
      >
        <text class="menu-icon">{{ item.icon }}</text>
        <text class="menu-text">{{ item.name }}</text>
        <text class="menu-arrow">></text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { AuthService } from '@/api/auth'

// 用户信息
const userInfo = ref({
  nickname: '',
  avatar: '',
  role: 'member'
})

// 默认头像（使用emoji或者base64编码的简单图片）
const defaultAvatar = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iNjAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjYwIiB5PSI3NSIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjQ4IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+RpDwvdGV4dD4KPHN2Zz4=')

// 菜单项配置
const menuItems = [
  {
    id: 1,
    name: '家庭管理',
    icon: '👨‍👩‍👧‍👦',
    action: 'family'
  },
  {
    id: 2,
    name: '访客分享演示',
    icon: '🎁',
    action: 'guest-demo',
    badge: 'NEW'
  },
  {
    id: 3,
    name: '我的收藏',
    icon: '❤️',
    action: 'favorites'
  },
  {
    id: 4,
    name: '设置',
    icon: '⚙️',
    action: 'settings'
  },
  {
    id: 5,
    name: '关于',
    icon: 'ℹ️',
    action: 'about'
  }
]

// 页面加载时获取用户信息
onMounted(async () => {
  await loadUserInfo()
})

// 加载用户信息
const loadUserInfo = async () => {
  try {
    // 先尝试从本地存储获取
    const localUserInfo = AuthService.getCurrentUser()
    console.log('本地用户信息:', localUserInfo)
    if (localUserInfo) {
      userInfo.value = {
        nickname: localUserInfo.nickname || '',
        avatar: localUserInfo.avatar || '',
        role: localUserInfo.role || 'member'
      }
    }

    // 如果已登录，从服务器获取最新信息
    if (AuthService.isLoggedIn()) {
      const serverUserInfo = await AuthService.getUserProfile()
      console.log('服务器用户信息:', serverUserInfo)
      userInfo.value = {
        nickname: serverUserInfo.nickname || '',
        avatar: serverUserInfo.avatar || '',
        role: serverUserInfo.role || 'member'
      }
      console.log('设置的用户信息:', userInfo.value)
    }
  } catch (error) {
    console.error('获取用户信息失败:', error)
    // 如果获取失败，使用默认值
    userInfo.value = {
      nickname: '未登录用户',
      avatar: '',
      role: 'member'
    }
  }
}

// 头像加载失败处理
const handleAvatarError = () => {
  console.log('头像加载失败，使用默认头像')
}

// 获取角色文本
const getRoleText = (role: string) => {
  switch (role) {
    case 'admin':
      return '家庭管理员'
    case 'member':
      return '家庭成员'
    case 'guest':
      return '访客'
    default:
      return '家庭成员'
  }
}

const handleMenuClick = (item: any) => {
  switch (item.action) {
    case 'family':
      uni.navigateTo({
        url: '/pages/family/index'
      })
      break
    case 'guest-demo':
      uni.navigateTo({
        url: '/pages/demo/guest-flow'
      })
      break
    case 'favorites':
      uni.navigateTo({
        url: '/pages/favorites/index'
      })
      break
    case 'settings':
      uni.navigateTo({
        url: '/pages/settings/index'
      })
      break
    case 'about':
      uni.navigateTo({
        url: '/pages/about/index'
      })
      break
    default:
      uni.showToast({
        title: '功能开发中',
        icon: 'none'
      })
  }
}
</script>

<style lang="scss" scoped>
.profile-page {
  padding: 24rpx;
  min-height: 100vh;
}

.profile-header {
  margin-bottom: 32rpx;
}

.user-info {
  display: flex;
  align-items: center;
  
  .avatar {
    width: 120rpx;
    height: 120rpx;
    border-radius: 50%;
    margin-right: 24rpx;
  }
  
  .user-details {
    flex: 1;
    
    .username {
      display: block;
      font-size: 32rpx;
      font-weight: bold;
      color: #424242;
      margin-bottom: 8rpx;
    }
    
    .user-role {
      font-size: 24rpx;
      color: #666;
    }
  }
}

.menu-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.menu-item {
  display: flex;
  align-items: center;
  padding: 32rpx 24rpx;
  
  .menu-icon {
    font-size: 32rpx;
    margin-right: 24rpx;
  }
  
  .menu-text {
    flex: 1;
    font-size: 28rpx;
    color: #424242;
  }
  
  .menu-arrow {
    font-size: 24rpx;
    color: #999;
  }
}
</style>
