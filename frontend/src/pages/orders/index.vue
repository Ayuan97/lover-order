<template>
  <view class="orders-page">
    <view class="page-header">
      <text class="page-title">我的订单</text>
    </view>
    
    <view class="content">
      <view class="empty-state">
        <text class="empty-icon">📋</text>
        <text class="empty-text">暂无订单</text>
        <text class="empty-desc">快去点餐吧</text>
        <button class="btn btn-primary" @click="createOrder">
          创建订单
        </button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
const createOrder = () => {
  uni.navigateTo({
    url: '/pages/orders/create'
  })
}
</script>

<style lang="scss" scoped>
.orders-page {
  padding: 24rpx;
  min-height: 100vh;
}

.page-header {
  margin-bottom: 32rpx;
}

.page-title {
  font-size: 36rpx;
  font-weight: bold;
  color: #424242;
}

.content {
  flex: 1;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 80rpx 32rpx;
  text-align: center;
}

.empty-icon {
  font-size: 120rpx;
  margin-bottom: 32rpx;
  opacity: 0.6;
}

.empty-text {
  font-size: 32rpx;
  color: #424242;
  font-weight: bold;
  margin-bottom: 16rpx;
}

.empty-desc {
  font-size: 28rpx;
  color: #666;
  line-height: 1.5;
  margin-bottom: 48rpx;
}
</style>
