<template>
  <view class="family-page">
    <!-- 家庭信息卡片 -->
    <view class="family-info card" v-if="familyInfo">
      <view class="family-header">
        <view class="family-avatar-container">
          <image
            class="family-avatar"
            :src="familyInfo.avatar || defaultFamilyAvatar"
            mode="aspectFill"
          />
          <view class="family-avatar-badge">
            <text class="badge-text">{{ members.length }}</text>
          </view>
        </view>
        <view class="family-details">
          <text class="family-name">{{ familyInfo.name }}</text>
          <text class="family-desc">{{ familyInfo.description || '温馨的家庭' }}</text>
          <view class="invite-code-container" @click="copyInviteCode">
            <text class="invite-code-label">邀请码</text>
            <text class="invite-code">{{ familyInfo.invite_code }}</text>
            <text class="copy-icon">📋</text>
          </view>
        </view>
      </view>

      <!-- 家庭统计 -->
      <view class="family-stats">
        <view class="stat-item">
          <text class="stat-number">{{ members.length }}</text>
          <text class="stat-label">成员</text>
        </view>
        <view class="stat-divider"></view>
        <view class="stat-item">
          <text class="stat-number">0</text>
          <text class="stat-label">菜谱</text>
        </view>
        <view class="stat-divider"></view>
        <view class="stat-item">
          <text class="stat-number">0</text>
          <text class="stat-label">订单</text>
        </view>
      </view>
    </view>

    <!-- 无家庭状态 -->
    <view class="no-family card" v-if="!familyInfo && !isLoading">
      <view class="no-family-illustration">
        <view class="illustration-bg">
          <text class="illustration-icon">🏠</text>
        </view>
        <view class="illustration-dots">
          <view class="dot dot-1"></view>
          <view class="dot dot-2"></view>
          <view class="dot dot-3"></view>
        </view>
      </view>

      <text class="no-family-title">欢迎来到 Love Order</text>
      <text class="no-family-subtitle">温馨家庭，美味共享</text>
      <text class="no-family-desc">创建或加入家庭后，即可开始使用菜谱和订餐功能，与家人一起享受美好的用餐时光</text>

      <view class="family-actions">
        <button class="action-btn primary" @click="showFamilyModal = true">
          <text class="btn-icon">🏠</text>
          <text class="btn-text">开始使用</text>
        </button>
      </view>

      <view class="features-preview">
        <view class="feature-item">
          <text class="feature-icon">👨‍👩‍👧‍👦</text>
          <text class="feature-text">家庭成员管理</text>
        </view>
        <view class="feature-item">
          <text class="feature-icon">📖</text>
          <text class="feature-text">共享菜谱库</text>
        </view>
        <view class="feature-item">
          <text class="feature-icon">🛒</text>
          <text class="feature-text">便捷点餐体验</text>
        </view>
      </view>
    </view>

    <!-- 快捷操作卡片 -->
    <view class="quick-actions card" v-if="familyInfo">
      <view class="actions-header">
        <text class="actions-title">快捷操作</text>
      </view>

      <view class="actions-grid">
        <view class="action-item" @click="goToGuestShare">
          <view class="action-icon-bg primary">
            <text class="action-icon">🎁</text>
          </view>
          <text class="action-title">邀请朋友</text>
          <text class="action-desc">分享家庭菜谱</text>
        </view>

        <view class="action-item" @click="copyInviteCode">
          <view class="action-icon-bg secondary">
            <text class="action-icon">📋</text>
          </view>
          <text class="action-title">复制邀请码</text>
          <text class="action-desc">家庭成员邀请</text>
        </view>

        <view class="action-item" @click="manageRecipes">
          <view class="action-icon-bg success">
            <text class="action-icon">📖</text>
          </view>
          <text class="action-title">管理菜谱</text>
          <text class="action-desc">添加编辑菜谱</text>
        </view>

        <view class="action-item" @click="viewOrders">
          <view class="action-icon-bg warning">
            <text class="action-icon">📊</text>
          </view>
          <text class="action-title">订单统计</text>
          <text class="action-desc">查看订单数据</text>
        </view>
      </view>
    </view>

    <!-- 家庭成员列表 -->
    <view class="members-section card" v-if="familyInfo">
      <view class="section-header">
        <text class="section-title">家庭成员</text>
        <view class="member-count-badge">
          <text class="count-text">{{ members.length }}</text>
        </view>
      </view>

      <view class="members-grid">
        <view
          class="member-card"
          v-for="member in members"
          :key="member.id"
        >
          <view class="member-avatar-container">
            <image
              class="member-avatar"
              :src="member.avatar || defaultAvatar"
              mode="aspectFill"
            />
            <view class="member-role-badge" :class="member.role">
              <text class="role-text">{{ getRoleText(member.role) }}</text>
            </view>
          </view>
          <text class="member-name">{{ member.nickname }}</text>
          <text class="member-join-date">{{ formatJoinDate(member.created_at) }}</text>
        </view>

        <!-- 添加成员卡片 -->
        <view class="member-card add-member" @click="showAddMember">
          <view class="add-member-icon">
            <text class="add-icon">+</text>
          </view>
          <text class="add-member-text">邀请成员</text>
        </view>
      </view>
    </view>

    <!-- 家庭设置 -->
    <view class="family-settings card" v-if="familyInfo">
      <view class="settings-header">
        <text class="settings-title">家庭设置</text>
      </view>

      <view class="settings-list">
        <view class="setting-item" @click="editFamilyInfo">
          <view class="setting-icon">
            <text class="icon">✏️</text>
          </view>
          <view class="setting-content">
            <text class="setting-title">编辑家庭信息</text>
            <text class="setting-desc">修改家庭名称和描述</text>
          </view>
          <text class="setting-arrow">></text>
        </view>

        <view class="setting-item" @click="familyPrivacy">
          <view class="setting-icon">
            <text class="icon">🔒</text>
          </view>
          <view class="setting-content">
            <text class="setting-title">隐私设置</text>
            <text class="setting-desc">管理家庭隐私权限</text>
          </view>
          <text class="setting-arrow">></text>
        </view>

        <view class="setting-item" @click="familyNotification">
          <view class="setting-icon">
            <text class="icon">🔔</text>
          </view>
          <view class="setting-content">
            <text class="setting-title">通知设置</text>
            <text class="setting-desc">订单和活动通知</text>
          </view>
          <text class="setting-arrow">></text>
        </view>
      </view>
    </view>

    <!-- 危险操作区域 -->
    <view class="danger-zone card" v-if="familyInfo">
      <view class="danger-header">
        <text class="danger-title">危险操作</text>
      </view>

      <view class="danger-actions">
        <button class="danger-btn" @click="showLeaveConfirm = true">
          <text class="btn-icon">🚪</text>
          <text class="btn-text">退出家庭</text>
        </button>
      </view>
    </view>

    <!-- 创建/加入家庭弹窗 -->
    <view class="family-modal" v-if="showFamilyModal" @click="closeFamilyModal">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="modal-title">开始您的家庭之旅</text>
          <text class="modal-close" @click="closeFamilyModal">✕</text>
        </view>

        <view class="modal-tabs">
          <view
            class="tab-item"
            :class="{ active: activeTab === 'create' }"
            @click="activeTab = 'create'"
          >
            <text class="tab-icon">✨</text>
            <text class="tab-text">创建家庭</text>
          </view>
          <view
            class="tab-item"
            :class="{ active: activeTab === 'join' }"
            @click="activeTab = 'join'"
          >
            <text class="tab-icon">🔗</text>
            <text class="tab-text">加入家庭</text>
          </view>
        </view>

        <!-- 创建家庭表单 -->
        <view class="tab-content" v-if="activeTab === 'create'">
          <view class="form-section">
            <view class="form-item">
              <text class="form-label">家庭名称</text>
              <input
                class="form-input"
                v-model="createForm.name"
                placeholder="给您的家庭起个温馨的名字"
                maxlength="20"
              />
            </view>

            <view class="form-item">
              <text class="form-label">家庭描述</text>
              <textarea
                class="form-textarea"
                v-model="createForm.description"
                placeholder="描述一下您的家庭特色（可选）"
                maxlength="100"
              />
            </view>
          </view>

          <view class="form-tips">
            <text class="tips-icon">💡</text>
            <text class="tips-text">创建家庭后，您将成为家庭管理员，可以邀请其他成员加入</text>
          </view>

          <button
            class="submit-btn create-btn"
            :disabled="!createForm.name.trim() || isCreating"
            @click="handleCreateFamily"
          >
            <text class="btn-icon">✨</text>
            <text class="btn-text">{{ isCreating ? '创建中...' : '创建我的家庭' }}</text>
          </button>
        </view>

        <!-- 加入家庭表单 -->
        <view class="tab-content" v-if="activeTab === 'join'">
          <view class="form-section">
            <view class="form-item">
              <text class="form-label">家庭邀请码</text>
              <input
                class="form-input invite-input"
                v-model="joinForm.inviteCode"
                placeholder="请输入6位邀请码"
                maxlength="20"
              />
            </view>
          </view>

          <view class="form-tips">
            <text class="tips-icon">🔍</text>
            <text class="tips-text">请向家庭管理员获取邀请码，输入后即可加入家庭</text>
          </view>

          <button
            class="submit-btn join-btn"
            :disabled="!joinForm.inviteCode.trim() || isJoining"
            @click="handleJoinFamily"
          >
            <text class="btn-icon">🔗</text>
            <text class="btn-text">{{ isJoining ? '加入中...' : '加入家庭' }}</text>
          </button>
        </view>
      </view>
    </view>

    <!-- 退出家庭确认弹窗 -->
    <view class="confirm-modal" v-if="showLeaveConfirm" @click="showLeaveConfirm = false">
      <view class="confirm-content" @click.stop>
        <view class="confirm-icon">
          <text class="icon">⚠️</text>
        </view>

        <text class="confirm-title">确认退出家庭？</text>
        <text class="confirm-message">
          退出后您将无法访问家庭的菜谱和订单数据，如需重新加入需要邀请码
        </text>

        <view class="confirm-actions">
          <button class="confirm-btn cancel" @click="showLeaveConfirm = false">
            取消
          </button>
          <button
            class="confirm-btn danger"
            :disabled="isLeaving"
            @click="handleLeaveFamily"
          >
            {{ isLeaving ? '退出中...' : '确认退出' }}
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { AuthService } from '@/api/auth'
import { FamilyService } from '@/api/family'

// 响应式数据
const isLoading = ref(true)
const familyInfo = ref(null)
const members = ref([])

// 弹窗控制
const showFamilyModal = ref(false)
const showLeaveConfirm = ref(false)
const activeTab = ref('create')

// 表单数据
const createForm = ref({
  name: '',
  description: ''
})

const joinForm = ref({
  inviteCode: ''
})

// 操作状态
const isCreating = ref(false)
const isJoining = ref(false)
const isLeaving = ref(false)

// 默认头像
const defaultAvatar = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiByeD0iMjAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjIwIiB5PSIyNiIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjE2IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+RpDwvdGV4dD4KPHN2Zz4=')
const defaultFamilyAvatar = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjYwIiBoZWlnaHQ9IjYwIiByeD0iMzAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjMwIiB5PSIzOCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjI0IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+PoDwvdGV4dD4KPHN2Zz4=')

// 页面加载
onMounted(async () => {
  await loadFamilyInfo()
})

// 监听弹窗状态
watch(showFamilyModal, (newVal) => {
  if (newVal) {
    // 重置表单
    createForm.value = { name: '', description: '' }
    joinForm.value = { inviteCode: '' }
    activeTab.value = 'create'
  }
})

// 关闭家庭模态框
const closeFamilyModal = () => {
  showFamilyModal.value = false
}

// 显示家庭模态框（只在没有家庭时显示）
const showFamilyModalIfNeeded = () => {
  if (!familyInfo.value) {
    showFamilyModal.value = true
  }
}

// 加载家庭信息
const loadFamilyInfo = async () => {
  try {
    isLoading.value = true

    // 检查用户是否有家庭
    if (!FamilyService.hasFamily()) {
      console.log('用户未加入家庭')
      familyInfo.value = null
      return
    }

    // 获取家庭信息和成员列表
    const [family, memberList] = await Promise.all([
      FamilyService.getFamilyInfo(),
      FamilyService.getFamilyMembers(true) // 包含访客
    ])

    familyInfo.value = family
    members.value = memberList

    console.log('家庭信息:', family)
    console.log('成员列表:', memberList)

  } catch (error: any) {
    console.error('加载家庭信息失败:', error)

    // 如果是权限错误，说明用户没有家庭
    if (error.statusCode === 403 || error.statusCode === 400) {
      familyInfo.value = null
      members.value = []
    } else {
      uni.showToast({
        title: '加载失败',
        icon: 'error'
      })
    }
  } finally {
    isLoading.value = false
  }
}

// 获取角色文本
const getRoleText = (role: string) => {
  switch (role) {
    case 'admin':
      return '管理员'
    case 'member':
      return '成员'
    case 'guest':
      return '访客'
    default:
      return '成员'
  }
}

// 创建家庭
const handleCreateFamily = async () => {
  if (!createForm.value.name.trim()) {
    uni.showToast({
      title: '请输入家庭名称',
      icon: 'none'
    })
    return
  }

  try {
    isCreating.value = true

    const family = await FamilyService.createFamily(createForm.value)
    console.log('创建家庭成功:', family)

    // 更新本地用户信息
    const currentUser = AuthService.getCurrentUser()
    if (currentUser) {
      currentUser.family_id = family.id
      uni.setStorageSync('user_info', currentUser)
    }

    uni.showToast({
      title: '创建成功',
      icon: 'success'
    })

    showFamilyModal.value = false
    await loadFamilyInfo()

  } catch (error: any) {
    console.error('创建家庭失败:', error)
    uni.showToast({
      title: error.message || '创建失败',
      icon: 'error'
    })
  } finally {
    isCreating.value = false
  }
}

// 加入家庭
const handleJoinFamily = async () => {
  if (!joinForm.value.inviteCode.trim()) {
    uni.showToast({
      title: '请输入邀请码',
      icon: 'none'
    })
    return
  }

  try {
    isJoining.value = true

    const family = await FamilyService.joinFamily({
      invite_code: joinForm.value.inviteCode.trim()
    })
    console.log('加入家庭成功:', family)

    // 更新本地用户信息
    const currentUser = AuthService.getCurrentUser()
    if (currentUser) {
      currentUser.family_id = family.id
      uni.setStorageSync('user_info', currentUser)
    }

    uni.showToast({
      title: '加入成功',
      icon: 'success'
    })

    showFamilyModal.value = false
    await loadFamilyInfo()

  } catch (error: any) {
    console.error('加入家庭失败:', error)
    uni.showToast({
      title: error.message || '加入失败',
      icon: 'error'
    })
  } finally {
    isJoining.value = false
  }
}

// 退出家庭
const handleLeaveFamily = async () => {
  try {
    isLeaving.value = true

    await FamilyService.leaveFamily()
    console.log('退出家庭成功')

    // 清除本地用户的家庭信息
    const currentUser = AuthService.getCurrentUser()
    if (currentUser) {
      currentUser.family_id = null
      uni.setStorageSync('user_info', currentUser)
    }

    uni.showToast({
      title: '已退出家庭',
      icon: 'success'
    })

    showLeaveConfirm.value = false
    await loadFamilyInfo()

  } catch (error: any) {
    console.error('退出家庭失败:', error)
    uni.showToast({
      title: error.message || '退出失败',
      icon: 'error'
    })
  } finally {
    isLeaving.value = false
  }
}

// 前往访客分享页面
const goToGuestShare = () => {
  uni.navigateTo({
    url: '/pages/guest/share'
  })
}

// 管理菜谱
const manageRecipes = () => {
  uni.navigateTo({
    url: '/pages/recipes/index'
  })
}

// 查看订单统计
const viewOrders = () => {
  uni.navigateTo({
    url: '/pages/orders/index'
  })
}

// 显示添加成员
const showAddMember = () => {
  uni.showModal({
    title: '邀请成员',
    content: `分享家庭邀请码给新成员：${familyInfo.value?.invite_code}`,
    confirmText: '复制邀请码',
    success: (res) => {
      if (res.confirm) {
        copyInviteCode()
      }
    }
  })
}

// 编辑家庭信息
const editFamilyInfo = () => {
  uni.showToast({
    title: '功能开发中',
    icon: 'none'
  })
}

// 家庭隐私设置
const familyPrivacy = () => {
  uni.showToast({
    title: '功能开发中',
    icon: 'none'
  })
}

// 家庭通知设置
const familyNotification = () => {
  uni.showToast({
    title: '功能开发中',
    icon: 'none'
  })
}

// 复制邀请码
const copyInviteCode = () => {
  if (!familyInfo.value?.invite_code) return

  uni.setClipboardData({
    data: familyInfo.value.invite_code,
    success: () => {
      uni.showToast({
        title: '邀请码已复制',
        icon: 'success'
      })
    }
  })
}

// 格式化加入日期
const formatJoinDate = (dateStr: string) => {
  const date = new Date(dateStr)
  const now = new Date()
  const diffTime = now.getTime() - date.getTime()
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))

  if (diffDays === 0) {
    return '今天加入'
  } else if (diffDays === 1) {
    return '昨天加入'
  } else if (diffDays < 30) {
    return `${diffDays}天前加入`
  } else {
    return `${date.getMonth() + 1}/${date.getDate()} 加入`
  }
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.family-page {
  padding: $spacing-base;
  background: linear-gradient(180deg, #FAFAFA 0%, #FFFFFF 100%);
  min-height: 100vh;
}

.card {
  background-color: $bg-card;
  border-radius: $radius-lg;
  box-shadow: $shadow-base;
  margin-bottom: $spacing-base;
}

// 家庭信息卡片
.family-info {
  padding: $spacing-xl;
  background: $gradient-primary;
  color: white;
  position: relative;
  overflow: hidden;

  &::before {
    content: '';
    position: absolute;
    top: -50%;
    right: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
    animation: float 6s ease-in-out infinite;
  }

  .family-header {
    display: flex;
    align-items: center;
    margin-bottom: $spacing-xl;
    position: relative;
    z-index: 2;

    .family-avatar-container {
      position: relative;
      margin-right: $spacing-lg;

      .family-avatar {
        width: 120rpx;
        height: 120rpx;
        border-radius: 60rpx;
        border: 4rpx solid rgba(255, 255, 255, 0.3);
      }

      .family-avatar-badge {
        position: absolute;
        top: -8rpx;
        right: -8rpx;
        width: 40rpx;
        height: 40rpx;
        background-color: $success;
        border-radius: 20rpx;
        @include flex-center;
        border: 3rpx solid white;

        .badge-text {
          font-size: $font-size-xxs;
          color: white;
          font-weight: $font-weight-bold;
        }
      }
    }

    .family-details {
      flex: 1;

      .family-name {
        display: block;
        font-size: $font-size-xl;
        font-weight: $font-weight-bold;
        color: white;
        margin-bottom: $spacing-xs;
      }

      .family-desc {
        display: block;
        font-size: $font-size-base;
        color: rgba(255, 255, 255, 0.9);
        margin-bottom: $spacing-md;
      }

      .invite-code-container {
        display: flex;
        align-items: center;
        background-color: rgba(255, 255, 255, 0.2);
        padding: $spacing-sm $spacing-md;
        border-radius: $radius-button;
        backdrop-filter: blur(10rpx);

        .invite-code-label {
          font-size: $font-size-xs;
          color: rgba(255, 255, 255, 0.8);
          margin-right: $spacing-sm;
        }

        .invite-code {
          font-size: $font-size-base;
          color: white;
          font-weight: $font-weight-bold;
          font-family: 'Courier New', monospace;
          flex: 1;
        }

        .copy-icon {
          font-size: $font-size-xs;
          margin-left: $spacing-sm;
        }
      }
    }
  }

  .family-stats {
    display: flex;
    align-items: center;
    justify-content: space-around;
    background-color: rgba(255, 255, 255, 0.15);
    padding: $spacing-lg;
    border-radius: $radius-md;
    backdrop-filter: blur(10rpx);
    position: relative;
    z-index: 2;

    .stat-item {
      display: flex;
      flex-direction: column;
      align-items: center;

      .stat-number {
        font-size: $font-size-xl;
        font-weight: $font-weight-bold;
        color: white;
        margin-bottom: 4rpx;
      }

      .stat-label {
        font-size: $font-size-xs;
        color: rgba(255, 255, 255, 0.8);
      }
    }

    .stat-divider {
      width: 2rpx;
      height: 40rpx;
      background-color: rgba(255, 255, 255, 0.3);
    }
  }
}

@keyframes float {
  0%, 100% { transform: translateY(0px) rotate(0deg); }
  50% { transform: translateY(-20px) rotate(180deg); }
}

// 无家庭状态
.no-family {
  @include flex-center;
  flex-direction: column;
  padding: 80rpx 40rpx 100rpx;
  text-align: center;

  .no-family-illustration {
    position: relative;
    margin-bottom: $spacing-xxl;

    .illustration-bg {
      width: 200rpx;
      height: 200rpx;
      background: $gradient-primary;
      border-radius: 100rpx;
      @include flex-center;
      box-shadow: 0 20rpx 40rpx rgba(255, 138, 101, 0.3);
      animation: pulse 2s ease-in-out infinite;

      .illustration-icon {
        font-size: 80rpx;
        color: white;
      }
    }

    .illustration-dots {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);

      .dot {
        position: absolute;
        width: 12rpx;
        height: 12rpx;
        background-color: $primary;
        border-radius: 6rpx;
        opacity: 0.6;

        &.dot-1 {
          top: -120rpx;
          left: -60rpx;
          animation: float-dot 3s ease-in-out infinite;
        }

        &.dot-2 {
          top: -80rpx;
          right: -80rpx;
          animation: float-dot 3s ease-in-out infinite 1s;
        }

        &.dot-3 {
          bottom: -100rpx;
          left: -40rpx;
          animation: float-dot 3s ease-in-out infinite 2s;
        }
      }
    }
  }

  .no-family-title {
    font-size: $font-size-xl;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: $spacing-xs;
  }

  .no-family-subtitle {
    font-size: $font-size-base;
    color: $primary;
    margin-bottom: $spacing-lg;
    font-weight: $font-weight-medium;
  }

  .no-family-desc {
    font-size: $font-size-base;
    color: $text-secondary;
    line-height: $line-height-base;
    margin-bottom: $spacing-xxl;
    max-width: 500rpx;
  }

  .family-actions {
    display: flex;
    gap: $spacing-lg;
    justify-content: center;
    margin-bottom: 60rpx;
    width: 100%;

    .action-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: $spacing-sm;
      padding: $spacing-lg $spacing-xxl;
      border-radius: $radius-button;
      font-weight: $font-weight-bold;
      border: none;
      box-shadow: $shadow-base;
      transition: all $duration-base;
      min-height: 96rpx;

      &.primary {
        background: $gradient-primary;
        color: white;

        &:active {
          transform: translateY(2rpx);
          box-shadow: $shadow-primary;
        }
      }

      &.secondary {
        background-color: white;
        color: $text-primary;
        border: 2rpx solid $border-base;

        &:active {
          transform: translateY(2rpx);
          background-color: $bg-section;
        }
      }

      .btn-icon {
        font-size: $font-size-xs;
      }

      .btn-text {
        font-size: $font-size-base;
      }
    }
  }

  .features-preview {
    display: flex;
    justify-content: space-around;
    width: 100%;
    max-width: 600rpx;
    margin-top: 80rpx;

    .feature-item {
      display: flex;
      flex-direction: column;
      align-items: center;
      opacity: 0.8;

      .feature-icon {
        font-size: 48rpx;
        margin-bottom: $spacing-sm;
      }

      .feature-text {
        font-size: $font-size-xs;
        color: $text-secondary;
        text-align: center;
      }
    }
  }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}

@keyframes float-dot {
  0%, 100% { transform: translateY(0px); opacity: 0.6; }
  50% { transform: translateY(-20rpx); opacity: 1; }
}

// 快捷操作
.quick-actions {
  padding: $spacing-xl;

  .actions-header {
    margin-bottom: $spacing-lg;

    .actions-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .actions-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 20rpx;

    .action-item {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: $spacing-xl $spacing-md;
      background-color: $bg-section;
      border-radius: $radius-md;
      transition: all $duration-base;

      &:active {
        transform: scale(0.95);
        background-color: $bg-hover;
      }

      .action-icon-bg {
        width: 80rpx;
        height: 80rpx;
        border-radius: 40rpx;
        @include flex-center;
        margin-bottom: $spacing-md;

        &.primary {
          background: $gradient-primary;
        }

        &.secondary {
          background: $gradient-secondary;
        }

        &.success {
          background: linear-gradient(135deg, #66BB6A 0%, #43A047 100%);
        }

        &.warning {
          background: linear-gradient(135deg, #FFA726 0%, #FB8C00 100%);
        }

        .action-icon {
          font-size: $font-size-xl;
          color: white;
        }
      }

      .action-title {
        font-size: $font-size-sm;
        font-weight: $font-weight-bold;
        color: $text-primary;
        margin-bottom: 4rpx;
      }

      .action-desc {
        font-size: $font-size-xxs;
        color: $text-secondary;
        text-align: center;
      }
    }
  }
}

// 成员列表
.members-section {
  padding: $spacing-xl;

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: $spacing-lg;

    .section-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }

    .member-count-badge {
      background-color: $primary;
      color: white;
      padding: $spacing-xs $spacing-md;
      border-radius: $radius-button;

      .count-text {
        font-size: $font-size-xs;
        font-weight: $font-weight-bold;
      }
    }
  }

  .members-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20rpx;

    .member-card {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: $spacing-lg $spacing-md;
      background-color: $bg-section;
      border-radius: $radius-md;
      transition: all $duration-base;

      &:active {
        transform: scale(0.95);
      }

      .member-avatar-container {
        position: relative;
        margin-bottom: $spacing-md;

        .member-avatar {
          width: 80rpx;
          height: 80rpx;
          border-radius: 40rpx;
          border: 3rpx solid white;
          box-shadow: $shadow-sm;
        }

        .member-role-badge {
          position: absolute;
          bottom: -8rpx;
          left: 50%;
          transform: translateX(-50%);
          padding: 4rpx $spacing-sm;
          border-radius: $radius-sm;

          &.admin {
            background-color: $primary;
          }

          &.member {
            background-color: $info;
          }

          &.guest {
            background-color: $success;
          }

          .role-text {
            font-size: $font-size-xxs;
            color: white;
            font-weight: $font-weight-bold;
          }
        }
      }

      .member-name {
        font-size: $font-size-xs;
        font-weight: $font-weight-bold;
        color: $text-primary;
        margin-bottom: 4rpx;
        text-align: center;
        @include text-ellipsis(1);
        width: 100%;
      }

      .member-join-date {
        font-size: $font-size-xxs;
        color: $text-tertiary;
        text-align: center;
      }

      &.add-member {
        border: 2rpx dashed $border-base;
        background-color: transparent;

        .add-member-icon {
          width: 80rpx;
          height: 80rpx;
          border-radius: 40rpx;
          background-color: $bg-section;
          @include flex-center;
          margin-bottom: $spacing-md;

          .add-icon {
            font-size: 40rpx;
            color: $text-tertiary;
            font-weight: $font-weight-bold;
          }
        }

        .add-member-text {
          font-size: $font-size-xs;
          color: $text-secondary;
        }
      }
    }
  }
}

// 家庭设置
.family-settings {
  padding: $spacing-xl;

  .settings-header {
    margin-bottom: $spacing-lg;

    .settings-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .settings-list {
    .setting-item {
      display: flex;
      align-items: center;
      padding: $spacing-lg 0;
      border-bottom: 1rpx solid $border-light;
      transition: all $duration-base;

      &:last-child {
        border-bottom: none;
      }

      &:active {
        background-color: $bg-section;
        margin: 0 (-$spacing-xl);
        padding: $spacing-lg $spacing-xl;
        border-radius: $radius-base;
      }

      .setting-icon {
        width: 64rpx;
        height: 64rpx;
        background-color: $bg-section;
        border-radius: 32rpx;
        @include flex-center;
        margin-right: 20rpx;

        .icon {
          font-size: $font-size-base;
        }
      }

      .setting-content {
        flex: 1;

        .setting-title {
          display: block;
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
          margin-bottom: 4rpx;
        }

        .setting-desc {
          display: block;
          font-size: $font-size-xs;
          color: $text-secondary;
        }
      }

      .setting-arrow {
        font-size: $font-size-xs;
        color: $text-placeholder;
      }
    }
  }
}

// 危险操作区域
.danger-zone {
  padding: $spacing-xl;
  border: 2rpx solid rgba(244, 67, 54, 0.2);
  background-color: $bg-section;

  .danger-header {
    margin-bottom: $spacing-lg;

    .danger-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $danger;
    }
  }

  .danger-actions {
    .danger-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: $spacing-sm;
      width: 100%;
      padding: 20rpx;
      background-color: transparent;
      border: 2rpx solid $danger;
      border-radius: $radius-base;
      color: $danger;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      transition: all $duration-base;

      &:active {
        background-color: $danger;
        color: white;
      }

      .btn-icon {
        font-size: $font-size-xs;
      }
    }
  }
}

// 家庭模态框
.family-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  @include flex-center;
  z-index: 1000;

  .modal-content {
    width: 680rpx;
    max-height: 80vh;
    background-color: white;
    border-radius: $radius-xl;
    overflow: hidden;
    animation: modalSlideIn $duration-base ease-out;

    .modal-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: $spacing-xl;
      background: $gradient-primary;
      color: white;

      .modal-title {
        font-size: $font-size-lg;
        font-weight: $font-weight-bold;
      }

      .modal-close {
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background-color: rgba(255, 255, 255, 0.2);
        @include flex-center;
        font-size: $font-size-xs;
      }
    }

    .modal-tabs {
      display: flex;
      background-color: $bg-section;

      .tab-item {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: $spacing-lg;
        transition: all $duration-base;

        &.active {
          background-color: white;
          color: $primary;
        }

        .tab-icon {
          font-size: $font-size-xl;
          margin-bottom: $spacing-xs;
        }

        .tab-text {
          font-size: $font-size-sm;
          font-weight: $font-weight-bold;
        }
      }
    }

    .tab-content {
      padding: $spacing-xl;

      .form-section {
        margin-bottom: $spacing-lg;

        .form-item {
          margin-bottom: $spacing-lg;

          .form-label {
            display: block;
            font-size: $font-size-base;
            color: $text-primary;
            font-weight: $font-weight-bold;
            margin-bottom: $spacing-sm;
          }

          .form-input, .form-textarea {
            width: 100%;
            padding: 20rpx;
            border: 2rpx solid $border-base;
            border-radius: $radius-base;
            font-size: $font-size-base;
            color: $text-primary;
            background-color: $bg-section;
            transition: border-color $duration-base;

            &:focus {
              border-color: $primary;
            }
          }

          .form-textarea {
            height: 120rpx;
            resize: none;
          }

          .invite-input {
            text-align: center;
            font-family: 'Courier New', monospace;
            font-weight: $font-weight-bold;
            letter-spacing: 4rpx;
          }
        }
      }

      .form-tips {
        display: flex;
        align-items: flex-start;
        padding: 20rpx;
        background-color: rgba(255, 152, 0, 0.1);
        border-radius: $radius-base;
        margin-bottom: $spacing-xl;

        .tips-icon {
          font-size: $font-size-xs;
          margin-right: $spacing-sm;
          margin-top: 2rpx;
        }

        .tips-text {
          flex: 1;
          font-size: $font-size-xs;
          color: $text-secondary;
          line-height: $line-height-base;
        }
      }

      .submit-btn {
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: $spacing-sm;
        padding: 20rpx;
        border-radius: $radius-base;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        border: none;
        transition: all $duration-base;

        &.create-btn {
          background: $gradient-primary;
          color: white;
          box-shadow: $shadow-primary;
        }

        &.join-btn {
          background: linear-gradient(135deg, #42A5F5 0%, #1E88E5 100%);
          color: white;
          box-shadow: 0 8rpx 24rpx rgba(66, 165, 245, 0.4);
        }

        &:disabled {
          opacity: 0.6;
          transform: none;
        }

        &:active:not(:disabled) {
          transform: scale(0.98);
        }

        .btn-icon {
          font-size: $font-size-xs;
        }
      }
    }
  }
}

// 确认模态框
.confirm-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  @include flex-center;
  z-index: 1000;

  .confirm-content {
    width: 600rpx;
    background-color: white;
    border-radius: $radius-xl;
    padding: $spacing-xxl $spacing-xl $spacing-xl;
    text-align: center;
    animation: modalSlideIn $duration-base ease-out;

    .confirm-icon {
      margin-bottom: $spacing-lg;

      .icon {
        font-size: 80rpx;
      }
    }

    .confirm-title {
      display: block;
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
      margin-bottom: $spacing-md;
    }

    .confirm-message {
      display: block;
      font-size: $font-size-sm;
      color: $text-secondary;
      line-height: $line-height-base;
      margin-bottom: $spacing-xxl;
    }

    .confirm-actions {
      display: flex;
      gap: $spacing-md;

      .confirm-btn {
        flex: 1;
        padding: $spacing-md $spacing-lg;
        border-radius: $radius-base;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        border: none;
        transition: all $duration-base;

        &.cancel {
          background-color: $bg-section;
          color: $text-primary;
        }

        &.danger {
          background-color: $danger;
          color: white;
        }

        &:disabled {
          opacity: 0.6;
        }

        &:active:not(:disabled) {
          transform: scale(0.95);
        }
      }
    }
  }
}

@keyframes modalSlideIn {
  from {
    opacity: 0;
    transform: translateY(-50rpx) scale(0.9);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}
</style>
