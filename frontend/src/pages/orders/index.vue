<template>
  <view class="orders-page">
    <!-- 顶部导航栏 -->
    <view class="top-navbar">
      <view class="navbar-left">
        <text class="page-title">💭 美食心愿</text>
      </view>
      <view class="navbar-right">
        <view class="nav-btn" @click="showFilter">
          <text class="btn-icon">🔍</text>
        </view>
      </view>
    </view>

    <!-- 状态过滤器（悬浮标签） -->
    <scroll-view class="status-filter" scroll-x :show-scrollbar="false">
      <view
        class="filter-chip"
        :class="{ active: activeStatus === status.value }"
        v-for="status in statusTabs"
        :key="status.value"
        @click="selectStatus(status.value)"
      >
        <text class="chip-text">{{ status.label }}</text>
        <view class="chip-badge" v-if="status.count > 0">{{ status.count }}</view>
      </view>
    </scroll-view>

    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading && orders.length === 0">
      <view class="loading-spinner"></view>
      <text class="loading-text">加载中...</text>
    </view>

    <!-- 订单时间线 -->
    <scroll-view
      class="orders-timeline"
      v-else-if="orders.length > 0"
      scroll-y
      refresher-enabled
      :refresher-triggered="isRefreshing"
      @refresherrefresh="onRefresh"
    >
      <view
        class="timeline-card"
        :class="`status-${order.status}`"
        v-for="order in orders"
        :key="order.id"
        @click="viewOrderDetail(order)"
      >
        <!-- 时间线节点 -->
        <view class="timeline-dot">
          <text class="dot-icon">{{ getStatusIcon(order.status) }}</text>
        </view>

        <!-- 订单卡片内容 -->
        <view class="card-content">
          <!-- 卡片头部 -->
          <view class="card-header">
            <view class="user-section">
              <image
                v-if="order.user?.avatar"
                class="user-avatar"
                :src="order.user.avatar"
                mode="aspectFill"
              />
              <view v-else class="user-avatar-placeholder">
                <text class="avatar-text">{{ order.user?.nickname?.charAt(0) || '?' }}</text>
              </view>
              <view class="user-info">
                <text class="user-name">{{ order.user?.nickname || '未知用户' }}</text>
                <text class="order-time">{{ formatOrderTime(order.created_at) }}</text>
              </view>
            </view>
            <view class="status-badge" :class="`badge-${order.status}`">
              <text class="badge-text">{{ getStatusText(order.status) }}</text>
            </view>
          </view>

          <!-- 心愿文字 -->
          <view class="wish-section">
            <text class="wish-text">{{ getWishText(order) }}</text>
          </view>

          <!-- 菜品展示区 -->
          <view class="dishes-showcase">
            <view
              class="dish-photo"
              v-for="(item, index) in order.items?.slice(0, 3)"
              :key="item.id"
              :class="`photo-count-${Math.min(order.items.length, 3)}`"
            >
              <image
                class="photo-img"
                :src="item.recipe_image || defaultRecipeImage"
                mode="aspectFill"
              />
              <view class="photo-overlay" v-if="index === 2 && order.items.length > 3">
                <text class="overlay-text">+{{ order.items.length - 3 }}</text>
              </view>
            </view>
          </view>

          <!-- 互动底栏 -->
          <view class="card-interactions">
            <view class="interaction-info">
              <text class="info-text">{{ order.item_count }}道菜</text>
              <text class="info-divider" v-if="order.meal_time">·</text>
              <text class="info-text" v-if="order.meal_time">{{ formatMealTime(order.meal_time) }}</text>
            </view>
            <view class="interaction-actions" @click.stop>
              <view
                v-if="canRepeat(order)"
                class="action-btn"
                @click="showRepeatConfirm(order)"
              >
                <text class="action-icon">🔄</text>
                <text class="action-text">再来一次</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- 加载更多 -->
      <view class="load-more" v-if="hasMore && !isLoadingMore">
        <button class="load-more-btn" @click="loadMore">
          加载更多
        </button>
      </view>

      <view class="no-more" v-if="!hasMore && orders.length > 0">
        <text class="no-more-text">没有更多了</text>
      </view>
    </scroll-view>

    <!-- 空状态 -->
    <view class="empty-state" v-else>
      <text class="empty-icon">📋</text>
      <text class="empty-text">{{ emptyText }}</text>
      <text class="empty-desc">快去点餐吧</text>
      <button class="btn btn-primary" @click="goToHome">
        去点餐
      </button>
    </view>

    <!-- 再来一单确认弹窗 -->
    <view class="repeat-modal" v-if="showRepeatModal" @click="closeRepeatModal">
      <view class="modal-content" @click.stop>
        <view class="modal-header">
          <text class="modal-title">再来一单</text>
          <text class="modal-close" @click="closeRepeatModal">✕</text>
        </view>
        <view class="modal-body">
          <text class="modal-message">确定要重新下单这些菜品吗？</text>
          <view class="order-summary" v-if="currentRepeatOrder">
            <text class="summary-label">订单内容：</text>
            <view class="summary-items">
              <text
                class="summary-item"
                v-for="(item, index) in currentRepeatOrder.items"
                :key="item.id"
              >
                {{ item.recipe_name }} x{{ item.quantity }}
              </text>
            </view>
          </view>
        </view>
        <view class="modal-actions">
          <button class="modal-btn cancel-btn" @click="closeRepeatModal">
            取消
          </button>
          <button
            class="modal-btn confirm-btn"
            :disabled="isRepeating"
            @click="confirmRepeatOrder"
          >
            {{ isRepeating ? '处理中...' : '确认下单' }}
          </button>
        </view>
      </view>
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
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { OrderService, OrderUtils, type Order, type OrderStatus } from '@/api/order'

// 响应式数据
const isLoading = ref(true)
const isRefreshing = ref(false)
const isLoadingMore = ref(false)
const orders = ref<Order[]>([])
const activeStatus = ref<OrderStatus | 'all'>('all')
const currentPage = ref(1)
const pageSize = 20
const totalCount = ref(0)
const statusCounts = ref<Record<string, number>>({})
const isFirstLoad = ref(true) // 标记是否首次加载

// 取消订单相关
const showCancelModal = ref(false)
const cancelReason = ref('')
const currentCancelOrder = ref<Order | null>(null)
const isCancelling = ref(false)

// 再来一单相关
const showRepeatModal = ref(false)
const currentRepeatOrder = ref<Order | null>(null)
const isRepeating = ref(false)

// 默认菜谱图片
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 状态标签页配置（温馨版）
const statusTabs = computed(() => [
  { label: '全部', value: 'all', count: 0 },
  { label: '💭 想吃', value: 'pending', count: statusCounts.value['pending'] || 0 },
  { label: '👨‍🍳 在做', value: 'cooking', count: statusCounts.value['cooking'] || 0 },
  { label: '🔔 做好啦', value: 'completed', count: statusCounts.value['completed'] || 0 },
  { label: '已取消', value: 'cancelled', count: statusCounts.value['cancelled'] || 0 }
])

// 计算属性
const hasMore = computed(() => {
  return orders.value.length < totalCount.value
})

const emptyText = computed(() => {
  if (activeStatus.value === 'all') {
    return '还没有点过餐呢'
  }
  const statusTextMap: Record<string, string> = {
    pending: '暂时还没有想吃的',
    cooking: '现在没有在做的菜',
    completed: '还没有完成的订单',
    cancelled: '没有取消的订单'
  }
  return statusTextMap[activeStatus.value] || '暂无订单'
})

// 页面加载
onMounted(async () => {
  await loadOrders()
})

// 页面显示时刷新
onShow(async () => {
  console.log('订单页面显示')

  // 如果是首次加载，跳过（onMounted会处理）
  if (isFirstLoad.value) {
    console.log('首次加载，跳过onShow刷新')
    isFirstLoad.value = false
    return
  }

  // 非首次显示时刷新订单列表
  console.log('刷新订单列表')
  await loadOrders(true)
})

// 加载订单列表
const loadOrders = async (refresh = false) => {
  try {
    if (refresh) {
      currentPage.value = 1
      orders.value = []
    }

    isLoading.value = true

    const params: any = {
      page: currentPage.value,
      size: pageSize,
      sort_by: 'created_at',
      sort_order: 'desc'
    }

    if (activeStatus.value !== 'all') {
      params.status = activeStatus.value
    }

    console.log('加载订单列表，参数:', params)

    const result = await OrderService.getOrderList(params)

    console.log('订单列表加载成功:', result)

    if (refresh) {
      orders.value = result.list || []
    } else {
      orders.value = [...orders.value, ...(result.list || [])]
    }

    totalCount.value = result.total || 0

    // 统计各状态订单数量
    await loadStatusCounts()

  } catch (error: any) {
    console.error('加载订单列表失败:', error)

    // 权限错误静默处理
    if (error?.statusCode !== 403 && error?.statusCode !== 400) {
      uni.showToast({
        title: error.message || '加载失败',
        icon: 'error'
      })
    }
  } finally {
    isLoading.value = false
    isLoadingMore.value = false
  }
}

// 加载状态统计
const loadStatusCounts = async () => {
  try {
    // 使用统计接口获取各状态订单数量
    const stats = await OrderService.getOrderStats(365) // 查询最近一年的统计

    const counts: Record<string, number> = {}
    if (stats.status_stats && Array.isArray(stats.status_stats)) {
      stats.status_stats.forEach((stat: any) => {
        counts[stat.status] = stat.count
      })
    }

    statusCounts.value = counts
  } catch (error) {
    console.error('加载状态统计失败:', error)
  }
}

// 选择状态
const selectStatus = async (status: OrderStatus | 'all') => {
  if (activeStatus.value === status) return

  activeStatus.value = status
  currentPage.value = 1
  orders.value = []
  await loadOrders()
}

// 加载更多
const loadMore = async () => {
  if (isLoadingMore.value || !hasMore.value) return

  isLoadingMore.value = true
  currentPage.value += 1
  await loadOrders()
}

// 查看订单详情
const viewOrderDetail = (order: Order) => {
  uni.navigateTo({
    url: `/pages/orders/detail?id=${order.id}`
  })
}

// 取消订单
const cancelOrder = (order: Order) => {
  currentCancelOrder.value = order
  cancelReason.value = ''
  showCancelModal.value = true
}

// 关闭取消弹窗
const closeCancelModal = () => {
  showCancelModal.value = false
  currentCancelOrder.value = null
  cancelReason.value = ''
}

// 确认取消订单
const confirmCancel = async () => {
  if (!currentCancelOrder.value || isCancelling.value) return

  try {
    isCancelling.value = true

    await OrderService.cancelOrder(
      currentCancelOrder.value.id,
      cancelReason.value
    )

    uni.showToast({
      title: '订单已取消',
      icon: 'success',
      duration: 1500
    })

    closeCancelModal()

    // 刷新列表
    await loadOrders(true)

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

// 显示再来一单确认弹窗
const showRepeatConfirm = (order: Order) => {
  currentRepeatOrder.value = order
  showRepeatModal.value = true
}

// 关闭再来一单弹窗
const closeRepeatModal = () => {
  showRepeatModal.value = false
  currentRepeatOrder.value = null
}

// 确认重复下单
const confirmRepeatOrder = async () => {
  if (!currentRepeatOrder.value || isRepeating.value) return

  try {
    isRepeating.value = true

    const newOrder = await OrderService.repeatOrder(currentRepeatOrder.value.id)

    uni.showToast({
      title: '下单成功',
      icon: 'success',
      duration: 1500
    })

    closeRepeatModal()

    // 刷新列表
    await loadOrders(true)

    // 跳转到订单详情
    setTimeout(() => {
      uni.navigateTo({
        url: `/pages/orders/detail?id=${newOrder.id}`
      })
    }, 1500)

  } catch (error: any) {
    console.error('重复下单失败:', error)
    uni.showToast({
      title: error.message || '下单失败',
      icon: 'error'
    })
  } finally {
    isRepeating.value = false
  }
}

// 前往首页
const goToHome = () => {
  uni.switchTab({
    url: '/pages/index/index'
  })
}

// 下拉刷新
const onRefresh = async () => {
  isRefreshing.value = true
  await loadOrders(true)
  setTimeout(() => {
    isRefreshing.value = false
    uni.showToast({
      title: '刷新成功',
      icon: 'success',
      duration: 1000
    })
  }, 500)
}

// 搜索/筛选
const showFilter = () => {
  uni.showToast({
    title: '筛选功能开发中',
    icon: 'none'
  })
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

// 工具函数
const getStatusText = (status: OrderStatus) => {
  return OrderUtils.getStatusText(status)
}

const getStatusColor = (status: OrderStatus) => {
  return OrderUtils.getStatusColor(status)
}

const formatOrderTime = (dateStr: string) => {
  return OrderUtils.formatOrderTime(dateStr)
}

const canCancel = (order: Order) => {
  return OrderUtils.canCancel(order)
}

const canRepeat = (order: Order) => {
  return OrderUtils.canRepeat(order)
}

const formatMealTime = (mealTime: string) => {
  if (!mealTime) return ''

  const date = new Date(mealTime)
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const mealDate = new Date(date.getFullYear(), date.getMonth(), date.getDate())

  const diffTime = mealDate.getTime() - today.getTime()
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))

  const hours = date.getHours().toString().padStart(2, '0')
  const minutes = date.getMinutes().toString().padStart(2, '0')
  const timeStr = `${hours}:${minutes}`

  if (diffDays === 0) {
    return `今天 ${timeStr}`
  } else if (diffDays === 1) {
    return `明天 ${timeStr}`
  } else if (diffDays === -1) {
    return `昨天 ${timeStr}`
  } else {
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    return `${month}-${day} ${timeStr}`
  }
}

const getWishText = (order: Order) => {
  const userName = order.user?.nickname || '未知用户'
  const itemCount = order.item_count || 0

  if (order.status === 'pending') {
    return `${userName}想吃这些～`
  } else if (order.status === 'cooking') {
    return `正在为${userName}准备中❤️`
  } else if (order.status === 'completed') {
    return `${userName}的美食做好啦🎉`
  } else if (order.status === 'cancelled') {
    return `${userName}取消了订单`
  } else {
    return `${userName}的订单`
  }
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.orders-page {
  min-height: 100vh;
  background: linear-gradient(180deg, #FAFAFA 0%, #FFFFFF 100%);
  padding-bottom: 40rpx;
}

// 顶部导航栏
.top-navbar {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10rpx);
  border-bottom: 1rpx solid rgba(0, 0, 0, 0.05);
  padding: 20rpx 24rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;

  .navbar-left {
    .page-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }
  }

  .navbar-right {
    .nav-btn {
      width: 56rpx;
      height: 56rpx;
      border-radius: 28rpx;
      background: $bg-section;
      @include flex-center;
      transition: all $duration-fast;

      &:active {
        transform: scale(0.9);
        background: $bg-hover;
      }

      .btn-icon {
        font-size: 32rpx;
      }
    }
  }
}

// 状态过滤器
.status-filter {
  padding: 20rpx 24rpx;
  border-bottom: 1rpx solid rgba(0, 0, 0, 0.05);
  white-space: nowrap;
  background: white;

  .filter-chip {
    display: inline-flex;
    align-items: center;
    gap: 8rpx;
    padding: 12rpx 24rpx;
    margin-right: 16rpx;
    border-radius: 40rpx;
    background: $bg-section;
    transition: all $duration-base;

    &.active {
      background: $gradient-primary;
      box-shadow: $shadow-primary;

      .chip-text {
        color: white;
        font-weight: $font-weight-bold;
      }

      .chip-badge {
        background: rgba(255, 255, 255, 0.3);
        color: white;
      }
    }

    .chip-text {
      font-size: $font-size-sm;
      color: $text-secondary;
      transition: all $duration-base;
    }

    .chip-badge {
      min-width: 32rpx;
      height: 32rpx;
      padding: 0 10rpx;
      border-radius: 16rpx;
      background: $primary;
      color: white;
      font-size: 20rpx;
      font-weight: $font-weight-bold;
      @include flex-center;
    }

    &:active {
      transform: scale(0.95);
    }
  }
}

// 加载状态
.loading-state {
  @include flex-center;
  flex-direction: column;
  padding: 120rpx 40rpx;

  .loading-spinner {
    width: 60rpx;
    height: 60rpx;
    border-radius: 50%;
    border: 4rpx solid $bg-section;
    border-top-color: $primary;
    animation: spin 0.8s linear infinite;
    margin-bottom: 20rpx;
  }

  .loading-text {
    font-size: $font-size-sm;
    color: $text-tertiary;
  }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

// 订单时间线
.orders-timeline {
  height: calc(100vh - 260rpx);
  padding: 0 24rpx;

  .timeline-card {
    position: relative;
    padding-left: 80rpx;
    margin-bottom: 32rpx;
    transition: all $duration-base;

    &:active {
      .card-content {
        transform: scale(0.98);
      }
    }

    // 时间线节点
    .timeline-dot {
      position: absolute;
      left: 0;
      top: 0;
      width: 64rpx;
      height: 64rpx;
      border-radius: 50%;
      background: $gradient-primary;
      box-shadow: $shadow-primary;
      @include flex-center;
      z-index: 10;

      .dot-icon {
        font-size: 32rpx;
      }

      // 时间线连接线
      &::after {
        content: '';
        position: absolute;
        top: 64rpx;
        left: 50%;
        transform: translateX(-50%);
        width: 4rpx;
        height: calc(100% + 32rpx);
        background: linear-gradient(180deg, $primary 0%, rgba(255, 138, 101, 0.2) 100%);
      }
    }

    // 最后一个卡片不显示连接线
    &:last-child {
      .timeline-dot::after {
        display: none;
      }
    }

    // 不同状态的颜色
    &.status-pending .timeline-dot {
      background: linear-gradient(135deg, #FFA726 0%, #FB8C00 100%);
    }

    &.status-cooking .timeline-dot {
      background: $gradient-primary;
    }

    &.status-completed .timeline-dot {
      background: linear-gradient(135deg, #66BB6A 0%, #4CAF50 100%);
    }

    &.status-cancelled .timeline-dot {
      background: linear-gradient(135deg, #BDBDBD 0%, #9E9E9E 100%);
    }
  }
}

// 卡片内容
.card-content {
  background: white;
  border-radius: $radius-lg;
  overflow: hidden;
  box-shadow: $shadow-base;
  transition: all $duration-base;

  // 卡片头部
  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20rpx 24rpx;

    .user-section {
      display: flex;
      align-items: center;
      gap: 16rpx;
      flex: 1;

      .user-avatar {
        width: 64rpx;
        height: 64rpx;
        border-radius: 50%;
        flex-shrink: 0;
      }

      .user-avatar-placeholder {
        width: 64rpx;
        height: 64rpx;
        border-radius: 50%;
        background: $gradient-primary;
        @include flex-center;
        flex-shrink: 0;

        .avatar-text {
          font-size: $font-size-lg;
          font-weight: $font-weight-bold;
          color: white;
        }
      }

      .user-info {
        flex: 1;
        min-width: 0;

        .user-name {
          display: block;
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
          margin-bottom: 4rpx;
          @include text-ellipsis(1);
        }

        .order-time {
          font-size: $font-size-xs;
          color: $text-tertiary;
        }
      }
    }

    .status-badge {
      flex-shrink: 0;
      padding: 6rpx 16rpx;
      border-radius: 40rpx;
      font-size: $font-size-xxs;
      font-weight: $font-weight-bold;

      &.badge-pending {
        background: rgba(255, 167, 38, 0.15);
        color: $warning;
      }

      &.badge-cooking {
        background: rgba(255, 138, 101, 0.15);
        color: $primary;
      }

      &.badge-completed {
        background: rgba(102, 187, 106, 0.15);
        color: $success;
      }

      &.badge-cancelled {
        background: rgba(189, 189, 189, 0.15);
        color: $text-tertiary;
      }

      .badge-text {
        font-size: inherit;
        color: inherit;
      }
    }
  }

  // 心愿文字
  .wish-section {
    padding: 16rpx 24rpx;
    background: rgba(255, 138, 101, 0.05);

    .wish-text {
      font-size: $font-size-sm;
      color: $text-secondary;
      line-height: $line-height-base;
    }
  }

  // 菜品展示区
  .dishes-showcase {
    display: flex;
    gap: 8rpx;
    padding: 16rpx 24rpx;

    .dish-photo {
      position: relative;
      flex: 1;
      height: 200rpx;
      border-radius: $radius-md;
      overflow: hidden;

      &.photo-count-1 {
        flex: 1 1 100%;
        height: 300rpx;
      }

      &.photo-count-2 {
        height: 240rpx;
      }

      .photo-img {
        width: 100%;
        height: 100%;
      }

      .photo-overlay {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.4);
        @include flex-center;

        .overlay-text {
          font-size: $font-size-xl;
          font-weight: $font-weight-bold;
          color: white;
        }
      }
    }
  }

  // 互动底栏
  .card-interactions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16rpx 24rpx;
    border-top: 1rpx solid $border-light;

    .interaction-info {
      display: flex;
      align-items: center;
      gap: 12rpx;

      .info-text {
        font-size: $font-size-sm;
        color: $text-secondary;
      }

      .info-divider {
        font-size: $font-size-sm;
        color: $text-placeholder;
      }
    }

    .interaction-actions {
      display: flex;
      gap: 12rpx;

      .action-btn {
        display: flex;
        align-items: center;
        gap: 6rpx;
        padding: 8rpx 20rpx;
        border-radius: 40rpx;
        background: rgba(255, 138, 101, 0.1);
        transition: all $duration-fast;

        &:active {
          transform: scale(0.95);
          background: rgba(255, 138, 101, 0.2);
        }

        .action-icon {
          font-size: 24rpx;
        }

        .action-text {
          font-size: $font-size-sm;
          color: $primary;
          font-weight: $font-weight-medium;
        }
      }
    }
  }
}

// 加载更多
.load-more {
  padding: $spacing-base;
  text-align: center;

  .load-more-btn {
    padding: $spacing-md $spacing-xl;
    background-color: transparent;
    border: 2rpx solid $border-base;
    border-radius: $radius-button;
    font-size: $font-size-sm;
    color: $text-secondary;

    &:active {
      background-color: $bg-section;
    }
  }
}

.no-more {
  padding: $spacing-lg;
  text-align: center;

  .no-more-text {
    font-size: $font-size-xs;
    color: $text-tertiary;
  }
}

// 空状态
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 120rpx 40rpx;
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

// 再来一单确认弹窗
.repeat-modal {
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

      .modal-message {
        display: block;
        font-size: $font-size-base;
        color: $text-primary;
        line-height: $line-height-base;
        margin-bottom: $spacing-lg;
      }

      .order-summary {
        padding: $spacing-base;
        background-color: $bg-section;
        border-radius: $radius-base;

        .summary-label {
          display: block;
          font-size: $font-size-sm;
          color: $text-secondary;
          margin-bottom: $spacing-sm;
        }

        .summary-items {
          display: flex;
          flex-direction: column;
          gap: $spacing-xs;

          .summary-item {
            font-size: $font-size-sm;
            color: $text-primary;
            padding: 4rpx 0;
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
</style>
