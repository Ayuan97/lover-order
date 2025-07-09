<template>
  <view class="guest-share-page">
    <!-- 页面头部 -->
    <view class="page-header">
      <text class="page-title">邀请朋友</text>
      <text class="page-subtitle">分享美味，共享温馨</text>
    </view>

    <!-- 家庭信息展示 -->
    <view class="family-preview card" v-if="familyInfo">
      <view class="family-header">
        <image 
          class="family-avatar" 
          :src="familyInfo.avatar || defaultFamilyAvatar" 
          mode="aspectFill"
        />
        <view class="family-details">
          <text class="family-name">{{ familyInfo.name }}</text>
          <text class="family-desc">{{ familyInfo.description || '温馨家庭料理' }}</text>
          <view class="family-stats">
            <text class="stat-item">{{ recipeCount }} 道菜谱</text>
            <text class="stat-divider">·</text>
            <text class="stat-item">{{ memberCount }} 位成员</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 邀请设置 -->
    <view class="invite-settings card">
      <view class="setting-header">
        <text class="setting-title">邀请设置</text>
      </view>
      
      <view class="setting-item">
        <text class="setting-label">有效期</text>
        <picker 
          mode="selector" 
          :value="selectedExpireIndex" 
          :range="expireOptions"
          range-key="label"
          @change="onExpireChange"
        >
          <view class="setting-value">
            {{ expireOptions[selectedExpireIndex].label }}
            <text class="setting-arrow">></text>
          </view>
        </picker>
      </view>
      
      <view class="setting-item">
        <text class="setting-label">备注信息</text>
        <input 
          class="setting-input" 
          v-model="inviteNote" 
          placeholder="为朋友添加一些说明（可选）"
          maxlength="50"
        />
      </view>
    </view>

    <!-- 当前邀请码 -->
    <view class="current-invite card" v-if="currentInvite">
      <view class="invite-header">
        <text class="invite-title">当前邀请</text>
        <text class="invite-status" :class="{ active: currentInvite.is_active }">
          {{ currentInvite.is_active ? '有效' : '已失效' }}
        </text>
      </view>
      
      <view class="invite-code-display" @click="copyInviteCode">
        <text class="invite-code">{{ currentInvite.invite_code }}</text>
        <text class="copy-icon">📋</text>
      </view>
      
      <view class="invite-info">
        <text class="invite-expire">有效期至：{{ formatDate(currentInvite.expires_at) }}</text>
        <text class="invite-usage">已使用：{{ currentInvite.used_count }} 次</text>
      </view>
      
      <view class="invite-actions">
        <button class="action-btn secondary" @click="shareInvite">
          <text class="btn-icon">📤</text>
          <text class="btn-text">分享邀请</text>
        </button>
        <button class="action-btn danger" @click="revokeInvite">
          <text class="btn-icon">🚫</text>
          <text class="btn-text">撤销邀请</text>
        </button>
      </view>
    </view>

    <!-- 创建邀请按钮 -->
    <view class="create-invite" v-if="!currentInvite || !currentInvite.is_active">
      <button 
        class="create-btn primary" 
        :disabled="isCreating"
        @click="createInvite"
      >
        <text class="btn-icon">✨</text>
        <text class="btn-text">{{ isCreating ? '创建中...' : '创建邀请' }}</text>
      </button>
    </view>

    <!-- 邀请历史 -->
    <view class="invite-history card" v-if="inviteHistory.length > 0">
      <view class="history-header">
        <text class="history-title">邀请历史</text>
      </view>
      
      <view class="history-list">
        <view 
          class="history-item" 
          v-for="invite in inviteHistory" 
          :key="invite.id"
        >
          <view class="history-info">
            <text class="history-code">{{ invite.invite_code }}</text>
            <text class="history-note" v-if="invite.note">{{ invite.note }}</text>
            <text class="history-date">{{ formatDate(invite.created_at) }}</text>
          </view>
          <view class="history-status">
            <text class="status-text" :class="{ active: invite.is_active }">
              {{ invite.is_active ? '有效' : '已失效' }}
            </text>
            <text class="usage-text">{{ invite.used_count }} 次使用</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 使用说明 -->
    <view class="usage-guide card">
      <view class="guide-header">
        <text class="guide-title">使用说明</text>
      </view>
      
      <view class="guide-content">
        <view class="guide-item">
          <text class="guide-icon">1️⃣</text>
          <text class="guide-text">创建邀请码并分享给朋友</text>
        </view>
        <view class="guide-item">
          <text class="guide-icon">2️⃣</text>
          <text class="guide-text">朋友通过邀请码进入访客模式</text>
        </view>
        <view class="guide-item">
          <text class="guide-icon">3️⃣</text>
          <text class="guide-text">访客可以浏览菜谱并下订单</text>
        </view>
        <view class="guide-item">
          <text class="guide-icon">4️⃣</text>
          <text class="guide-text">访客权限在有效期内自动失效</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { FamilyService, type GuestInvite } from '@/api/family'

// 响应式数据
const familyInfo = ref(null)
const currentInvite = ref<GuestInvite | null>(null)
const inviteHistory = ref<GuestInvite[]>([])
const isCreating = ref(false)

// 邀请设置
const inviteNote = ref('')
const selectedExpireIndex = ref(0)
const expireOptions = ref([
  { label: '1小时', value: 1 },
  { label: '3小时', value: 3 },
  { label: '6小时', value: 6 },
  { label: '12小时', value: 12 },
  { label: '1天', value: 24 },
  { label: '3天', value: 72 },
  { label: '7天', value: 168 }
])

// 统计数据
const recipeCount = ref(0)
const memberCount = ref(0)

// 默认头像
const defaultFamilyAvatar = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjYwIiBoZWlnaHQ9IjYwIiByeD0iMzAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjMwIiB5PSIzOCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjI0IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+PoDwvdGV4dD4KPHN2Zz4=')

// 页面加载
onMounted(async () => {
  await loadPageData()
})

// 加载页面数据
const loadPageData = async () => {
  try {
    // 检查是否有家庭
    if (!FamilyService.hasFamily()) {
      uni.showToast({
        title: '请先加入家庭',
        icon: 'none'
      })
      uni.navigateBack()
      return
    }

    // 加载家庭信息
    const [family, stats, invites] = await Promise.all([
      FamilyService.getFamilyInfo(),
      FamilyService.getFamilyStats(),
      FamilyService.getGuestInvites()
    ])

    familyInfo.value = family
    recipeCount.value = stats.recipe_count
    memberCount.value = stats.member_count

    // 处理邀请列表
    const activeInvite = invites.find(invite => invite.is_active)
    currentInvite.value = activeInvite || null
    inviteHistory.value = invites.filter(invite => !invite.is_active).slice(0, 5)

  } catch (error: any) {
    console.error('加载页面数据失败:', error)
    uni.showToast({
      title: '加载失败',
      icon: 'error'
    })
  }
}

// 有效期选择
const onExpireChange = (e: any) => {
  selectedExpireIndex.value = e.detail.value
}

// 创建邀请
const createInvite = async () => {
  try {
    isCreating.value = true

    const params = {
      note: inviteNote.value.trim() || undefined,
      expires_hours: expireOptions.value[selectedExpireIndex.value].value
    }

    const invite = await FamilyService.createGuestInvite(params)
    currentInvite.value = invite

    uni.showToast({
      title: '邀请创建成功',
      icon: 'success'
    })

    // 重置表单
    inviteNote.value = ''

  } catch (error: any) {
    console.error('创建邀请失败:', error)
    uni.showToast({
      title: error.message || '创建失败',
      icon: 'error'
    })
  } finally {
    isCreating.value = false
  }
}

// 复制邀请码
const copyInviteCode = () => {
  if (!currentInvite.value) return

  uni.setClipboardData({
    data: currentInvite.value.invite_code,
    success: () => {
      uni.showToast({
        title: '邀请码已复制',
        icon: 'success'
      })
    }
  })
}

// 分享邀请
const shareInvite = () => {
  if (!currentInvite.value || !familyInfo.value) return

  const shareText = FamilyService.generateShareText(
    familyInfo.value.name,
    currentInvite.value.invite_code
  )

  // 微信小程序分享
  uni.share({
    provider: 'weixin',
    scene: 'WXSceneSession',
    type: 0,
    title: `${familyInfo.value.name} 邀请您品尝美味`,
    summary: shareText,
    success: () => {
      uni.showToast({
        title: '分享成功',
        icon: 'success'
      })
    },
    fail: () => {
      // 如果分享失败，复制到剪贴板
      uni.setClipboardData({
        data: shareText,
        success: () => {
          uni.showToast({
            title: '分享内容已复制',
            icon: 'success'
          })
        }
      })
    }
  })
}

// 撤销邀请
const revokeInvite = () => {
  if (!currentInvite.value) return

  uni.showModal({
    title: '撤销邀请',
    content: '确定要撤销当前邀请吗？撤销后邀请码将立即失效。',
    success: async (res) => {
      if (res.confirm) {
        try {
          // TODO: 实现撤销邀请API
          // await FamilyService.revokeGuestInvite(currentInvite.value.id)
          
          uni.showToast({
            title: '邀请已撤销',
            icon: 'success'
          })
          
          await loadPageData()
        } catch (error: any) {
          uni.showToast({
            title: '撤销失败',
            icon: 'error'
          })
        }
      }
    }
  })
}

// 格式化日期
const formatDate = (dateStr: string) => {
  const date = new Date(dateStr)
  return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`
}
</script>

<style lang="scss" scoped>
.guest-share-page {
  padding: 24rpx;
  background-color: #FAFAFA;
  min-height: 100vh;
}

.card {
  background-color: #fff;
  border-radius: 16rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
  margin-bottom: 24rpx;
  overflow: hidden;
}

// 页面头部
.page-header {
  text-align: center;
  padding: 32rpx 0 48rpx;

  .page-title {
    display: block;
    font-size: 40rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 8rpx;
  }

  .page-subtitle {
    display: block;
    font-size: 28rpx;
    color: #FF8A65;
  }
}

// 家庭预览
.family-preview {
  padding: 32rpx;

  .family-header {
    display: flex;
    align-items: center;

    .family-avatar {
      width: 100rpx;
      height: 100rpx;
      border-radius: 50rpx;
      margin-right: 24rpx;
    }

    .family-details {
      flex: 1;

      .family-name {
        display: block;
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
        margin-bottom: 8rpx;
      }

      .family-desc {
        display: block;
        font-size: 26rpx;
        color: #666;
        margin-bottom: 12rpx;
      }

      .family-stats {
        display: flex;
        align-items: center;

        .stat-item {
          font-size: 24rpx;
          color: #999;
        }

        .stat-divider {
          margin: 0 12rpx;
          color: #DDD;
        }
      }
    }
  }
}

// 邀请设置
.invite-settings {
  padding: 32rpx;

  .setting-header {
    margin-bottom: 24rpx;

    .setting-title {
      font-size: 32rpx;
      font-weight: bold;
      color: #333;
    }
  }

  .setting-item {
    display: flex;
    align-items: center;
    padding: 20rpx 0;
    border-bottom: 1rpx solid #F0F0F0;

    &:last-child {
      border-bottom: none;
    }

    .setting-label {
      width: 120rpx;
      font-size: 28rpx;
      color: #333;
    }

    .setting-value {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 28rpx;
      color: #666;

      .setting-arrow {
        color: #CCC;
      }
    }

    .setting-input {
      flex: 1;
      font-size: 28rpx;
      color: #333;
    }
  }
}

// 当前邀请
.current-invite {
  padding: 32rpx;

  .invite-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24rpx;

    .invite-title {
      font-size: 32rpx;
      font-weight: bold;
      color: #333;
    }

    .invite-status {
      padding: 8rpx 16rpx;
      border-radius: 16rpx;
      font-size: 24rpx;
      background-color: #F5F5F5;
      color: #999;

      &.active {
        background-color: #E8F5E8;
        color: #4CAF50;
      }
    }
  }

  .invite-code-display {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background-color: #F8F8F8;
    padding: 20rpx 24rpx;
    border-radius: 12rpx;
    margin-bottom: 16rpx;

    .invite-code {
      font-size: 32rpx;
      font-weight: bold;
      color: #FF8A65;
      font-family: 'Courier New', monospace;
    }

    .copy-icon {
      font-size: 24rpx;
      color: #666;
    }
  }

  .invite-info {
    display: flex;
    justify-content: space-between;
    margin-bottom: 24rpx;

    .invite-expire, .invite-usage {
      font-size: 24rpx;
      color: #999;
    }
  }

  .invite-actions {
    display: flex;
    gap: 16rpx;

    .action-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8rpx;
      padding: 16rpx;
      border-radius: 12rpx;
      font-size: 26rpx;
      font-weight: bold;
      border: none;

      &.secondary {
        background-color: #F5F5F5;
        color: #333;
      }

      &.danger {
        background-color: #FFEBEE;
        color: #F44336;
      }

      .btn-icon {
        font-size: 20rpx;
      }
    }
  }
}

// 创建邀请
.create-invite {
  padding: 32rpx 0;
  text-align: center;

  .create-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 12rpx;
    padding: 20rpx 48rpx;
    background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
    color: white;
    border-radius: 50rpx;
    font-size: 28rpx;
    font-weight: bold;
    border: none;
    box-shadow: 0 8rpx 24rpx rgba(255, 138, 101, 0.4);

    &:disabled {
      opacity: 0.6;
    }

    .btn-icon {
      font-size: 24rpx;
    }
  }
}

// 邀请历史
.invite-history {
  padding: 32rpx;

  .history-header {
    margin-bottom: 24rpx;

    .history-title {
      font-size: 32rpx;
      font-weight: bold;
      color: #333;
    }
  }

  .history-list {
    .history-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 20rpx 0;
      border-bottom: 1rpx solid #F0F0F0;

      &:last-child {
        border-bottom: none;
      }

      .history-info {
        flex: 1;

        .history-code {
          display: block;
          font-size: 28rpx;
          font-weight: bold;
          color: #333;
          margin-bottom: 4rpx;
        }

        .history-note {
          display: block;
          font-size: 24rpx;
          color: #666;
          margin-bottom: 4rpx;
        }

        .history-date {
          display: block;
          font-size: 22rpx;
          color: #999;
        }
      }

      .history-status {
        text-align: right;

        .status-text {
          display: block;
          font-size: 24rpx;
          color: #999;
          margin-bottom: 4rpx;

          &.active {
            color: #4CAF50;
          }
        }

        .usage-text {
          display: block;
          font-size: 22rpx;
          color: #999;
        }
      }
    }
  }
}

// 使用说明
.usage-guide {
  padding: 32rpx;

  .guide-header {
    margin-bottom: 24rpx;

    .guide-title {
      font-size: 32rpx;
      font-weight: bold;
      color: #333;
    }
  }

  .guide-content {
    .guide-item {
      display: flex;
      align-items: flex-start;
      margin-bottom: 16rpx;

      .guide-icon {
        width: 48rpx;
        font-size: 24rpx;
        margin-right: 16rpx;
      }

      .guide-text {
        flex: 1;
        font-size: 26rpx;
        color: #666;
        line-height: 1.5;
      }
    }
  }
}
</style>
