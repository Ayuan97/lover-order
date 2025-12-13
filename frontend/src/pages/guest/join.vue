<template>
  <view class="guest-join">
    <!-- 欢迎头部 -->
    <view class="join-header">
      <view class="welcome-icon">🎉</view>
      <text class="welcome-title">受邀来做客</text>
      <text class="welcome-subtitle" v-if="familyInfo">
        {{ familyInfo.name || '朋友' }}邀请你来家里点餐
      </text>
    </view>

    <!-- 主内容 -->
    <view class="join-content">
      <!-- 步骤1：输入邀请码 -->
      <view class="step-section" v-if="currentStep === 1">
        <view class="section-title">
          <text class="step-number">1</text>
          <text class="title-text">输入邀请码</text>
        </view>
        <view class="input-group">
          <input
            class="invite-code-input"
            v-model="inviteCode"
            type="text"
            placeholder="请输入6位邀请码"
            maxlength="6"
            :disabled="isVerifying"
          />
          <button
            class="verify-btn"
            :class="{ disabled: inviteCode.length !== 6 || isVerifying }"
            @click="verifyInviteCode"
          >
            {{ isVerifying ? '验证中...' : '验证' }}
          </button>
        </view>
        <view class="input-hint">
          <text class="hint-icon">💡</text>
          <text class="hint-text">邀请码由主人分享给你</text>
        </view>
      </view>

      <!-- 步骤2：输入昵称 -->
      <view class="step-section" v-if="currentStep === 2">
        <view class="section-title">
          <text class="step-number">2</text>
          <text class="title-text">输入你的昵称</text>
        </view>
        <view class="input-group">
          <input
            class="nickname-input"
            v-model="nickname"
            type="text"
            placeholder="让主人知道你是谁"
            maxlength="20"
            :disabled="isJoining"
          />
        </view>
        <view class="input-hint">
          <text class="hint-icon">😊</text>
          <text class="hint-text">建议使用真实姓名或昵称</text>
        </view>

        <!-- 访客权限说明 -->
        <view class="guest-info">
          <view class="info-title">
            <text class="info-icon">ℹ️</text>
            <text class="info-text">访客权限说明</text>
          </view>
          <view class="info-list">
            <view class="info-item">
              <text class="check-icon">✅</text>
              <text class="item-text">可以浏览菜谱</text>
            </view>
            <view class="info-item">
              <text class="check-icon">✅</text>
              <text class="item-text">可以点餐（创建订单）</text>
            </view>
            <view class="info-item">
              <text class="check-icon">✅</text>
              <text class="item-text">可以查看自己的订单</text>
            </view>
            <view class="info-item">
              <text class="check-icon">⏰</text>
              <text class="item-text">24小时后自动退出</text>
            </view>
          </view>
        </view>

        <!-- 操作按钮 -->
        <view class="action-buttons">
          <button class="btn-back" @click="goBackToStep1">
            <text class="btn-text">返回</text>
          </button>
          <button
            class="btn-join"
            :class="{ disabled: !nickname.trim() || isJoining }"
            @click="joinAsGuest"
          >
            <text class="btn-text">{{ isJoining ? '加入中...' : '开始点餐' }}</text>
          </button>
        </view>
      </view>
    </view>

    <!-- 底部提示 -->
    <view class="join-footer">
      <text class="footer-text">访客身份仅在聚会期间有效</text>
      <text class="footer-text">主人可以随时结束聚会</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { FamilyService } from '@/api/family'

// 状态数据
const currentStep = ref(1) // 1: 输入邀请码, 2: 输入昵称
const inviteCode = ref('')
const nickname = ref('')
const isVerifying = ref(false)
const isJoining = ref(false)

// 家庭信息
const familyInfo = ref<any>(null)

// 页面加载
onLoad((options: any) => {
  // 如果URL带有邀请码参数，自动填充
  if (options?.code) {
    inviteCode.value = options.code
  }
})

onMounted(() => {
  // 可以在这里初始化
})

// 验证邀请码
const verifyInviteCode = async () => {
  if (inviteCode.value.length !== 6) {
    uni.showToast({
      title: '请输入6位邀请码',
      icon: 'none'
    })
    return
  }

  try {
    isVerifying.value = true

    // 调用后端API验证邀请码
    const result = await FamilyService.checkGuestInvite(inviteCode.value)

    // 保存家庭信息
    familyInfo.value = {
      id: result.family_id,
      name: result.family_name || '朋友的家'
    }

    // 验证成功，进入下一步
    currentStep.value = 2

    uni.showToast({
      title: '邀请码验证成功',
      icon: 'success'
    })
  } catch (error: any) {
    console.error('验证邀请码失败:', error)
    uni.showToast({
      title: error.message || '邀请码无效或已过期',
      icon: 'none'
    })
  } finally {
    isVerifying.value = false
  }
}

// 返回第一步
const goBackToStep1 = () => {
  currentStep.value = 1
}

// 以访客身份加入
const joinAsGuest = async () => {
  if (!nickname.value.trim()) {
    uni.showToast({
      title: '请输入昵称',
      icon: 'none'
    })
    return
  }

  try {
    isJoining.value = true

    // 调用后端API注册访客
    const result = await FamilyService.guestRegister({
      invite_code: inviteCode.value,
      user_info: {
        nickname: nickname.value.trim(),
        avatar_url: '',
        gender: 0
      }
    })

    // 保存访客信息和 token 到本地
    if (result.token) {
      uni.setStorageSync('token', result.token)
    }
    if (result.user) {
      uni.setStorageSync('user_info', result.user)
    }

    uni.setStorageSync('isGuest', true)
    uni.setStorageSync('guestNickname', nickname.value.trim())
    uni.setStorageSync('guestExpiresAt', Date.now() + 24 * 3600 * 1000) // 24小时后过期

    uni.showToast({
      title: '加入成功！',
      icon: 'success',
      duration: 1500
    })

    // 延迟跳转到首页
    setTimeout(() => {
      uni.switchTab({
        url: '/pages/index/index'
      })
    }, 1500)
  } catch (error: any) {
    console.error('加入失败:', error)
    uni.showToast({
      title: error.message || '加入失败，请重试',
      icon: 'none'
    })
  } finally {
    isJoining.value = false
  }
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.guest-join {
  min-height: 100vh;
  background: linear-gradient(180deg, #FFF8F5 0%, #FFFFFF 100%);
  padding: 40rpx 24rpx;
  padding-bottom: calc(40rpx + env(safe-area-inset-bottom));
}

// 欢迎头部
.join-header {
  text-align: center;
  padding: 60rpx 0 80rpx;

  .welcome-icon {
    font-size: 120rpx;
    margin-bottom: 24rpx;
  }

  .welcome-title {
    display: block;
    font-size: $font-size-xxl;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: 12rpx;
  }

  .welcome-subtitle {
    display: block;
    font-size: $font-size-base;
    color: $text-secondary;
  }
}

// 主内容
.join-content {
  background: white;
  border-radius: $radius-xl;
  padding: 40rpx 32rpx;
  box-shadow: $shadow-lg;
}

// 步骤区域
.step-section {
  .section-title {
    display: flex;
    align-items: center;
    gap: 12rpx;
    margin-bottom: 32rpx;

    .step-number {
      width: 48rpx;
      height: 48rpx;
      border-radius: 50%;
      background: $gradient-primary;
      color: white;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      @include flex-center;
    }

    .title-text {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .input-group {
    display: flex;
    gap: 12rpx;
    margin-bottom: 16rpx;

    .invite-code-input,
    .nickname-input {
      flex: 1;
      height: 88rpx;
      padding: 0 24rpx;
      background: $bg-section;
      border: 2rpx solid transparent;
      border-radius: $radius-lg;
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      text-align: center;
      letter-spacing: 8rpx;
      transition: all $duration-fast;

      &:focus {
        background: white;
        border-color: $primary;
      }

      &:disabled {
        opacity: 0.6;
      }
    }

    .nickname-input {
      text-align: left;
      letter-spacing: normal;
    }

    .verify-btn {
      width: 160rpx;
      height: 88rpx;
      background: $gradient-primary;
      color: white;
      border: none;
      border-radius: $radius-lg;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      box-shadow: $shadow-primary;
      transition: all $duration-fast;

      &:active:not(.disabled) {
        transform: scale(0.96);
      }

      &.disabled {
        opacity: 0.5;
        box-shadow: none;
      }
    }
  }

  .input-hint {
    display: flex;
    align-items: center;
    gap: 8rpx;
    padding: 16rpx;
    background: rgba($primary, 0.05);
    border-radius: $radius-md;

    .hint-icon {
      font-size: 28rpx;
    }

    .hint-text {
      font-size: $font-size-sm;
      color: $text-secondary;
    }
  }
}

// 访客信息
.guest-info {
  margin-top: 40rpx;
  padding: 24rpx;
  background: $bg-section;
  border-radius: $radius-lg;

  .info-title {
    display: flex;
    align-items: center;
    gap: 8rpx;
    margin-bottom: 20rpx;

    .info-icon {
      font-size: 28rpx;
    }

    .info-text {
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .info-list {
    .info-item {
      display: flex;
      align-items: center;
      gap: 12rpx;
      padding: 12rpx 0;

      .check-icon {
        font-size: 24rpx;
      }

      .item-text {
        font-size: $font-size-sm;
        color: $text-secondary;
      }
    }
  }
}

// 操作按钮
.action-buttons {
  display: flex;
  gap: 16rpx;
  margin-top: 48rpx;

  .btn-back,
  .btn-join {
    height: 88rpx;
    border: none;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    transition: all $duration-fast;

    &:active:not(.disabled) {
      transform: scale(0.96);
    }
  }

  .btn-back {
    flex: 0 0 160rpx;
    background: $bg-section;
    color: $text-primary;
  }

  .btn-join {
    flex: 1;
    background: $gradient-primary;
    color: white;
    box-shadow: $shadow-primary;

    &.disabled {
      opacity: 0.5;
      box-shadow: none;
    }
  }
}

// 底部提示
.join-footer {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  margin-top: 48rpx;
  padding: 0 24rpx;

  .footer-text {
    font-size: $font-size-xs;
    color: $text-tertiary;
    text-align: center;
  }
}
</style>
