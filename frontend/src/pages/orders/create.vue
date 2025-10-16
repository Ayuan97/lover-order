<template>
  <view class="create-order-page">
    <!-- 页面头部 -->
    <view class="page-header">
      <text class="page-title">💭 想吃这些</text>
      <text class="page-subtitle">告诉TA你的美味心愿～</text>
    </view>

    <!-- 空购物车状态 -->
    <view class="empty-cart" v-if="cartItems.length === 0">
      <text class="empty-icon">😋</text>
      <text class="empty-text">还没选想吃的呢</text>
      <text class="empty-desc">快去看看今天想吃什么吧～</text>
      <button class="btn btn-primary" @click="goToHome">
        去看看
      </button>
    </view>

    <!-- 订单内容 -->
    <view class="order-content" v-else>
      <!-- 菜品列表 -->
      <view class="order-items-section card">
        <view class="section-header">
          <text class="section-icon">😋</text>
          <text class="section-title">想吃的菜</text>
          <text class="section-count">({{ cartItems.length }}道)</text>
        </view>

        <view class="order-items-list">
          <view
            class="order-item"
            v-for="item in cartItems"
            :key="item.id"
          >
            <image
              class="item-image"
              :src="item.image || defaultRecipeImage"
              mode="aspectFill"
            />
            <view class="item-info">
              <text class="item-name">{{ item.name }}</text>
              <text class="item-desc">{{ item.description || '暂无描述' }}</text>
              <view class="item-meta">
                <text class="meta-badge time">{{ item.cooking_time }}分钟</text>
                <text class="meta-badge difficulty">{{ getDifficultyText(item.difficulty) }}</text>
              </view>
            </view>
            <view class="item-quantity">
              <view class="quantity-badge">
                <text class="quantity-text">x{{ item.quantity }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- 订单摘要 -->
      <view class="order-summary-section card">
        <view class="section-header">
          <text class="section-icon">⏱️</text>
          <text class="section-title">预计时间</text>
        </view>

        <view class="summary-items">
          <view class="summary-item">
            <text class="summary-label">一共</text>
            <text class="summary-value highlight">{{ totalQuantity }}道菜</text>
          </view>
          <view class="summary-item">
            <text class="summary-label">大约需要</text>
            <text class="summary-value">{{ totalCookingTime }}分钟</text>
          </view>
        </view>
      </view>

      <!-- 用餐时间（可选） -->
      <view class="meal-time-section card">
        <view class="section-header">
          <text class="section-icon">⏰</text>
          <text class="section-title">什么时候吃</text>
          <text class="section-tip">（可选）</text>
        </view>

        <view class="datetime-picker" @click="showDatetimePicker = true">
          <text class="picker-value" :class="{ placeholder: !mealTime }">
            {{ mealTimeDisplay || '选个时间吧～' }}
          </text>
          <text class="picker-arrow">></text>
        </view>
      </view>

      <!-- 备注 -->
      <view class="note-section card">
        <view class="section-header">
          <text class="section-icon">💬</text>
          <text class="section-title">想说的话</text>
          <text class="section-tip">（可选）</text>
        </view>

        <textarea
          class="note-input"
          v-model="orderNote"
          placeholder="有什么特别的要求吗？比如少盐、多辣～"
          maxlength="200"
          :show-confirm-bar="false"
        />
        <view class="note-counter">
          <text class="counter-text">{{ orderNote.length }}/200</text>
        </view>
      </view>
    </view>

    <!-- 底部操作栏 -->
    <view class="footer-actions" v-if="cartItems.length > 0">
      <view class="footer-info">
        <text class="info-label">{{ totalQuantity }}道菜</text>
        <text class="info-time">约{{ totalCookingTime }}分钟</text>
      </view>
      <button
        class="submit-btn"
        :disabled="isSubmitting"
        @click="submitOrder"
      >
        {{ isSubmitting ? '提交中...' : '💭 告诉TA' }}
      </button>
    </view>

    <!-- 日期时间选择器弹窗 -->
    <view class="datetime-modal" v-if="showDatetimePicker" @click="closeDatetimePicker">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="modal-title">选择用餐时间</text>
          <text class="modal-close" @click="closeDatetimePicker">✕</text>
        </view>
        <view class="modal-body">
          <picker
            mode="date"
            :value="tempDate"
            @change="onDateChange"
          >
            <view class="picker-item">
              <text class="picker-label">日期</text>
              <text class="picker-value">{{ tempDate || '选择日期' }}</text>
            </view>
          </picker>
          <picker
            mode="time"
            :value="tempTime"
            @change="onTimeChange"
          >
            <view class="picker-item">
              <text class="picker-label">时间</text>
              <text class="picker-value">{{ tempTime || '选择时间' }}</text>
            </view>
          </picker>
        </view>
        <view class="modal-actions">
          <button class="modal-btn cancel-btn" @click="closeDatetimePicker">取消</button>
          <button class="modal-btn confirm-btn" @click="confirmMealTime">确定</button>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { OrderService } from '@/api/order'

// 默认菜谱图片
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 购物车数据
const cartItems = ref<any[]>([])

// 订单表单数据
const mealTime = ref<string>('')
const orderNote = ref<string>('')
const isSubmitting = ref(false)

// 日期时间选择器
const showDatetimePicker = ref(false)
const tempDate = ref('')
const tempTime = ref('')

// 计算属性
const totalQuantity = computed(() => {
  return cartItems.value.reduce((total, item) => total + item.quantity, 0)
})

const totalCookingTime = computed(() => {
  return cartItems.value.reduce((total, item) => {
    return total + (item.cooking_time * item.quantity)
  }, 0)
})

const mealTimeDisplay = computed(() => {
  if (!mealTime.value) return ''

  // ISO 8601 格式字符串可以直接被 Date 解析
  const date = new Date(mealTime.value)

  // 检查日期是否有效
  if (isNaN(date.getTime())) return ''

  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hour = String(date.getHours()).padStart(2, '0')
  const minute = String(date.getMinutes()).padStart(2, '0')

  return `${year}-${month}-${day} ${hour}:${minute}`
})

// 页面加载
onMounted(() => {
  loadCartData()
})

// 加载购物车数据
const loadCartData = () => {
  try {
    const cart = uni.getStorageSync('shopping_cart') || []
    cartItems.value = cart
    console.log('购物车数据加载成功:', cartItems.value.length, '个商品')
  } catch (error) {
    console.error('加载购物车失败:', error)
    cartItems.value = []
  }
}

// 获取难度文本
const getDifficultyText = (difficulty: number) => {
  const difficultyMap: { [key: number]: string } = {
    1: '简单',
    2: '中等',
    3: '困难'
  }
  return difficultyMap[difficulty] || '未知'
}

// 前往首页
const goToHome = () => {
  uni.switchTab({
    url: '/pages/index/index'
  })
}

// 日期选择
const onDateChange = (e: any) => {
  tempDate.value = e.detail.value
}

// 时间选择
const onTimeChange = (e: any) => {
  tempTime.value = e.detail.value
}

// 关闭日期时间选择器
const closeDatetimePicker = () => {
  showDatetimePicker.value = false
}

// 确认用餐时间
const confirmMealTime = () => {
  if (tempDate.value && tempTime.value) {
    // 构建 ISO 8601 格式的时间字符串（Go 后端需要这种格式）
    mealTime.value = `${tempDate.value}T${tempTime.value}:00+08:00`
    showDatetimePicker.value = false

    uni.showToast({
      title: '已设置用餐时间',
      icon: 'success',
      duration: 1000
    })
  } else {
    uni.showToast({
      title: '请选择完整的日期和时间',
      icon: 'none'
    })
  }
}

// 提交订单
const submitOrder = async () => {
  if (isSubmitting.value) return

  if (cartItems.value.length === 0) {
    uni.showToast({
      title: '购物车是空的',
      icon: 'none'
    })
    return
  }

  try {
    isSubmitting.value = true

    // 构建订单项数据
    const items = cartItems.value.map(item => ({
      recipe_id: item.id,
      quantity: item.quantity,
      note: ''
    }))

    // 构建订单数据
    const orderData: any = {
      items: items
    }

    // 添加可选字段
    if (mealTime.value) {
      orderData.meal_time = mealTime.value
    }

    if (orderNote.value.trim()) {
      orderData.note = orderNote.value.trim()
    }

    console.log('提交订单数据:', orderData)

    // 调用 API 创建订单
    const result = await OrderService.createOrder(orderData)

    console.log('订单创建成功:', result)

    // 从响应中提取订单ID
    const orderId = result?.id || result?.data?.id
    console.log('提取到的订单ID:', orderId)

    if (!orderId) {
      throw new Error('订单创建成功，但未获取到订单ID')
    }

    // 清空购物车
    uni.removeStorageSync('shopping_cart')

    // 显示成功提示
    uni.showToast({
      title: '💭 已经告诉TA啦～',
      icon: 'success',
      duration: 1500
    })

    // 延迟跳转到订单详情页
    setTimeout(() => {
      uni.redirectTo({
        url: `/pages/orders/detail?id=${orderId}`
      })
    }, 1500)

  } catch (error: any) {
    console.error('提交订单失败:', error)
    uni.showToast({
      title: error.message || '提交失败',
      icon: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.create-order-page {
  min-height: 100vh;
  background-color: $bg-page;
  padding-bottom: 160rpx;
}

// 页面头部
.page-header {
  background: $gradient-primary;
  padding: 48rpx $spacing-base 40rpx;
  color: white;
  text-align: center;

  .page-title {
    display: block;
    font-size: $font-size-xl;
    font-weight: $font-weight-bold;
    margin-bottom: 8rpx;
  }

  .page-subtitle {
    display: block;
    font-size: $font-size-sm;
    opacity: 0.9;
  }
}

// 空购物车状态
.empty-cart {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 200rpx 40rpx;
  text-align: center;

  .empty-icon {
    font-size: 120rpx;
    margin-bottom: $spacing-lg;
    opacity: 0.6;
  }

  .empty-text {
    font-size: $font-size-lg;
    color: $text-primary;
    font-weight: $font-weight-bold;
    margin-bottom: $spacing-sm;
  }

  .empty-desc {
    font-size: $font-size-sm;
    color: $text-secondary;
    line-height: $line-height-base;
    margin-bottom: $spacing-xl;
  }

  .btn {
    padding: $spacing-base $spacing-xl;
    background: $gradient-primary;
    color: white;
    border: none;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    box-shadow: $shadow-primary;

    &:active {
      transform: scale(0.96);
    }
  }
}

// 订单内容
.order-content {
  padding: $spacing-base;

  .card {
    background-color: $bg-card;
    border-radius: $radius-lg;
    padding: $spacing-lg;
    margin-bottom: $spacing-base;
    box-shadow: $shadow-base;
  }

  .section-header {
    display: flex;
    align-items: center;
    gap: $spacing-sm;
    margin-bottom: $spacing-lg;

    .section-icon {
      font-size: $font-size-xl;
    }

    .section-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }

    .section-count {
      font-size: $font-size-sm;
      color: $text-secondary;
    }

    .section-tip {
      font-size: $font-size-xs;
      color: $text-tertiary;
      margin-left: $spacing-xs;
    }
  }
}

// 菜品列表
.order-items-list {
  .order-item {
    display: flex;
    align-items: center;
    gap: $spacing-md;
    padding: $spacing-md 0;
    border-bottom: 1rpx solid $border-light;

    &:last-child {
      border-bottom: none;
    }

    .item-image {
      width: 100rpx;
      height: 100rpx;
      border-radius: $radius-base;
      flex-shrink: 0;
      background-color: $bg-section;
    }

    .item-info {
      flex: 1;
      min-width: 0;

      .item-name {
        display: block;
        font-size: $font-size-base;
        color: $text-primary;
        font-weight: $font-weight-medium;
        margin-bottom: 4rpx;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .item-desc {
        display: block;
        font-size: $font-size-xs;
        color: $text-secondary;
        margin-bottom: $spacing-xs;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .item-meta {
        display: flex;
        gap: $spacing-xs;

        .meta-badge {
          font-size: $font-size-xxs;
          padding: 4rpx $spacing-xs;
          border-radius: $radius-sm;
          background-color: $bg-section;
          color: $text-secondary;

          &.time {
            background-color: rgba(255, 138, 101, 0.1);
            color: $primary;
          }

          &.difficulty {
            background-color: $bg-section;
            color: $text-tertiary;
          }
        }
      }
    }

    .item-quantity {
      flex-shrink: 0;

      .quantity-badge {
        padding: $spacing-xs $spacing-md;
        background-color: $bg-section;
        border-radius: $radius-base;

        .quantity-text {
          font-size: $font-size-sm;
          color: $text-primary;
          font-weight: $font-weight-bold;
        }
      }
    }
  }
}

// 订单摘要
.summary-items {
  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: $spacing-md 0;
    border-bottom: 1rpx solid $border-light;

    &:last-child {
      border-bottom: none;
    }

    .summary-label {
      font-size: $font-size-base;
      color: $text-secondary;
    }

    .summary-value {
      font-size: $font-size-base;
      color: $text-primary;
      font-weight: $font-weight-medium;

      &.highlight {
        color: $primary;
        font-weight: $font-weight-bold;
      }
    }
  }
}

// 日期时间选择器
.datetime-picker {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: $spacing-base;
  background-color: $bg-section;
  border-radius: $radius-base;
  transition: all $duration-base $ease-out;

  &:active {
    background-color: $bg-hover;
  }

  .picker-value {
    font-size: $font-size-base;
    color: $text-primary;

    &.placeholder {
      color: $text-placeholder;
    }
  }

  .picker-arrow {
    font-size: $font-size-sm;
    color: $text-tertiary;
  }
}

// 备注输入
.note-input {
  width: 100%;
  min-height: 160rpx;
  padding: $spacing-base;
  background-color: $bg-section;
  border: 2rpx solid transparent;
  border-radius: $radius-base;
  font-size: $font-size-base;
  color: $text-primary;
  line-height: $line-height-base;
  transition: all $duration-base $ease-out;

  &:focus {
    background-color: white;
    border-color: $primary;
    box-shadow: 0 2rpx 8rpx rgba(255, 138, 101, 0.15);
  }
}

.note-counter {
  display: flex;
  justify-content: flex-end;
  margin-top: $spacing-sm;

  .counter-text {
    font-size: $font-size-xs;
    color: $text-tertiary;
  }
}

// 底部操作栏
.footer-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: $spacing-base;
  background-color: white;
  border-top: 1rpx solid $border-light;
  box-shadow: 0 -4rpx 12rpx rgba(0, 0, 0, 0.05);
  z-index: 100;

  .footer-info {
    display: flex;
    flex-direction: column;
    gap: 4rpx;

    .info-label {
      font-size: $font-size-base;
      color: $text-primary;
      font-weight: $font-weight-bold;
    }

    .info-time {
      font-size: $font-size-xs;
      color: $text-secondary;
    }
  }

  .submit-btn {
    flex: 0 0 240rpx;
    height: 88rpx;
    background: $gradient-primary;
    color: white;
    border: none;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    box-shadow: $shadow-primary;
    transition: all $duration-base $ease-out;

    &:disabled {
      opacity: 0.6;
      transform: none;
    }

    &:active:not(:disabled) {
      transform: scale(0.96);
      box-shadow: $shadow-primary-hover;
    }
  }
}

// 日期时间选择弹窗
.datetime-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;

  .modal-content {
    width: 600rpx;
    background-color: white;
    border-radius: $radius-xl;
    overflow: hidden;
    box-shadow: 0 16rpx 48rpx rgba(0, 0, 0, 0.2);

    .modal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: $spacing-lg;
      border-bottom: 1rpx solid $border-light;

      .modal-title {
        font-size: $font-size-lg;
        font-weight: $font-weight-bold;
        color: $text-primary;
      }

      .modal-close {
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background-color: $bg-section;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: $font-size-base;
        color: $text-secondary;

        &:active {
          background-color: $bg-disabled;
        }
      }
    }

    .modal-body {
      padding: $spacing-lg;

      .picker-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: $spacing-base;
        background-color: $bg-section;
        border-radius: $radius-base;
        margin-bottom: $spacing-md;

        &:last-child {
          margin-bottom: 0;
        }

        .picker-label {
          font-size: $font-size-base;
          color: $text-secondary;
          font-weight: $font-weight-medium;
        }

        .picker-value {
          font-size: $font-size-base;
          color: $text-primary;
          font-weight: $font-weight-bold;
        }
      }
    }

    .modal-actions {
      display: flex;
      gap: $spacing-md;
      padding: 0 $spacing-lg $spacing-lg;

      .modal-btn {
        flex: 1;
        height: 80rpx;
        border-radius: $radius-button;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        border: none;

        &.cancel-btn {
          background-color: $bg-section;
          color: $text-secondary;

          &:active {
            background-color: $bg-disabled;
          }
        }

        &.confirm-btn {
          background: $gradient-primary;
          color: white;
          box-shadow: $shadow-primary;

          &:active {
            box-shadow: $shadow-primary-hover;
          }
        }
      }
    }
  }
}
</style>
