<template>
  <view class="profile-page">
    <view class="profile-header">
      <view class="user-info card" @click="showEditProfile">
        <view class="avatar-container">
          <image
            class="avatar"
            :src="userInfo.avatar || defaultAvatar"
            mode="aspectFill"
            @error="handleAvatarError"
          />
          <view class="edit-badge">
            <text class="badge-icon">✏️</text>
          </view>
        </view>
        <view class="user-details">
          <text class="username">{{ userInfo.nickname || '未设置昵称' }}</text>
          <text class="user-role">{{ getRoleText(userInfo.role) }}</text>
          <text class="edit-hint">点击编辑个人资料</text>
        </view>
      </view>
    </view>

    <!-- 统计数据 -->
    <view class="stats-section card">
      <view class="stat-item" @click="goToFavorites">
        <text class="stat-value">{{ stats.favoriteCount }}</text>
        <text class="stat-label">收藏</text>
      </view>
      <view class="stat-divider"></view>
      <view class="stat-item" @click="goToOrders">
        <text class="stat-value">{{ stats.orderCount }}</text>
        <text class="stat-label">订单</text>
      </view>
      <view class="stat-divider"></view>
      <view class="stat-item" @click="goToMyRecipes">
        <text class="stat-value">{{ stats.recipeCount }}</text>
        <text class="stat-label">菜谱</text>
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
        <view class="menu-badge" v-if="item.badge">
          <text class="badge-text">{{ item.badge }}</text>
        </view>
        <text class="menu-arrow">></text>
      </view>
    </view>

    <!-- 编辑资料弹窗 -->
    <view class="edit-modal" v-if="showEditDialog" @click="closeEditDialog">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="header-title">编辑资料</text>
          <view class="close-btn" @click="closeEditDialog">
            <text class="close-icon">×</text>
          </view>
        </view>

        <view class="modal-body">
          <!-- 头像编辑 -->
          <view class="edit-avatar" @click="chooseAvatar">
            <image
              class="avatar-preview"
              :src="editForm.avatar || defaultAvatar"
              mode="aspectFill"
            />
            <view class="avatar-overlay">
              <text class="overlay-text">更换头像</text>
            </view>
          </view>

          <!-- 昵称编辑 -->
          <view class="edit-field">
            <text class="field-label">昵称</text>
            <input
              class="field-input"
              v-model="editForm.nickname"
              type="text"
              placeholder="请输入昵称"
              maxlength="20"
            />
          </view>
        </view>

        <view class="modal-footer">
          <button class="btn-cancel" @click="closeEditDialog">取消</button>
          <button class="btn-save" @click="saveProfile" :disabled="isSaving">
            {{ isSaving ? '保存中...' : '保存' }}
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { AuthService } from '@/api/auth'
import { OrderService } from '@/api/order'

// 用户信息
const userInfo = ref({
  nickname: '',
  avatar: '',
  role: 'member'
})

// 统计数据
const stats = reactive({
  favoriteCount: 0,
  orderCount: 0,
  recipeCount: 0
})

// 编辑弹窗状态
const showEditDialog = ref(false)
const isSaving = ref(false)
const editForm = reactive({
  nickname: '',
  avatar: ''
})

// 默认头像
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
    name: '我的收藏',
    icon: '❤️',
    action: 'favorites'
  },
  {
    id: 3,
    name: '访客分享',
    icon: '🎁',
    action: 'guest-demo',
    badge: 'NEW'
  },
  {
    id: 4,
    name: '关于',
    icon: 'ℹ️',
    action: 'about'
  }
]

// 页面加载时获取用户信息
onMounted(async () => {
  await loadUserInfo()
  await loadStats()
})

// 页面显示时刷新
onShow(async () => {
  await loadStats()
})

// 加载用户信息
const loadUserInfo = async () => {
  try {
    const localUserInfo = AuthService.getCurrentUser()
    if (localUserInfo) {
      userInfo.value = {
        nickname: localUserInfo.nickname || '',
        avatar: localUserInfo.avatar || '',
        role: localUserInfo.role || 'member'
      }
    }

    if (AuthService.isLoggedIn()) {
      const serverUserInfo = await AuthService.getUserProfile()
      userInfo.value = {
        nickname: serverUserInfo.nickname || '',
        avatar: serverUserInfo.avatar || '',
        role: serverUserInfo.role || 'member'
      }
    }
  } catch (error) {
    console.error('获取用户信息失败:', error)
    userInfo.value = {
      nickname: '未登录用户',
      avatar: '',
      role: 'member'
    }
  }
}

// 加载统计数据
const loadStats = async () => {
  try {
    const summary = await OrderService.getUserOrderSummary()
    stats.favoriteCount = summary.favorite_count || 0
    stats.orderCount = summary.total_orders || 0
    stats.recipeCount = summary.favorite_recipes?.length || 0
  } catch (error) {
    console.error('获取统计数据失败:', error)
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

// 显示编辑弹窗
const showEditProfile = () => {
  editForm.nickname = userInfo.value.nickname
  editForm.avatar = userInfo.value.avatar
  showEditDialog.value = true
}

// 关闭编辑弹窗
const closeEditDialog = () => {
  showEditDialog.value = false
}

// 选择头像
const chooseAvatar = () => {
  uni.chooseImage({
    count: 1,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: (res) => {
      editForm.avatar = res.tempFilePaths[0]
    }
  })
}

// 保存资料
const saveProfile = async () => {
  if (!editForm.nickname.trim()) {
    uni.showToast({
      title: '请输入昵称',
      icon: 'none'
    })
    return
  }

  try {
    isSaving.value = true

    await AuthService.updateProfile({
      nickname: editForm.nickname.trim()
    })

    userInfo.value.nickname = editForm.nickname.trim()
    if (editForm.avatar && editForm.avatar !== userInfo.value.avatar) {
      userInfo.value.avatar = editForm.avatar
    }

    uni.showToast({
      title: '保存成功',
      icon: 'success'
    })
    closeEditDialog()
  } catch (error) {
    console.error('保存失败:', error)
    uni.showToast({
      title: '保存失败',
      icon: 'none'
    })
  } finally {
    isSaving.value = false
  }
}

// 跳转到收藏页面
const goToFavorites = () => {
  uni.navigateTo({
    url: '/pages/favorites/index'
  })
}

// 跳转到订单页面
const goToOrders = () => {
  uni.switchTab({
    url: '/pages/orders/index'
  })
}

// 跳转到我的菜谱（菜谱页面会有筛选）
const goToMyRecipes = () => {
  uni.switchTab({
    url: '/pages/recipes/index'
  })
}

const handleMenuClick = (item: any) => {
  switch (item.action) {
    case 'family':
      uni.navigateTo({
        url: '/pages/family/index'
      })
      break
    case 'favorites':
      uni.navigateTo({
        url: '/pages/favorites/index'
      })
      break
    case 'guest-demo':
      uni.navigateTo({
        url: '/pages/demo/guest-flow'
      })
      break
    case 'about':
      uni.showModal({
        title: 'Love Order',
        content: '温馨的情侣/家庭点餐小程序\n\n版本: 1.0.0\n\n让每一餐都充满爱意 ❤️',
        showCancel: false,
        confirmText: '知道了'
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
@use '@/styles/design-system.scss' as *;

.profile-page {
  padding: 24rpx;
  min-height: 100vh;
  background: $bg-page;
}

.card {
  background: white;
  border-radius: $radius-lg;
  padding: 24rpx;
  box-shadow: $shadow-base;
}

.profile-header {
  margin-bottom: 24rpx;
}

.user-info {
  display: flex;
  align-items: center;

  .avatar-container {
    position: relative;
    margin-right: 24rpx;

    .avatar {
      width: 120rpx;
      height: 120rpx;
      border-radius: 50%;
      border: 4rpx solid $primary;
    }

    .edit-badge {
      position: absolute;
      right: -4rpx;
      bottom: -4rpx;
      width: 40rpx;
      height: 40rpx;
      border-radius: 50%;
      background: $gradient-primary;
      @include flex-center;
      border: 2rpx solid white;

      .badge-icon {
        font-size: 20rpx;
      }
    }
  }

  .user-details {
    flex: 1;

    .username {
      display: block;
      font-size: $font-size-xl;
      font-weight: $font-weight-bold;
      color: $text-primary;
      margin-bottom: 8rpx;
    }

    .user-role {
      display: block;
      font-size: $font-size-sm;
      color: $primary;
      margin-bottom: 8rpx;
    }

    .edit-hint {
      font-size: $font-size-xs;
      color: $text-tertiary;
    }
  }
}

// 统计区域
.stats-section {
  display: flex;
  align-items: center;
  justify-content: space-around;
  margin-bottom: 24rpx;

  .stat-item {
    flex: 1;
    @include flex-center;
    flex-direction: column;
    padding: 16rpx 0;

    .stat-value {
      font-size: 40rpx;
      font-weight: $font-weight-bold;
      color: $primary;
      margin-bottom: 8rpx;
    }

    .stat-label {
      font-size: $font-size-sm;
      color: $text-secondary;
    }
  }

  .stat-divider {
    width: 1rpx;
    height: 48rpx;
    background: $border-light;
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

  .menu-icon {
    font-size: 36rpx;
    margin-right: 24rpx;
  }

  .menu-text {
    flex: 1;
    font-size: $font-size-base;
    color: $text-primary;
  }

  .menu-badge {
    margin-right: 12rpx;
    padding: 4rpx 12rpx;
    background: $gradient-primary;
    border-radius: $radius-sm;

    .badge-text {
      font-size: 20rpx;
      color: white;
      font-weight: $font-weight-bold;
    }
  }

  .menu-arrow {
    font-size: $font-size-base;
    color: $text-tertiary;
  }
}

// 编辑资料弹窗
.edit-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  @include flex-center;
  z-index: 1000;
  padding: 40rpx;

  .modal-content {
    width: 100%;
    max-width: 600rpx;
    background: white;
    border-radius: $radius-xl;
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 32rpx 24rpx;
    border-bottom: 1rpx solid $border-light;

    .header-title {
      font-size: $font-size-xl;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }

    .close-btn {
      width: 56rpx;
      height: 56rpx;
      @include flex-center;
      border-radius: 50%;
      background: $bg-section;

      .close-icon {
        font-size: 48rpx;
        color: $text-tertiary;
        line-height: 1;
      }
    }
  }

  .modal-body {
    padding: 32rpx 24rpx;

    .edit-avatar {
      width: 160rpx;
      height: 160rpx;
      margin: 0 auto 32rpx;
      position: relative;
      border-radius: 50%;
      overflow: hidden;

      .avatar-preview {
        width: 100%;
        height: 100%;
      }

      .avatar-overlay {
        position: absolute;
        bottom: 0;
        left: 0;
        right: 0;
        height: 48rpx;
        background: rgba(0, 0, 0, 0.5);
        @include flex-center;

        .overlay-text {
          font-size: $font-size-xs;
          color: white;
        }
      }
    }

    .edit-field {
      .field-label {
        display: block;
        font-size: $font-size-sm;
        color: $text-secondary;
        margin-bottom: 12rpx;
      }

      .field-input {
        width: 100%;
        height: 88rpx;
        background: $bg-section;
        border: 1rpx solid $border-light;
        border-radius: $radius-md;
        padding: 0 20rpx;
        font-size: $font-size-base;
        color: $text-primary;

        &:focus {
          border-color: $primary;
        }
      }
    }
  }

  .modal-footer {
    display: flex;
    gap: 16rpx;
    padding: 16rpx 24rpx 32rpx;

    .btn-cancel,
    .btn-save {
      flex: 1;
      height: 88rpx;
      border-radius: $radius-button;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      border: none;
    }

    .btn-cancel {
      background: $bg-section;
      color: $text-primary;
    }

    .btn-save {
      background: $gradient-primary;
      color: white;
      box-shadow: $shadow-primary;

      &:disabled {
        opacity: 0.5;
      }
    }
  }
}
</style>
