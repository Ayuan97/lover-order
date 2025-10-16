<template>
  <view class="order-detail-page">
    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading">
      <text class="loading-text">加载中...</text>
    </view>

    <!-- 详情内容 -->
    <view class="detail-content" v-else-if="order">
      <!-- 订单状态卡片 -->
      <view class="status-card">
        <view class="status-icon-container">
          <text class="status-icon">{{ getStatusIcon(order.status) }}</text>
        </view>
        <view class="status-info">
          <text class="status-text">
            {{ getStatusText(order.status) }}
          </text>
          <text class="status-desc">{{ getStatusDescription(order.status) }}</text>
          <!-- 预计时间（烹饪中时显示） -->
          <text class="cooking-time" v-if="order.status === 'cooking'">
            预计还需 {{ totalCookingTime }}分钟
          </text>
        </view>
      </view>

      <!-- 订单信息 -->
      <view class="order-info-card card">
        <view class="section-header">
          <text class="section-icon">📋</text>
          <text class="section-title">订单信息</text>
        </view>

        <view class="info-items">
          <view class="info-item">
            <text class="info-label">订单编号</text>
            <text class="info-value">{{ order.order_no }}</text>
          </view>
          <view class="info-item">
            <text class="info-label">下单时间</text>
            <text class="info-value">{{ formatDateTime(order.created_at) }}</text>
          </view>
          <view class="info-item" v-if="order.meal_time">
            <text class="info-label">期望用餐时间</text>
            <text class="info-value highlight">{{ formatDateTime(order.meal_time) }}</text>
          </view>
          <view class="info-item" v-if="order.confirmed_at">
            <text class="info-label">确认时间</text>
            <text class="info-value">{{ formatDateTime(order.confirmed_at) }}</text>
          </view>
          <view class="info-item" v-if="order.completed_at">
            <text class="info-label">完成时间</text>
            <text class="info-value">{{ formatDateTime(order.completed_at) }}</text>
          </view>
          <view class="info-item" v-if="order.cancelled_at">
            <text class="info-label">取消时间</text>
            <text class="info-value">{{ formatDateTime(order.cancelled_at) }}</text>
          </view>
        </view>

        <!-- 订单备注 -->
        <view class="order-note" v-if="order.note">
          <view class="note-header">
            <text class="note-icon">📝</text>
            <text class="note-title">订单备注</text>
          </view>
          <text class="note-content">{{ order.note }}</text>
        </view>

        <!-- 取消原因 -->
        <view class="cancel-reason" v-if="order.cancel_reason">
          <view class="reason-header">
            <text class="reason-icon">❗</text>
            <text class="reason-title">取消原因</text>
          </view>
          <text class="reason-content">{{ order.cancel_reason }}</text>
        </view>
      </view>

      <!-- 菜品列表 -->
      <view class="order-items-card card">
        <view class="section-header">
          <text class="section-icon">🍽️</text>
          <text class="section-title">菜品清单</text>
          <text class="section-count">({{ order.item_count }}道菜)</text>
        </view>

        <view class="items-list">
          <view
            class="item-row"
            v-for="item in order.items"
            :key="item.id"
          >
            <image
              class="item-image"
              :src="item.recipe_image || defaultRecipeImage"
              mode="aspectFill"
            />
            <view class="item-info">
              <text class="item-name">{{ item.recipe_name }}</text>
              <text class="item-desc" v-if="item.recipe_description">
                {{ item.recipe_description }}
              </text>
              <view class="item-note" v-if="item.note">
                <text class="note-label">备注：</text>
                <text class="note-text">{{ item.note }}</text>
              </view>
            </view>
            <view class="item-quantity">
              <text class="quantity-text">x{{ item.quantity }}</text>
            </view>
          </view>
        </view>

        <!-- 订单汇总 -->
        <view class="order-summary">
          <view class="summary-row">
            <text class="summary-label">菜品数量</text>
            <text class="summary-value">{{ order.item_count }}道菜</text>
          </view>
        </view>
      </view>

      <!-- 下单用户信息 -->
      <view class="user-info-card card" v-if="order.user">
        <view class="section-header">
          <text class="section-icon">👤</text>
          <text class="section-title">下单用户</text>
        </view>

        <view class="user-content">
          <view class="user-avatar">
            <text class="avatar-text">{{ order.user.nickname.charAt(0) }}</text>
          </view>
          <view class="user-details">
            <text class="user-name">{{ order.user.nickname }}</text>
            <text class="user-badge" v-if="order.is_guest_order">访客</text>
          </view>
        </view>
      </view>

      <!-- 确认人信息 -->
      <view class="confirmer-info-card card" v-if="order.confirmed_by_user">
        <view class="section-header">
          <text class="section-icon">✅</text>
          <text class="section-title">确认人</text>
        </view>

        <view class="user-content">
          <view class="user-avatar">
            <text class="avatar-text">{{ order.confirmed_by_user.nickname.charAt(0) }}</text>
          </view>
          <view class="user-details">
            <text class="user-name">{{ order.confirmed_by_user.nickname }}</text>
          </view>
        </view>
      </view>

      <!-- 订单评价 -->
      <view class="review-card card" v-if="order.status === 'completed'">
        <view class="section-header">
          <text class="section-icon">😋</text>
          <text class="section-title">品尝反馈</text>
        </view>

        <!-- 已有评价 -->
        <view class="review-content" v-if="order.review">
          <view class="review-rating">
            <text class="star" v-for="i in 5" :key="i" :class="{ filled: i <= order.review.rating }">
              {{ i <= order.review.rating ? '⭐' : '☆' }}
            </text>
          </view>
          <view class="review-emoji" v-if="order.review.emoji">
            <text class="emoji-text">{{ order.review.emoji }}</text>
          </view>
          <view class="review-comment" v-if="order.review.comment">
            <text class="comment-text">{{ order.review.comment }}</text>
          </view>
          <view class="review-time">
            <text class="time-text">{{ formatDateTime(order.review.created_at!) }}</text>
          </view>
        </view>

        <!-- 未评价 -->
        <view class="no-review" v-else-if="canReview(order)">
          <text class="no-review-text">分享一下品尝感受吧～</text>
          <button class="review-btn" @click="showReviewModal = true">
            <text class="btn-icon">😋</text>
            <text class="btn-text">写评价</text>
          </button>
        </view>
      </view>
    </view>

    <!-- 错误状态 -->
    <view class="error-state" v-else>
      <text class="error-icon">😞</text>
      <text class="error-text">订单加载失败</text>
      <button class="btn btn-primary" @click="loadOrderDetail">
        重新加载
      </button>
    </view>

    <!-- 底部操作栏 -->
    <view class="footer-actions" v-if="order && hasActions">
      <button
        v-if="canCancel(order)"
        class="action-btn cancel-btn"
        @click="cancelOrder"
      >
        取消
      </button>

      <button
        v-if="canRepeat(order)"
        class="action-btn repeat-btn"
        @click="repeatOrder"
      >
        再来一份
      </button>

      <button
        v-if="canStartCooking(order)"
        class="action-btn cooking-btn"
        @click="startCooking"
      >
        <text class="btn-icon">👨‍🍳</text>
        <text class="btn-text">开始做</text>
      </button>

      <button
        v-if="canComplete(order)"
        class="action-btn complete-btn"
        @click="completeOrder"
      >
        <text class="btn-icon">🔔</text>
        <text class="btn-text">做好啦</text>
      </button>
    </view>

    <!-- 取消订单弹窗 -->
    <view class="cancel-modal" v-if="showCancelModal" @click="closeCancelModal">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="modal-title">取消订单</text>
          <text class="modal-close" @click="closeCancelModal">✕</text>
        </view>
        <view class="modal-body">
          <textarea
            class="cancel-reason-input"
            v-model="cancelReason"
            placeholder="请输入取消原因（可选）"
            maxlength="200"
            :show-confirm-bar="false"
          />
        </view>
        <view class="modal-actions">
          <button class="modal-btn cancel-confirm-btn" @click="closeCancelModal">
            取消
          </button>
          <button
            class="modal-btn submit-btn"
            :disabled="isCancelling"
            @click="confirmCancel"
          >
            {{ isCancelling ? '取消中...' : '确认取消' }}
          </button>
        </view>
      </view>
    </view>

    <!-- 评价订单弹窗 -->
    <view class="review-modal" v-if="showReviewModal" @click="closeReviewModal">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="modal-title">😋 品尝感受</text>
          <text class="modal-close" @click="closeReviewModal">✕</text>
        </view>
        <view class="modal-body">
          <!-- 评分 -->
          <view class="rating-section">
            <text class="rating-label">好吃吗？</text>
            <view class="rating-stars">
              <text
                class="star-item"
                v-for="i in 5"
                :key="i"
                @click="reviewRating = i"
              >
                {{ i <= reviewRating ? '⭐' : '☆' }}
              </text>
            </view>
          </view>

          <!-- 表情选择 -->
          <view class="emoji-section">
            <text class="emoji-label">选个表情～</text>
            <view class="emoji-list">
              <text
                class="emoji-item"
                v-for="emoji in emojiOptions"
                :key="emoji"
                :class="{ selected: reviewEmoji === emoji }"
                @click="reviewEmoji = emoji"
              >
                {{ emoji }}
              </text>
            </view>
          </view>

          <!-- 评价留言 -->
          <view class="comment-section">
            <text class="comment-label">想说的话（可选）</text>
            <textarea
              class="comment-input"
              v-model="reviewComment"
              placeholder="分享一下感受吧，比如：超好吃！下次还想吃～"
              maxlength="200"
              :show-confirm-bar="false"
            />
            <view class="comment-counter">
              <text class="counter-text">{{ reviewComment.length }}/200</text>
            </view>
          </view>
        </view>
        <view class="modal-actions">
          <button class="modal-btn cancel-btn" @click="closeReviewModal">
            取消
          </button>
          <button
            class="modal-btn submit-btn"
            :disabled="isSubmittingReview || reviewRating === 0"
            @click="submitReview"
          >
            {{ isSubmittingReview ? '提交中...' : '提交评价' }}
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { OrderService, OrderUtils, type Order, type OrderStatus } from '@/api/order'
import { AuthService } from '@/api/auth'

// 页面参数
const orderId = ref<number>(0)

// 响应式数据
const isLoading = ref(true)
const order = ref<Order | null>(null)

// 取消订单相关
const showCancelModal = ref(false)
const cancelReason = ref('')
const isCancelling = ref(false)

// 评价订单相关
const showReviewModal = ref(false)
const reviewRating = ref(0)
const reviewEmoji = ref('')
const reviewComment = ref('')
const isSubmittingReview = ref(false)

// 表情选项
const emojiOptions = ['😋', '🥰', '😍', '🤤', '👍', '💯', '❤️', '🔥']

// 默认菜谱图片
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 计算属性
const hasActions = computed(() => {
  if (!order.value) return false
  return canCancel(order.value) || canRepeat(order.value) || canStartCooking(order.value) || canComplete(order.value)
})

// 计算总烹饪时间
const totalCookingTime = computed(() => {
  if (!order.value || !order.value.items) return 0
  return order.value.items.reduce((total, item) => {
    // 假设cooking_time字段存在于item中
    return total + ((item as any).cooking_time || 30) * item.quantity
  }, 0)
})

// 页面加载
onLoad((options: any) => {
  console.log('订单详情页面加载，参数:', options)

  if (options.id) {
    orderId.value = Number(options.id)
    loadOrderDetail()
  } else {
    console.error('缺少订单ID参数')
    uni.showToast({
      title: '参数错误',
      icon: 'error'
    })
  }
})

// 加载订单详情
const loadOrderDetail = async () => {
  try {
    isLoading.value = true

    const result = await OrderService.getOrderDetail(orderId.value)
    order.value = result

  } catch (error: any) {
    console.error('加载订单详情失败:', error)
    uni.showToast({
      title: error.message || '加载失败',
      icon: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

// 格式化日期时间
const formatDateTime = (dateStr: string) => {
  const date = new Date(dateStr)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hour = String(date.getHours()).padStart(2, '0')
  const minute = String(date.getMinutes()).padStart(2, '0')
  return `${year}-${month}-${day} ${hour}:${minute}`
}

// 获取状态文本
const getStatusText = (status: OrderStatus) => {
  return OrderUtils.getStatusText(status)
}

// 获取状态颜色
const getStatusColor = (status: OrderStatus) => {
  return OrderUtils.getStatusColor(status)
}

// 获取状态图标
const getStatusIcon = (status: OrderStatus) => {
  const iconMap: Record<OrderStatus, string> = {
    pending: '💭',
    confirmed: '✅',
    cooking: '👨‍🍳',
    completed: '🍽️',
    cancelled: '❌'
  }
  return iconMap[status] || '📋'
}

// 获取状态描述（温馨版）
const getStatusDescription = (status: OrderStatus) => {
  if (!order.value) return ''

  const userName = order.value.user?.nickname || 'Ta'

  const descMap: Record<OrderStatus, string> = {
    pending: `${userName}想吃这些～`,
    confirmed: '已确认，准备开始做',
    cooking: '正在为你用心准备中❤️',
    completed: '爱的美食做好啦，快来品尝～',
    cancelled: '已取消这次点餐'
  }
  return descMap[status] || ''
}

// 判断是否可以取消
const canCancel = (order: Order) => {
  return OrderUtils.canCancel(order)
}

// 判断是否可以重复下单
const canRepeat = (order: Order) => {
  return OrderUtils.canRepeat(order)
}

// 判断是否可以开始烹饪（管理员功能）
const canStartCooking = (order: Order) => {
  const currentUser = AuthService.getCurrentUser()
  if (!currentUser || currentUser.role !== 'admin') return false
  // 从pending状态直接开始做
  return order.status === 'pending'
}

// 判断是否可以完成（管理员功能）
const canComplete = (order: Order) => {
  const currentUser = AuthService.getCurrentUser()
  if (!currentUser || currentUser.role !== 'admin') return false
  return order.status === 'cooking'
}

// 判断是否可以评价
const canReview = (order: Order) => {
  // 只有点餐人可以评价
  const currentUser = AuthService.getCurrentUser()
  if (!currentUser) return false
  return order.user_id === currentUser.id && !order.review
}

// 取消订单
const cancelOrder = () => {
  cancelReason.value = ''
  showCancelModal.value = true
}

// 关闭取消弹窗
const closeCancelModal = () => {
  showCancelModal.value = false
  cancelReason.value = ''
}

// 确认取消订单
const confirmCancel = async () => {
  if (!order.value || isCancelling.value) return

  try {
    isCancelling.value = true

    await OrderService.cancelOrder(
      order.value.id,
      cancelReason.value
    )

    uni.showToast({
      title: '订单已取消',
      icon: 'success',
      duration: 1500
    })

    closeCancelModal()

    // 重新加载订单详情
    await loadOrderDetail()

  } catch (error: any) {
    console.error('取消订单失败:', error)
    uni.showToast({
      title: error.message || '取消失败',
      icon: 'error'
    })
  } finally {
    isCancelling.value = false
  }
}

// 重复下单
const repeatOrder = async () => {
  if (!order.value) return

  try {
    uni.showLoading({ title: '处理中...' })

    const newOrder = await OrderService.repeatOrder(order.value.id)

    uni.hideLoading()

    uni.showToast({
      title: '下单成功',
      icon: 'success',
      duration: 1500
    })

    // 跳转到新订单详情
    setTimeout(() => {
      uni.redirectTo({
        url: `/pages/orders/detail?id=${newOrder.id}`
      })
    }, 1500)

  } catch (error: any) {
    uni.hideLoading()
    console.error('重复下单失败:', error)
    uni.showToast({
      title: error.message || '下单失败',
      icon: 'error'
    })
  }
}

// 开始烹饪（管理员）
const startCooking = async () => {
  if (!order.value) return

  try {
    uni.showLoading({ title: '开始准备...' })

    await OrderService.updateOrderStatus(order.value.id, 'cooking')

    uni.hideLoading()

    uni.showToast({
      title: '👨‍🍳 开始做啦～',
      icon: 'success',
      duration: 1500
    })

    // 重新加载订单详情
    await loadOrderDetail()

  } catch (error: any) {
    uni.hideLoading()
    console.error('更新订单状态失败:', error)
    uni.showToast({
      title: error.message || '操作失败',
      icon: 'error'
    })
  }
}

// 完成订单（管理员）
const completeOrder = async () => {
  if (!order.value) return

  try {
    uni.showLoading({ title: '处理中...' })

    await OrderService.updateOrderStatus(order.value.id, 'completed')

    uni.hideLoading()

    uni.showToast({
      title: '🔔 做好啦，快来吃～',
      icon: 'success',
      duration: 1500
    })

    // 重新加载订单详情
    await loadOrderDetail()

  } catch (error: any) {
    uni.hideLoading()
    console.error('完成订单失败:', error)
    uni.showToast({
      title: error.message || '操作失败',
      icon: 'error'
    })
  }
}

// 关闭评价弹窗
const closeReviewModal = () => {
  showReviewModal.value = false
  reviewRating.value = 0
  reviewEmoji.value = ''
  reviewComment.value = ''
}

// 提交评价
const submitReview = async () => {
  if (!order.value || isSubmittingReview.value || reviewRating.value === 0) return

  try {
    isSubmittingReview.value = true

    await OrderService.reviewOrder(order.value.id, {
      rating: reviewRating.value,
      emoji: reviewEmoji.value,
      comment: reviewComment.value.trim()
    })

    uni.showToast({
      title: '😋 感谢分享～',
      icon: 'success',
      duration: 1500
    })

    closeReviewModal()

    // 重新加载订单详情
    await loadOrderDetail()

  } catch (error: any) {
    console.error('提交评价失败:', error)
    uni.showToast({
      title: error.message || '提交失败',
      icon: 'error'
    })
  } finally {
    isSubmittingReview.value = false
  }
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.order-detail-page {
  min-height: 100vh;
  background-color: $bg-page;
  padding-bottom: 160rpx;
}

// 加载状态
.loading-state {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 200rpx 40rpx;

  .loading-text {
    font-size: $font-size-base;
    color: $text-secondary;
  }
}

// 错误状态
.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 200rpx 40rpx;
  text-align: center;

  .error-icon {
    font-size: 120rpx;
    margin-bottom: $spacing-lg;
    opacity: 0.6;
  }

  .error-text {
    font-size: $font-size-lg;
    color: $text-primary;
    font-weight: $font-weight-bold;
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

// 详情内容
.detail-content {
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
  }
}

// 订单状态卡片
.status-card {
  display: flex;
  align-items: center;
  gap: $spacing-lg;
  background: $gradient-primary;
  padding: $spacing-xl $spacing-lg;
  border-radius: $radius-lg;
  margin-bottom: $spacing-base;
  box-shadow: $shadow-primary;

  .status-icon-container {
    width: 88rpx;
    height: 88rpx;
    background-color: rgba(255, 255, 255, 0.9);
    border-radius: 44rpx;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;

    .status-icon {
      font-size: 48rpx;
    }
  }

  .status-info {
    flex: 1;

    .status-text {
      display: block;
      font-size: $font-size-xl;
      font-weight: $font-weight-bold;
      color: white;
      margin-bottom: 8rpx;
    }

    .status-desc {
      display: block;
      font-size: $font-size-sm;
      color: rgba(255, 255, 255, 0.9);
      margin-bottom: 4rpx;
    }

    .cooking-time {
      display: block;
      font-size: $font-size-xs;
      color: rgba(255, 255, 255, 0.85);
      background: rgba(255, 255, 255, 0.15);
      padding: 4rpx 12rpx;
      border-radius: $radius-sm;
      display: inline-block;
      margin-top: 8rpx;
    }
  }
}

// 订单信息
.info-items {
  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: $spacing-md 0;
    border-bottom: 1rpx solid $border-light;

    &:last-child {
      border-bottom: none;
    }

    .info-label {
      font-size: $font-size-base;
      color: $text-secondary;
    }

    .info-value {
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

// 订单备注
.order-note {
  margin-top: $spacing-lg;
  padding-top: $spacing-lg;
  border-top: 1rpx solid $border-light;

  .note-header {
    display: flex;
    align-items: center;
    gap: $spacing-xs;
    margin-bottom: $spacing-sm;

    .note-icon {
      font-size: $font-size-md;
    }

    .note-title {
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .note-content {
    font-size: $font-size-sm;
    color: $text-secondary;
    line-height: $line-height-base;
    background-color: $bg-section;
    padding: $spacing-md;
    border-radius: $radius-base;
  }
}

// 取消原因
.cancel-reason {
  margin-top: $spacing-lg;
  padding-top: $spacing-lg;
  border-top: 1rpx solid $border-light;

  .reason-header {
    display: flex;
    align-items: center;
    gap: $spacing-xs;
    margin-bottom: $spacing-sm;

    .reason-icon {
      font-size: $font-size-md;
    }

    .reason-title {
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      color: $danger;
    }
  }

  .reason-content {
    font-size: $font-size-sm;
    color: $text-secondary;
    line-height: $line-height-base;
    background-color: rgba(244, 67, 54, 0.05);
    padding: $spacing-md;
    border-radius: $radius-base;
  }
}

// 菜品列表
.items-list {
  .item-row {
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
      }

      .item-desc {
        display: block;
        font-size: $font-size-xs;
        color: $text-secondary;
        margin-bottom: 4rpx;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .item-note {
        display: flex;
        align-items: flex-start;
        gap: 4rpx;
        margin-top: $spacing-xs;

        .note-label {
          font-size: $font-size-xxs;
          color: $text-tertiary;
          flex-shrink: 0;
        }

        .note-text {
          font-size: $font-size-xxs;
          color: $text-tertiary;
          flex: 1;
        }
      }
    }

    .item-quantity {
      flex-shrink: 0;
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

// 订单汇总
.order-summary {
  margin-top: $spacing-lg;
  padding-top: $spacing-lg;
  border-top: 1rpx solid $border-light;

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;

    .summary-label {
      font-size: $font-size-base;
      color: $text-secondary;
    }

    .summary-value {
      font-size: $font-size-lg;
      color: $primary;
      font-weight: $font-weight-bold;
    }
  }
}

// 用户信息
.user-content {
  display: flex;
  align-items: center;
  gap: $spacing-md;

  .user-avatar {
    width: 80rpx;
    height: 80rpx;
    border-radius: 40rpx;
    background: $gradient-primary;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;

    .avatar-text {
      font-size: $font-size-xl;
      color: white;
      font-weight: $font-weight-bold;
    }
  }

  .user-details {
    flex: 1;
    display: flex;
    align-items: center;
    gap: $spacing-sm;

    .user-name {
      font-size: $font-size-base;
      color: $text-primary;
      font-weight: $font-weight-medium;
    }

    .user-badge {
      font-size: $font-size-xs;
      color: $primary;
      background-color: rgba(255, 138, 101, 0.1);
      padding: 4rpx $spacing-xs;
      border-radius: $radius-sm;
    }
  }
}

// 底部操作栏
.footer-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  gap: $spacing-md;
  padding: $spacing-base;
  background-color: white;
  border-top: 1rpx solid $border-light;
  box-shadow: 0 -4rpx 12rpx rgba(0, 0, 0, 0.05);
  z-index: 100;

  .action-btn {
    flex: 1;
    height: 88rpx;
    border-radius: $radius-button;
    font-size: $font-size-base;
    font-weight: $font-weight-bold;
    border: none;
    transition: all $duration-base $ease-out;

    &:active {
      transform: scale(0.96);
    }

    &.cancel-btn {
      background-color: transparent;
      border: 2rpx solid $border-base;
      color: $text-secondary;

      &:active {
        background-color: $bg-section;
      }
    }

    &.repeat-btn {
      background: $gradient-secondary;
      color: white;
      box-shadow: $shadow-primary;

      &:active {
        box-shadow: $shadow-primary-hover;
      }
    }

    &.cooking-btn,
    &.complete-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8rpx;
      background: $gradient-primary;
      color: white;
      box-shadow: $shadow-primary;

      .btn-icon {
        font-size: 32rpx;
      }

      .btn-text {
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
      }

      &:active {
        box-shadow: $shadow-primary-hover;
      }
    }
  }
}

// 订单评价卡片
.review-card {
  .review-content {
    .review-rating {
      display: flex;
      align-items: center;
      gap: 8rpx;
      margin-bottom: $spacing-md;

      .star {
        font-size: 36rpx;

        &.filled {
          color: #FFB800;
        }
      }
    }

    .review-emoji {
      margin-bottom: $spacing-md;

      .emoji-text {
        font-size: 48rpx;
      }
    }

    .review-comment {
      background-color: $bg-section;
      padding: $spacing-md;
      border-radius: $radius-base;
      margin-bottom: $spacing-sm;

      .comment-text {
        font-size: $font-size-base;
        color: $text-primary;
        line-height: $line-height-base;
      }
    }

    .review-time {
      .time-text {
        font-size: $font-size-xs;
        color: $text-tertiary;
      }
    }
  }

  .no-review {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: $spacing-lg 0;

    .no-review-text {
      font-size: $font-size-sm;
      color: $text-secondary;
      margin-bottom: $spacing-md;
    }

    .review-btn {
      display: flex;
      align-items: center;
      gap: 8rpx;
      padding: $spacing-sm $spacing-lg;
      background: $gradient-secondary;
      color: white;
      border: none;
      border-radius: $radius-button;
      font-weight: $font-weight-bold;
      box-shadow: $shadow-primary;

      .btn-icon {
        font-size: 24rpx;
      }

      .btn-text {
        font-size: $font-size-base;
      }

      &:active {
        transform: scale(0.96);
      }
    }
  }
}

// 取消订单弹窗
.cancel-modal {
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

      .cancel-reason-input {
        width: 100%;
        min-height: 200rpx;
        padding: $spacing-base;
        background-color: $bg-section;
        border-radius: $radius-base;
        font-size: $font-size-base;
        color: $text-primary;
        line-height: $line-height-base;
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

        &.cancel-confirm-btn {
          background-color: $bg-section;
          color: $text-secondary;

          &:active {
            background-color: $bg-disabled;
          }
        }

        &.submit-btn {
          background: $gradient-primary;
          color: white;
          box-shadow: $shadow-primary;

          &:disabled {
            opacity: 0.6;
          }

          &:active:not(:disabled) {
            box-shadow: $shadow-primary-hover;
          }
        }
      }
    }
  }
}

// 评价订单弹窗
.review-modal {
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
    width: 640rpx;
    max-height: 80vh;
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
      max-height: 60vh;
      overflow-y: auto;

      .rating-section {
        margin-bottom: $spacing-xl;

        .rating-label {
          display: block;
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
          margin-bottom: $spacing-md;
        }

        .rating-stars {
          display: flex;
          align-items: center;
          gap: 16rpx;

          .star-item {
            font-size: 48rpx;
            cursor: pointer;
            transition: transform 0.2s;

            &:active {
              transform: scale(1.2);
            }
          }
        }
      }

      .emoji-section {
        margin-bottom: $spacing-xl;

        .emoji-label {
          display: block;
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
          margin-bottom: $spacing-md;
        }

        .emoji-list {
          display: flex;
          flex-wrap: wrap;
          gap: 16rpx;

          .emoji-item {
            width: 72rpx;
            height: 72rpx;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40rpx;
            background-color: $bg-section;
            border-radius: $radius-base;
            border: 2rpx solid transparent;
            transition: all 0.2s;

            &.selected {
              background-color: rgba(255, 138, 101, 0.1);
              border-color: $primary;
              transform: scale(1.1);
            }

            &:active {
              transform: scale(0.9);
            }
          }
        }
      }

      .comment-section {
        .comment-label {
          display: block;
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
          margin-bottom: $spacing-md;
        }

        .comment-input {
          width: 100%;
          min-height: 200rpx;
          padding: $spacing-base;
          background-color: $bg-section;
          border: 2rpx solid transparent;
          border-radius: $radius-base;
          font-size: $font-size-base;
          color: $text-primary;
          line-height: $line-height-base;
          transition: all 0.2s;

          &:focus {
            background-color: white;
            border-color: $primary;
            box-shadow: 0 2rpx 8rpx rgba(255, 138, 101, 0.15);
          }
        }

        .comment-counter {
          display: flex;
          justify-content: flex-end;
          margin-top: $spacing-sm;

          .counter-text {
            font-size: $font-size-xs;
            color: $text-tertiary;
          }
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
        transition: all 0.2s;

        &.cancel-btn {
          background-color: $bg-section;
          color: $text-secondary;

          &:active {
            background-color: $bg-disabled;
          }
        }

        &.submit-btn {
          background: $gradient-primary;
          color: white;
          box-shadow: $shadow-primary;

          &:disabled {
            opacity: 0.6;
          }

          &:active:not(:disabled) {
            transform: scale(0.98);
            box-shadow: $shadow-primary-hover;
          }
        }
      }
    }
  }
}
</style>
