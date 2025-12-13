<template>
  <view class="couple-home" v-if="displayMode === 'couple'">
    <!-- 顶部温馨标题 -->
    <view class="home-header">
      <view class="couple-title">
        <text class="title-emoji">💕</text>
        <text class="title-text">我们的小食堂</text>
        <view class="invite-btn" @click="showInviteDialog">
          <text class="invite-icon">🎉</text>
        </view>
      </view>
      <view class="couple-avatars">
        <image v-if="currentUser?.avatar" class="avatar mine" :src="currentUser.avatar" mode="aspectFill" />
        <view v-else class="avatar mine placeholder">
          <text class="avatar-text">{{ currentUser?.nickname?.charAt(0) || '我' }}</text>
        </view>
        <view class="heart-icon">❤️</view>
        <image v-if="partnerUser?.avatar" class="avatar partner" :src="partnerUser.avatar" mode="aspectFill" />
        <view v-else class="avatar partner placeholder">
          <text class="avatar-text">{{ partnerUser?.nickname?.charAt(0) || 'Ta' }}</text>
        </view>
      </view>
    </view>

    <!-- 滚动内容区 -->
    <scroll-view
      class="home-scroll"
      scroll-y
      refresher-enabled
      :refresher-triggered="isRefreshing"
      @refresherrefresh="onRefresh"
    >
      <!-- Ta想吃这些 -->
      <view class="section partner-wishes" v-if="partnerPendingOrders.length > 0">
        <view class="section-header">
          <text class="section-icon">💭</text>
          <text class="section-title">Ta想吃这些（{{ partnerPendingOrders.length }}个心愿）</text>
        </view>
        <view
          class="wish-card"
          v-for="order in partnerPendingOrders"
          :key="order.id"
          @click="viewOrderDetail(order)"
        >
          <view class="card-header">
            <view class="user-info">
              <image v-if="order.user?.avatar" class="user-avatar" :src="order.user.avatar" mode="aspectFill" />
              <view v-else class="user-avatar placeholder">
                <text class="avatar-text">{{ order.user?.nickname?.charAt(0) }}</text>
              </view>
              <view class="user-details">
                <text class="user-name">{{ order.user?.nickname }}</text>
                <text class="wish-time">{{ formatWishTime(order.created_at) }}</text>
              </view>
            </view>
          </view>

          <view class="card-content">
            <text class="wish-note" v-if="order.note">{{ order.note }}</text>
            <text class="wish-note default" v-else>想吃这些美食～</text>
          </view>

          <view class="card-dishes" v-if="order.items && order.items.length > 0">
            <view
              class="dish-item"
              v-for="(item, index) in order.items.slice(0, 3)"
              :key="index"
            >
              <image
                v-if="item.recipe_image"
                class="dish-image"
                :src="item.recipe_image"
                mode="aspectFill"
              />
              <view v-else class="dish-image placeholder">
                <text class="dish-emoji">🍽️</text>
              </view>
              <view class="dish-info">
                <text class="dish-name">{{ item.recipe_name }}</text>
                <text class="dish-quantity">x{{ item.quantity }}</text>
              </view>
            </view>
            <view class="more-dishes" v-if="order.items.length > 3">
              <text class="more-text">还有{{ order.items.length - 3 }}道菜...</text>
            </view>
          </view>

          <view class="card-actions">
            <button class="action-btn primary" @click.stop="startCooking(order)">
              <text class="btn-icon">❤️</text>
              <text class="btn-text">开始做</text>
            </button>
            <button class="action-btn secondary" @click.stop="replyToPartner(order)">
              <text class="btn-icon">💬</text>
              <text class="btn-text">回复Ta</text>
            </button>
          </view>
        </view>
      </view>

      <!-- Ta想吃这些 - 空状态 -->
      <view class="section partner-wishes empty" v-else>
        <view class="empty-state">
          <text class="empty-icon">💭</text>
          <text class="empty-title">Ta还没有想吃的</text>
          <text class="empty-desc">等Ta点餐后这里会显示哦～</text>
        </view>
      </view>

      <!-- 我在做的 -->
      <view class="section my-cooking" v-if="myCookingOrders.length > 0">
        <view class="section-header">
          <text class="section-icon">👨‍🍳</text>
          <text class="section-title">我在做的（{{ myCookingOrders.length }}个）</text>
        </view>
        <view
          class="cooking-card"
          v-for="order in myCookingOrders"
          :key="order.id"
          @click="viewOrderDetail(order)"
        >
          <view class="cooking-header">
            <view class="cooking-info">
              <text class="cooking-dish">{{ getOrderMainDish(order) }}</text>
              <text class="cooking-for">为{{ order.user?.nickname }}准备中</text>
            </view>
            <view class="cooking-status">
              <text class="status-icon">⏱️</text>
              <text class="status-text">烹饪中</text>
            </view>
          </view>

          <view class="cooking-dishes" v-if="order.items && order.items.length > 1">
            <text class="dishes-list">
              还有{{ order.items.slice(1).map(item => item.recipe_name).join('、') }}
            </text>
          </view>

          <view class="cooking-action">
            <button class="done-btn" @click.stop="markAsDone(order)">
              <text class="btn-icon">🔔</text>
              <text class="btn-text">做好啦！</text>
            </button>
          </view>
        </view>
      </view>

      <!-- Ta最爱的菜 -->
      <view class="section favorite-recipes">
        <view class="section-header">
          <text class="section-icon">📖</text>
          <text class="section-title">Ta最爱的菜</text>
          <text class="section-more" @click="viewAllRecipes">查看全部 ></text>
        </view>
        <view class="recipes-grid">
          <view
            class="recipe-card"
            v-for="recipe in favoriteRecipes.slice(0, 4)"
            :key="recipe.id"
            @click="viewRecipeDetail(recipe)"
          >
            <image
              v-if="recipe.image"
              class="recipe-image"
              :src="recipe.image"
              mode="aspectFill"
            />
            <view v-else class="recipe-image placeholder">
              <text class="recipe-emoji">🍽️</text>
            </view>
            <view class="recipe-info">
              <text class="recipe-name">{{ recipe.name }}</text>
              <view class="recipe-meta">
                <text class="meta-item">⏱️ {{ recipe.cooking_time }}分</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- 底部安全距离 -->
      <view class="bottom-safe-area"></view>
    </scroll-view>

  </view>

  <!-- 聚会/家庭模式 - Instagram Feed 风格 -->
  <view class="party-home" v-else>
    <!-- 顶部标题栏 -->
    <view class="party-header">
      <view class="party-title">
        <text class="title-emoji">🎉</text>
        <text class="title-text">{{ displayMode === 'party' ? '今日聚会' : '家庭小食堂' }}</text>
        <view class="member-count" v-if="displayMode === 'party'">
          <text class="count-text">{{ guestCount }}位朋友</text>
        </view>
      </view>
      <view class="header-actions">
        <view class="action-icon" @click="showInviteDialog" v-if="displayMode === 'party'">
          <text class="icon-text">🎁</text>
        </view>
      </view>
    </view>

    <!-- Stories 动态条 -->
    <scroll-view class="stories-container" scroll-x show-scrollbar="false">
      <!-- 当前用户（可发布） -->
      <view class="story-item my-story" @click="createOrder">
        <view class="story-avatar add-story">
          <image v-if="currentUser?.avatar" class="avatar-img" :src="currentUser.avatar" mode="aspectFill" />
          <view v-else class="avatar-placeholder">
            <text class="avatar-text">{{ currentUser?.nickname?.charAt(0) || '我' }}</text>
          </view>
          <view class="add-icon">+</view>
        </view>
        <text class="story-name">发布心愿</text>
      </view>

      <!-- 其他成员 Stories -->
      <view
        class="story-item"
        v-for="member in members.filter(m => m.id !== currentUser?.id)"
        :key="member.id"
        @click="viewMemberOrders(member)"
      >
        <view class="story-avatar" :class="{ 'has-story': hasPendingOrders(member) }">
          <image v-if="member.avatar" class="avatar-img" :src="member.avatar" mode="aspectFill" />
          <view v-else class="avatar-placeholder">
            <text class="avatar-text">{{ member.nickname?.charAt(0) }}</text>
          </view>
        </view>
        <text class="story-name">{{ member.nickname }}</text>
        <view class="guest-badge" v-if="member.role === 'guest'">
          <text class="badge-text">访客</text>
        </view>
      </view>
    </scroll-view>

    <!-- Feed 动态卡片流 -->
    <scroll-view
      class="feed-scroll"
      scroll-y
      refresher-enabled
      :refresher-triggered="isRefreshing"
      @refresherrefresh="onRefresh"
    >
      <!-- 所有pending订单的动态卡片 -->
      <view
        class="feed-card"
        v-for="order in allPendingOrders"
        :key="order.id"
        @click="viewOrderDetail(order)"
      >
        <!-- 卡片头部：用户信息 -->
        <view class="feed-header">
          <view class="user-info">
            <image v-if="order.user?.avatar" class="user-avatar" :src="order.user.avatar" mode="aspectFill" />
            <view v-else class="user-avatar placeholder">
              <text class="avatar-text">{{ order.user?.nickname?.charAt(0) }}</text>
            </view>
            <view class="user-details">
              <view class="user-name-row">
                <text class="user-name">{{ order.user?.nickname }}</text>
                <view class="guest-tag" v-if="order.is_guest_order">
                  <text class="tag-text">访客</text>
                </view>
              </view>
              <text class="post-time">{{ formatWishTime(order.created_at) }}</text>
            </view>
          </view>
        </view>

        <!-- 卡片内容：心愿文字 -->
        <view class="feed-content">
          <text class="wish-text" v-if="order.note">{{ order.note }}</text>
          <text class="wish-text default" v-else>想吃这些美食～</text>
        </view>

        <!-- 卡片图片：菜品照片网格 -->
        <view class="feed-images" v-if="order.items && order.items.length > 0">
          <view class="images-grid" :class="getGridClass(order.items.length)">
            <view
              class="grid-image"
              v-for="(item, index) in order.items.slice(0, 4)"
              :key="index"
            >
              <image
                v-if="item.recipe_image"
                class="dish-img"
                :src="item.recipe_image"
                mode="aspectFill"
              />
              <view v-else class="dish-img placeholder">
                <text class="placeholder-emoji">🍽️</text>
              </view>
              <view class="image-overlay" v-if="index === 3 && order.items.length > 4">
                <text class="overlay-text">+{{ order.items.length - 4 }}</text>
              </view>
            </view>
          </view>
        </view>

        <!-- 卡片互动栏 -->
        <view class="feed-actions">
          <view class="action-group">
            <view class="action-btn" @click.stop="toggleLike(order)">
              <text class="action-icon" :class="{ liked: order.liked }">{{ order.liked ? '❤️' : '🤍' }}</text>
              <text class="action-text" v-if="order.like_count">{{ order.like_count }}</text>
            </view>
            <view class="action-btn" @click.stop="replyToPartner(order)">
              <text class="action-icon">💬</text>
              <text class="action-text" v-if="order.comment_count">{{ order.comment_count }}</text>
            </view>
            <view class="action-btn" @click.stop="shareOrder(order)">
              <text class="action-icon">📤</text>
            </view>
          </view>
          <view class="action-cook" v-if="currentUser?.role === 'admin'">
            <button class="cook-btn" @click.stop="startCooking(order)">
              <text class="btn-icon">❤️</text>
              <text class="btn-text">开始做</text>
            </button>
          </view>
        </view>
      </view>

      <!-- 空状态 -->
      <view class="feed-empty" v-if="allPendingOrders.length === 0">
        <view class="empty-content">
          <text class="empty-icon">🍽️</text>
          <text class="empty-title">还没有人点餐哦</text>
          <text class="empty-desc">点击上方"发布心愿"开始点餐吧～</text>
        </view>
      </view>

      <!-- 底部安全距离 -->
      <view class="feed-safe-area"></view>
    </scroll-view>

  </view>

  <!-- 邀请弹窗 -->
  <view class="invite-modal" v-if="showInvite" @click="closeInviteDialog">
    <view class="modal-content" @click.stop>
      <view class="modal-header">
        <text class="header-title">🎉 邀请朋友</text>
        <view class="close-btn" @click="closeInviteDialog">
          <text class="close-icon">×</text>
        </view>
      </view>

      <view class="modal-body">
        <view class="invite-code-section">
          <text class="section-label">邀请码</text>
          <view class="code-display">
            <text class="code-text">{{ invitationCode || '生成中...' }}</text>
          </view>
          <text class="code-hint">24小时有效 · 朋友可使用此码加入聚会</text>
        </view>

        <view class="action-buttons">
          <button class="btn-copy" @click="copyInviteCode">
            <text class="btn-icon">📋</text>
            <text class="btn-text">复制邀请码</text>
          </button>
          <button class="btn-share" @click="shareInvite">
            <text class="btn-icon">📤</text>
            <text class="btn-text">分享给朋友</text>
          </button>
        </view>

        <view class="invite-info">
          <view class="info-item">
            <text class="info-icon">👥</text>
            <text class="info-text">已有 {{ guestCount }} 位朋友加入</text>
          </view>
          <view class="info-item">
            <text class="info-icon">⏰</text>
            <text class="info-text">访客24小时后自动退出</text>
          </view>
        </view>
      </view>

      <view class="modal-footer" v-if="guestCount > 0">
        <button class="btn-end-party" @click="endParty">
          <text class="btn-text">结束聚会</text>
        </button>
      </view>
    </view>
  </view>

  <!-- 回复弹窗 -->
  <view class="reply-modal" v-if="showReplyDialog" @click="closeReplyDialog">
    <view class="modal-content" @click.stop>
      <view class="modal-header">
        <text class="header-title">💬 回复Ta</text>
        <view class="close-btn" @click="closeReplyDialog">
          <text class="close-icon">×</text>
        </view>
      </view>

      <view class="modal-body">
        <!-- 订单信息 -->
        <view class="order-info" v-if="replyTargetOrder">
          <view class="order-user">
            <image v-if="replyTargetOrder.user?.avatar" class="user-avatar" :src="replyTargetOrder.user.avatar" mode="aspectFill" />
            <view v-else class="user-avatar placeholder">
              <text class="avatar-text">{{ replyTargetOrder.user?.nickname?.charAt(0) }}</text>
            </view>
            <text class="user-name">{{ replyTargetOrder.user?.nickname }}</text>
            <text class="order-note">{{ replyTargetOrder.note || '想吃这些美食～' }}</text>
          </view>
        </view>

        <!-- 回复列表 -->
        <view class="replies-list" v-if="orderReplies.length > 0">
          <view class="reply-item" v-for="reply in orderReplies" :key="reply.id">
            <image v-if="reply.user?.avatar" class="reply-avatar" :src="reply.user.avatar" mode="aspectFill" />
            <view v-else class="reply-avatar placeholder">
              <text class="avatar-text">{{ reply.user?.nickname?.charAt(0) }}</text>
            </view>
            <view class="reply-content">
              <view class="reply-header">
                <text class="reply-name">{{ reply.user?.nickname }}</text>
                <text class="reply-time">{{ formatReplyTime(reply.created_at) }}</text>
              </view>
              <text class="reply-text">{{ reply.content }}</text>
            </view>
          </view>
        </view>

        <!-- 空状态 -->
        <view class="replies-empty" v-else-if="!isLoadingReplies">
          <text class="empty-text">还没有回复，快来说点什么吧～</text>
        </view>

        <!-- 加载中 -->
        <view class="replies-loading" v-if="isLoadingReplies">
          <text class="loading-text">加载中...</text>
        </view>
      </view>

      <!-- 输入区域 -->
      <view class="reply-input-area">
        <input
          class="reply-input"
          v-model="replyContent"
          type="text"
          placeholder="说点什么..."
          maxlength="200"
          :disabled="isSubmittingReply"
        />
        <button
          class="send-btn"
          @click="submitReply"
          :disabled="isSubmittingReply || !replyContent.trim()"
        >
          <text class="btn-text">{{ isSubmittingReply ? '发送中' : '发送' }}</text>
        </button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { FamilyService } from '@/api/family'
import { OrderService, type Order, type OrderStatus, type OrderReply } from '@/api/order'
import { RecipeService, type Recipe } from '@/api/recipe'

// 状态数据
const isLoading = ref(true)
const isRefreshing = ref(false)
const hasFamily = ref(false)

// 用户数据
const currentUser = ref<any>(null)
const partnerUser = ref<any>(null)
const members = ref<any[]>([])

// 订单数据
const partnerPendingOrders = ref<Order[]>([])
const myCookingOrders = ref<Order[]>([])
const allPendingOrders = ref<Order[]>([]) // 聚会模式：所有人的pending订单

// 菜谱数据
const favoriteRecipes = ref<Recipe[]>([])

// 邀请弹窗数据
const showInvite = ref(false)
const invitationCode = ref('')
const guestCount = computed(() => members.value.filter(m => m.role === 'guest').length)

// 回复弹窗数据
const showReplyDialog = ref(false)
const replyTargetOrder = ref<Order | null>(null)
const replyContent = ref('')
const orderReplies = ref<OrderReply[]>([])
const isLoadingReplies = ref(false)
const isSubmittingReply = ref(false)

// 显示模式
const displayMode = computed(() => {
  // 如果还没有加载成员数据，默认使用情侣模式
  if (members.value.length === 0) {
    console.log('[首页] 成员数据未加载，默认显示情侣模式')
    return 'couple'
  }

  const memberCount = members.value.filter(m => m.role !== 'guest').length
  const hasGuests = members.value.some(m => m.role === 'guest')

  console.log('[首页] 成员统计:', {
    总成员数: members.value.length,
    正式成员数: memberCount,
    访客数: members.value.filter(m => m.role === 'guest').length,
    有访客: hasGuests
  })

  if (hasGuests) {
    console.log('[首页] 切换到聚会模式（有访客）')
    return 'party'
  }

  if (memberCount === 2) {
    console.log('[首页] 切换到情侣模式（2人）')
    return 'couple'
  }

  console.log('[首页] 切换到家庭模式（>2人）')
  return 'family'
})

// 初始化
onMounted(async () => {
  await initializeData()
})

onShow(async () => {
  if (!isLoading.value) {
    await refreshData()
  }
})

const initializeData = async () => {
  try {
    isLoading.value = true
    hasFamily.value = FamilyService.hasFamily()

    if (hasFamily.value) {
      await loadMembers()

      // 根据模式加载不同数据
      if (displayMode.value === 'couple') {
        await Promise.all([
          loadPartnerOrders(),
          loadMyCookingOrders(),
          loadFavoriteRecipes()
        ])
      } else {
        // 聚会/家庭模式
        await loadAllPendingOrders()
      }
    }
  } catch (error) {
    console.error('初始化失败:', error)
    uni.showToast({
      title: '加载失败',
      icon: 'none'
    })
  } finally {
    isLoading.value = false
  }
}

// 加载成员
const loadMembers = async () => {
  try {
    // 加载所有成员（包括访客）
    members.value = await FamilyService.getFamilyMembers(true)

    console.log('[首页] 成员数据加载成功:', members.value)

    // 获取当前用户ID
    const userInfo = uni.getStorageSync('userInfo')
    const currentUserId = userInfo?.id

    // 找到当前用户和伴侣
    currentUser.value = members.value.find(m => m.id === currentUserId)
    partnerUser.value = members.value.find(m => m.id !== currentUserId && m.role !== 'guest')

    console.log('[首页] 当前用户:', currentUser.value)
    console.log('[首页] 伴侣用户:', partnerUser.value)
  } catch (error) {
    console.error('[首页] 加载成员失败:', error)
    uni.showToast({
      title: '加载成员失败',
      icon: 'none'
    })
  }
}

// 加载对方的pending订单
const loadPartnerOrders = async () => {
  try {
    if (!partnerUser.value) {
      console.log('[首页] 伴侣用户不存在，跳过加载伴侣订单')
      return
    }

    console.log('[首页] 正在加载伴侣订单...', { partner_id: partnerUser.value.id })

    const response = await OrderService.getOrderList({
      page: 1,
      size: 10,
      user_id: partnerUser.value.id,
      status: 'pending' as OrderStatus
    })

    partnerPendingOrders.value = response.list || []
    console.log('[首页] 伴侣订单加载成功:', partnerPendingOrders.value.length, '个')
  } catch (error) {
    console.error('[首页] 加载伴侣订单失败:', error)
  }
}

// 加载我在做的订单
const loadMyCookingOrders = async () => {
  try {
    console.log('[首页] 正在加载我在做的订单...')

    const response = await OrderService.getOrderList({
      page: 1,
      size: 10,
      status: 'cooking' as OrderStatus
    })

    myCookingOrders.value = response.list || []
    console.log('[首页] 烹饪订单加载成功:', myCookingOrders.value.length, '个')
  } catch (error) {
    console.error('[首页] 加载烹饪订单失败:', error)
  }
}

// 加载对方喜欢的菜谱
const loadFavoriteRecipes = async () => {
  try {
    const response = await RecipeService.getRecipeList({
      page: 1,
      size: 6,
      sort_by: 'created_at',
      sort_order: 'desc'
    })

    favoriteRecipes.value = response.list || []
  } catch (error) {
    console.error('加载菜谱失败:', error)
  }
}

// 加载所有人的pending订单（聚会/家庭模式）
const loadAllPendingOrders = async () => {
  try {
    console.log('[首页] 正在加载所有待处理订单...')

    const response = await OrderService.getOrderList({
      page: 1,
      size: 50,
      status: 'pending' as OrderStatus
    })

    allPendingOrders.value = (response.list || []).map(order => ({
      ...order,
      liked: getLikeStatus(order.id), // 从本地存储获取点赞状态
      like_count: 0,
      comment_count: 0
    }))

    console.log('[首页] 所有待处理订单加载成功:', allPendingOrders.value.length, '个')
  } catch (error) {
    console.error('[首页] 加载订单列表失败:', error)
  }
}

// 刷新数据
const refreshData = async () => {
  if (displayMode.value === 'couple') {
    await Promise.all([
      loadPartnerOrders(),
      loadMyCookingOrders(),
      loadFavoriteRecipes()
    ])
  } else {
    await loadAllPendingOrders()
  }
}

// 下拉刷新
const onRefresh = async () => {
  isRefreshing.value = true
  await refreshData()
  setTimeout(() => {
    isRefreshing.value = false
    uni.showToast({
      title: '刷新成功',
      icon: 'success',
      duration: 1000
    })
  }, 500)
}

// 格式化心愿时间
const formatWishTime = (dateStr: string) => {
  const date = new Date(dateStr)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)

  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`

  const month = date.getMonth() + 1
  const day = date.getDate()
  return `${month}月${day}日`
}

// 获取订单主菜
const getOrderMainDish = (order: Order) => {
  if (order.items && order.items.length > 0) {
    return order.items[0].recipe_name
  }
  return '美食'
}

// 开始做饭
const startCooking = async (order: Order) => {
  try {
    await OrderService.updateOrderStatus(order.id, 'cooking' as OrderStatus)

    uni.showToast({
      title: '开始做饭啦！',
      icon: 'success'
    })

    await refreshData()
  } catch (error) {
    console.error('开始做饭失败:', error)
    uni.showToast({
      title: '操作失败',
      icon: 'none'
    })
  }
}

// 标记为完成
const markAsDone = async (order: Order) => {
  try {
    await OrderService.updateOrderStatus(order.id, 'completed' as OrderStatus)

    uni.showToast({
      title: '做好啦！快叫Ta来吃～',
      icon: 'success'
    })

    await refreshData()
  } catch (error) {
    console.error('标记完成失败:', error)
    uni.showToast({
      title: '操作失败',
      icon: 'none'
    })
  }
}

// 回复对方
const replyToPartner = async (order: Order) => {
  replyTargetOrder.value = order
  replyContent.value = ''
  orderReplies.value = []
  showReplyDialog.value = true
  await loadOrderReplies(order.id)
}

// 加载订单回复
const loadOrderReplies = async (orderId: number) => {
  try {
    isLoadingReplies.value = true
    orderReplies.value = await OrderService.getOrderReplies(orderId)
  } catch (error) {
    console.error('加载回复失败:', error)
  } finally {
    isLoadingReplies.value = false
  }
}

// 提交回复
const submitReply = async () => {
  if (!replyContent.value.trim() || !replyTargetOrder.value) {
    uni.showToast({
      title: '请输入回复内容',
      icon: 'none'
    })
    return
  }

  try {
    isSubmittingReply.value = true
    const reply = await OrderService.createOrderReply(
      replyTargetOrder.value.id,
      replyContent.value.trim()
    )
    orderReplies.value.push(reply)
    replyContent.value = ''
    uni.showToast({
      title: '回复成功',
      icon: 'success'
    })
  } catch (error) {
    console.error('回复失败:', error)
    uni.showToast({
      title: '回复失败',
      icon: 'none'
    })
  } finally {
    isSubmittingReply.value = false
  }
}

// 关闭回复弹窗
const closeReplyDialog = () => {
  showReplyDialog.value = false
  replyTargetOrder.value = null
  replyContent.value = ''
  orderReplies.value = []
}

// 格式化回复时间
const formatReplyTime = (dateStr: string) => {
  const date = new Date(dateStr)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)

  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`

  const month = date.getMonth() + 1
  const day = date.getDate()
  const hour = date.getHours().toString().padStart(2, '0')
  const minute = date.getMinutes().toString().padStart(2, '0')
  return `${month}月${day}日 ${hour}:${minute}`
}

// 查看订单详情
const viewOrderDetail = (order: Order) => {
  uni.navigateTo({
    url: `/pages/orders/detail?id=${order.id}`
  })
}

// 查看菜谱详情
const viewRecipeDetail = (recipe: Recipe) => {
  uni.navigateTo({
    url: `/pages/recipes/detail?id=${recipe.id}`
  })
}

// 创建订单
const createOrder = () => {
  uni.navigateTo({
    url: '/pages/orders/create'
  })
}

// 浏览菜谱
const browseRecipes = () => {
  uni.switchTab({
    url: '/pages/recipes/index'
  })
}

// 查看全部菜谱
const viewAllRecipes = () => {
  uni.switchTab({
    url: '/pages/recipes/index'
  })
}

// 显示邀请弹窗
const showInviteDialog = async () => {
  try {
    console.log('[首页] 正在生成访客邀请码...')

    // 调用后端API生成邀请码
    const invite = await FamilyService.createGuestInvite({
      note: '欢迎来做客',
      expires_hours: 24
    })

    invitationCode.value = invite.invite_code
    console.log('[首页] 邀请码生成成功:', invitationCode.value)

    showInvite.value = true
  } catch (error) {
    console.error('[首页] 生成邀请码失败:', error)
    uni.showToast({
      title: '生成邀请码失败',
      icon: 'none'
    })
  }
}

// 关闭邀请弹窗
const closeInviteDialog = () => {
  showInvite.value = false
}

// 复制邀请码
const copyInviteCode = () => {
  uni.setClipboardData({
    data: invitationCode.value,
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
  const shareText = `我邀请你来家里做客！\n邀请码：${invitationCode.value}\n24小时有效，快来点餐吧～`

  uni.setClipboardData({
    data: shareText,
    success: () => {
      uni.showToast({
        title: '邀请信息已复制，快去分享给朋友吧',
        icon: 'success',
        duration: 2000
      })
    }
  })
}

// 结束聚会
const endParty = async () => {
  uni.showModal({
    title: '结束聚会',
    content: `确定要结束聚会吗？所有访客（${guestCount.value}位）将被移除`,
    confirmText: '结束',
    confirmColor: '#FF8A65',
    success: async (res) => {
      if (res.confirm) {
        try {
          // 调用后端API结束聚会
          const result = await FamilyService.endParty()

          uni.showToast({
            title: `聚会已结束，已移除${result.removed_count}位访客`,
            icon: 'success',
            duration: 2000
          })

          closeInviteDialog()
          await loadMembers()
          await refreshData()
        } catch (error) {
          console.error('结束聚会失败:', error)
          uni.showToast({
            title: '操作失败',
            icon: 'none'
          })
        }
      }
    }
  })
}

// 聚会模式相关函数

// 判断成员是否有pending订单
const hasPendingOrders = (member: any) => {
  return allPendingOrders.value.some(order => order.user_id === member.id)
}

// 查看成员的订单
const viewMemberOrders = (member: any) => {
  const memberOrders = allPendingOrders.value.filter(order => order.user_id === member.id)
  if (memberOrders.length > 0) {
    viewOrderDetail(memberOrders[0])
  } else {
    uni.showToast({
      title: `${member.nickname}还没有点餐`,
      icon: 'none'
    })
  }
}

// 点赞/取消点赞（使用本地存储持久化）
const toggleLike = (order: any) => {
  order.liked = !order.liked
  if (order.liked) {
    order.like_count = (order.like_count || 0) + 1
  } else {
    order.like_count = Math.max((order.like_count || 0) - 1, 0)
  }

  // 保存点赞状态到本地存储
  saveLikeStatus(order.id, order.liked)
}

// 保存点赞状态
const saveLikeStatus = (orderId: number, liked: boolean) => {
  try {
    const likedOrders = uni.getStorageSync('liked_orders') || {}
    if (liked) {
      likedOrders[orderId] = true
    } else {
      delete likedOrders[orderId]
    }
    uni.setStorageSync('liked_orders', likedOrders)
  } catch (error) {
    console.error('保存点赞状态失败:', error)
  }
}

// 获取点赞状态
const getLikeStatus = (orderId: number): boolean => {
  try {
    const likedOrders = uni.getStorageSync('liked_orders') || {}
    return !!likedOrders[orderId]
  } catch (error) {
    return false
  }
}

// 应用点赞状态到订单列表
const applyLikeStatus = (orders: any[]) => {
  orders.forEach(order => {
    order.liked = getLikeStatus(order.id)
  })
}

// 分享订单
const shareOrder = (order: Order) => {
  const dishNames = order.items?.map(item => item.recipe_name).join('、') || '美食'
  const shareText = `${order.user?.nickname}想吃：${dishNames}\n快来帮忙做吧～`

  uni.setClipboardData({
    data: shareText,
    success: () => {
      uni.showToast({
        title: '订单信息已复制',
        icon: 'success'
      })
    }
  })
}

// 获取图片网格样式类
const getGridClass = (count: number) => {
  if (count === 1) return 'grid-1'
  if (count === 2) return 'grid-2'
  if (count === 3) return 'grid-3'
  return 'grid-4'
}

// 查看所有订单
const viewAllOrders = () => {
  uni.switchTab({
    url: '/pages/orders/index'
  })
}
</script>

<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.couple-home {
  min-height: 100vh;
  background: linear-gradient(180deg, #FFF8F5 0%, #FFFFFF 100%);
  padding-bottom: env(safe-area-inset-bottom);
}

// 顶部头部
.home-header {
  padding: 32rpx 24rpx;
  text-align: center;

  .couple-title {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12rpx;
    margin-bottom: 24rpx;
    position: relative;

    .title-emoji {
      font-size: 48rpx;
    }

    .title-text {
      font-size: $font-size-xl;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }

    .invite-btn {
      position: absolute;
      right: 24rpx;
      width: 64rpx;
      height: 64rpx;
      border-radius: 50%;
      background: $gradient-primary;
      @include flex-center;
      box-shadow: $shadow-primary;
      transition: all $duration-fast;

      &:active {
        transform: scale(0.9);
      }

      .invite-icon {
        font-size: 32rpx;
      }
    }
  }

  .couple-avatars {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 24rpx;

    .avatar {
      width: 96rpx;
      height: 96rpx;
      border-radius: 50%;
      border: 4rpx solid $primary;

      &.placeholder {
        background: $gradient-primary;
        @include flex-center;

        .avatar-text {
          font-size: $font-size-lg;
          font-weight: $font-weight-bold;
          color: white;
        }
      }
    }

    .heart-icon {
      font-size: 32rpx;
      animation: heartbeat 1.5s ease-in-out infinite;
    }
  }
}

@keyframes heartbeat {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

// 滚动区域
.home-scroll {
  height: calc(100vh - 280rpx);
}

// 板块样式
.section {
  margin: 24rpx 0;
  padding: 0 24rpx;

  .section-header {
    display: flex;
    align-items: center;
    margin-bottom: 16rpx;

    .section-icon {
      font-size: 32rpx;
      margin-right: 8rpx;
    }

    .section-title {
      flex: 1;
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }

    .section-more {
      font-size: $font-size-sm;
      color: $primary;
    }
  }
}

// Ta想吃的卡片
.wish-card {
  background: white;
  border-radius: $radius-lg;
  padding: 24rpx;
  margin-bottom: 16rpx;
  box-shadow: $shadow-base;
  transition: all $duration-fast;

  &:active {
    transform: scale(0.98);
  }

  .card-header {
    margin-bottom: 16rpx;

    .user-info {
      display: flex;
      align-items: center;
      gap: 12rpx;

      .user-avatar {
        width: 56rpx;
        height: 56rpx;
        border-radius: 50%;

        &.placeholder {
          background: $gradient-primary;
          @include flex-center;

          .avatar-text {
            font-size: $font-size-sm;
            font-weight: $font-weight-bold;
            color: white;
          }
        }
      }

      .user-details {
        flex: 1;
        display: flex;
        flex-direction: column;

        .user-name {
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
        }

        .wish-time {
          font-size: $font-size-xs;
          color: $text-tertiary;
        }
      }
    }
  }

  .card-content {
    margin-bottom: 16rpx;

    .wish-note {
      font-size: $font-size-base;
      color: $text-primary;
      line-height: $line-height-base;

      &.default {
        color: $text-secondary;
        font-style: italic;
      }
    }
  }

  .card-dishes {
    margin-bottom: 20rpx;

    .dish-item {
      display: flex;
      align-items: center;
      gap: 12rpx;
      padding: 12rpx;
      background: $bg-section;
      border-radius: $radius-md;
      margin-bottom: 8rpx;

      .dish-image {
        width: 64rpx;
        height: 64rpx;
        border-radius: $radius-sm;

        &.placeholder {
          background: $bg-hover;
          @include flex-center;

          .dish-emoji {
            font-size: 32rpx;
          }
        }
      }

      .dish-info {
        flex: 1;
        display: flex;
        flex-direction: column;

        .dish-name {
          font-size: $font-size-base;
          font-weight: $font-weight-medium;
          color: $text-primary;
          margin-bottom: 4rpx;
        }

        .dish-quantity {
          font-size: $font-size-sm;
          color: $text-secondary;
        }
      }
    }

    .more-dishes {
      padding: 8rpx;
      text-align: center;

      .more-text {
        font-size: $font-size-sm;
        color: $text-tertiary;
      }
    }
  }

  .card-actions {
    display: flex;
    gap: 12rpx;

    .action-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8rpx;
      height: 72rpx;
      border-radius: $radius-button;
      border: none;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      transition: all $duration-fast;

      &.primary {
        background: $gradient-primary;
        color: white;
        box-shadow: $shadow-primary;
      }

      &.secondary {
        background: $bg-section;
        color: $text-primary;
      }

      &:active {
        transform: scale(0.96);
      }

      .btn-icon {
        font-size: 28rpx;
      }

      .btn-text {
        font-size: $font-size-base;
      }
    }
  }
}

// 空状态
.empty-state {
  @include flex-center;
  flex-direction: column;
  padding: 80rpx 40rpx;
  text-align: center;

  .empty-icon {
    font-size: 96rpx;
    margin-bottom: 24rpx;
    opacity: 0.6;
  }

  .empty-title {
    font-size: $font-size-lg;
    font-weight: $font-weight-bold;
    color: $text-primary;
    margin-bottom: 12rpx;
  }

  .empty-desc {
    font-size: $font-size-sm;
    color: $text-secondary;
    line-height: $line-height-base;
  }
}

// 烹饪中的卡片
.cooking-card {
  background: white;
  border-radius: $radius-lg;
  padding: 24rpx;
  margin-bottom: 16rpx;
  box-shadow: $shadow-base;
  border-left: 6rpx solid $primary;

  .cooking-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12rpx;

    .cooking-info {
      flex: 1;

      .cooking-dish {
        display: block;
        font-size: $font-size-lg;
        font-weight: $font-weight-bold;
        color: $text-primary;
        margin-bottom: 4rpx;
      }

      .cooking-for {
        font-size: $font-size-sm;
        color: $text-secondary;
      }
    }

    .cooking-status {
      display: flex;
      align-items: center;
      gap: 4rpx;
      padding: 8rpx 16rpx;
      background: rgba($primary, 0.1);
      border-radius: $radius-button;

      .status-icon {
        font-size: 24rpx;
      }

      .status-text {
        font-size: $font-size-sm;
        color: $primary;
        font-weight: $font-weight-bold;
      }
    }
  }

  .cooking-dishes {
    margin-bottom: 16rpx;

    .dishes-list {
      font-size: $font-size-sm;
      color: $text-secondary;
      line-height: $line-height-base;
    }
  }

  .cooking-action {
    .done-btn {
      width: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8rpx;
      height: 72rpx;
      background: $gradient-primary;
      color: white;
      border: none;
      border-radius: $radius-button;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      box-shadow: $shadow-primary;

      &:active {
        transform: scale(0.98);
      }

      .btn-icon {
        font-size: 28rpx;
      }
    }
  }
}

// 菜谱网格
.recipes-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16rpx;

  .recipe-card {
    background: white;
    border-radius: $radius-lg;
    overflow: hidden;
    box-shadow: $shadow-base;
    transition: all $duration-fast;

    &:active {
      transform: scale(0.96);
    }

    .recipe-image {
      width: 100%;
      height: 240rpx;

      &.placeholder {
        background: $bg-section;
        @include flex-center;

        .recipe-emoji {
          font-size: 64rpx;
        }
      }
    }

    .recipe-info {
      padding: 12rpx;

      .recipe-name {
        display: block;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        color: $text-primary;
        margin-bottom: 8rpx;
        @include text-ellipsis(2);
      }

      .recipe-meta {
        display: flex;
        align-items: center;
        gap: 12rpx;

        .meta-item {
          font-size: $font-size-xs;
          color: $text-tertiary;
        }
      }
    }
  }
}

// 底部安全距离
.bottom-safe-area {
  height: 80rpx;
}

// 其他模式占位
.social-home {
  @include flex-center;
  min-height: 100vh;
  padding: 40rpx;
  text-align: center;
  font-size: $font-size-lg;
  color: $text-tertiary;
}

// 邀请弹窗
.invite-modal {
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
    animation: modalSlideUp 0.3s ease-out;
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
      cursor: pointer;
      transition: all $duration-fast;

      &:active {
        background: $bg-hover;
        transform: scale(0.9);
      }

      .close-icon {
        font-size: 48rpx;
        color: $text-tertiary;
        line-height: 1;
      }
    }
  }

  .modal-body {
    padding: 32rpx 24rpx;

    .invite-code-section {
      margin-bottom: 32rpx;

      .section-label {
        display: block;
        font-size: $font-size-sm;
        color: $text-secondary;
        margin-bottom: 12rpx;
      }

      .code-display {
        background: $bg-section;
        border: 2rpx dashed $primary;
        border-radius: $radius-lg;
        padding: 24rpx;
        text-align: center;
        margin-bottom: 8rpx;

        .code-text {
          font-size: 48rpx;
          font-weight: $font-weight-bold;
          color: $primary;
          letter-spacing: 8rpx;
          font-family: monospace;
        }
      }

      .code-hint {
        font-size: $font-size-xs;
        color: $text-tertiary;
        text-align: center;
      }
    }

    .action-buttons {
      display: flex;
      gap: 12rpx;
      margin-bottom: 32rpx;

      .btn-copy,
      .btn-share {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8rpx;
        height: 88rpx;
        border: none;
        border-radius: $radius-button;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        transition: all $duration-fast;

        &:active {
          transform: scale(0.96);
        }

        .btn-icon {
          font-size: 28rpx;
        }
      }

      .btn-copy {
        background: $bg-section;
        color: $text-primary;
      }

      .btn-share {
        background: $gradient-primary;
        color: white;
        box-shadow: $shadow-primary;
      }
    }

    .invite-info {
      background: $bg-section;
      border-radius: $radius-lg;
      padding: 20rpx;

      .info-item {
        display: flex;
        align-items: center;
        gap: 12rpx;
        padding: 8rpx 0;

        .info-icon {
          font-size: 28rpx;
        }

        .info-text {
          font-size: $font-size-sm;
          color: $text-secondary;
        }
      }
    }
  }

  .modal-footer {
    padding: 0 24rpx 24rpx;

    .btn-end-party {
      width: 100%;
      height: 88rpx;
      background: white;
      border: 2rpx solid $error;
      color: $error;
      border-radius: $radius-button;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      transition: all $duration-fast;

      &:active {
        background: rgba($error, 0.05);
        transform: scale(0.96);
      }
    }
  }
}

@keyframes modalSlideUp {
  from {
    opacity: 0;
    transform: translateY(100rpx);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

// 聚会/家庭模式样式
.party-home {
  min-height: 100vh;
  background: $bg-page;
  padding-bottom: env(safe-area-inset-bottom);
}

// 聚会顶部标题栏
.party-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx;
  background: white;
  border-bottom: 1rpx solid $border-light;

  .party-title {
    display: flex;
    align-items: center;
    gap: 12rpx;

    .title-emoji {
      font-size: 40rpx;
    }

    .title-text {
      font-size: $font-size-xl;
      font-weight: $font-weight-bold;
      color: $text-primary;
    }

    .member-count {
      margin-left: 8rpx;
      padding: 4rpx 12rpx;
      background: rgba($primary, 0.1);
      border-radius: $radius-button;

      .count-text {
        font-size: $font-size-xs;
        color: $primary;
        font-weight: $font-weight-bold;
      }
    }
  }

  .header-actions {
    .action-icon {
      width: 56rpx;
      height: 56rpx;
      @include flex-center;
      border-radius: 50%;
      background: $bg-section;

      &:active {
        background: $bg-hover;
        transform: scale(0.9);
      }

      .icon-text {
        font-size: 32rpx;
      }
    }
  }
}

// Stories 动态条
.stories-container {
  padding: 20rpx 0;
  white-space: nowrap;
  background: white;
  border-bottom: 1rpx solid $border-light;

  .story-item {
    display: inline-block;
    width: 100rpx;
    margin: 0 12rpx;
    text-align: center;
    vertical-align: top;

    &:first-child {
      margin-left: 24rpx;
    }

    &:last-child {
      margin-right: 24rpx;
    }

    .story-avatar {
      width: 88rpx;
      height: 88rpx;
      border-radius: 50%;
      margin: 0 auto 8rpx;
      position: relative;
      border: 3rpx solid $border-light;
      overflow: hidden;

      &.has-story {
        border: 3rpx solid transparent;
        background: $instagram-gradient;
        padding: 4rpx;
      }

      &.add-story {
        background: $bg-section;
        @include flex-center;
        border: 2rpx dashed $primary;

        .avatar-img,
        .avatar-placeholder {
          width: 100%;
          height: 100%;
          border-radius: 50%;
        }

        .avatar-placeholder {
          background: $gradient-primary;
          @include flex-center;

          .avatar-text {
            font-size: $font-size-lg;
            font-weight: $font-weight-bold;
            color: white;
          }
        }

        .add-icon {
          position: absolute;
          right: -2rpx;
          bottom: -2rpx;
          width: 32rpx;
          height: 32rpx;
          border-radius: 50%;
          background: $gradient-primary;
          color: white;
          font-size: 24rpx;
          font-weight: $font-weight-bold;
          @include flex-center;
          border: 2rpx solid white;
        }
      }

      .avatar-img {
        width: 100%;
        height: 100%;
        border-radius: 50%;
      }

      .avatar-placeholder {
        width: 100%;
        height: 100%;
        border-radius: 50%;
        background: $gradient-primary;
        @include flex-center;

        .avatar-text {
          font-size: $font-size-lg;
          font-weight: $font-weight-bold;
          color: white;
        }
      }
    }

    .story-name {
      display: block;
      font-size: $font-size-xs;
      color: $text-secondary;
      @include text-ellipsis(1);
      max-width: 100rpx;
    }

    .guest-badge {
      margin-top: 4rpx;
      padding: 2rpx 8rpx;
      background: rgba($warning, 0.1);
      border-radius: $radius-sm;

      .badge-text {
        font-size: 20rpx;
        color: $warning;
      }
    }
  }
}

// Feed 滚动区域
.feed-scroll {
  height: calc(100vh - 240rpx);
}

// Feed 卡片
.feed-card {
  background: white;
  margin-bottom: 16rpx;
  transition: all $duration-fast;

  &:active {
    opacity: 0.95;
  }

  // 卡片头部
  .feed-header {
    padding: 16rpx 20rpx;

    .user-info {
      display: flex;
      align-items: center;
      gap: 12rpx;

      .user-avatar {
        width: 64rpx;
        height: 64rpx;
        border-radius: 50%;

        &.placeholder {
          background: $gradient-primary;
          @include flex-center;

          .avatar-text {
            font-size: $font-size-base;
            font-weight: $font-weight-bold;
            color: white;
          }
        }
      }

      .user-details {
        flex: 1;

        .user-name-row {
          display: flex;
          align-items: center;
          gap: 8rpx;
          margin-bottom: 4rpx;

          .user-name {
            font-size: $font-size-base;
            font-weight: $font-weight-bold;
            color: $text-primary;
          }

          .guest-tag {
            padding: 2rpx 8rpx;
            background: rgba($warning, 0.1);
            border-radius: $radius-sm;

            .tag-text {
              font-size: 20rpx;
              color: $warning;
            }
          }
        }

        .post-time {
          font-size: $font-size-xs;
          color: $text-tertiary;
        }
      }
    }
  }

  // 卡片内容
  .feed-content {
    padding: 0 20rpx 16rpx;

    .wish-text {
      font-size: $font-size-base;
      color: $text-primary;
      line-height: $line-height-base;

      &.default {
        color: $text-secondary;
        font-style: italic;
      }
    }
  }

  // 卡片图片网格
  .feed-images {
    width: 100%;

    .images-grid {
      display: grid;
      gap: 2rpx;

      &.grid-1 {
        grid-template-columns: 1fr;

        .grid-image {
          height: 600rpx;
        }
      }

      &.grid-2 {
        grid-template-columns: 1fr 1fr;

        .grid-image {
          height: 375rpx;
        }
      }

      &.grid-3 {
        grid-template-columns: 1fr 1fr;

        .grid-image {
          height: 250rpx;

          &:first-child {
            grid-column: 1 / 3;
            height: 500rpx;
          }
        }
      }

      &.grid-4 {
        grid-template-columns: 1fr 1fr;

        .grid-image {
          height: 250rpx;
        }
      }

      .grid-image {
        position: relative;
        overflow: hidden;

        .dish-img {
          width: 100%;
          height: 100%;

          &.placeholder {
            background: $bg-section;
            @include flex-center;

            .placeholder-emoji {
              font-size: 64rpx;
            }
          }
        }

        .image-overlay {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.5);
          @include flex-center;

          .overlay-text {
            font-size: 48rpx;
            font-weight: $font-weight-bold;
            color: white;
          }
        }
      }
    }
  }

  // 卡片互动栏
  .feed-actions {
    padding: 12rpx 20rpx;
    display: flex;
    align-items: center;
    justify-content: space-between;

    .action-group {
      display: flex;
      align-items: center;
      gap: 24rpx;

      .action-btn {
        display: flex;
        align-items: center;
        gap: 6rpx;
        padding: 8rpx 12rpx;
        border-radius: $radius-md;
        transition: all $duration-fast;

        &:active {
          background: $bg-section;
        }

        .action-icon {
          font-size: 40rpx;

          &.liked {
            animation: heartBeat 0.5s ease-out;
          }
        }

        .action-text {
          font-size: $font-size-sm;
          color: $text-secondary;
        }
      }
    }

    .action-cook {
      .cook-btn {
        display: flex;
        align-items: center;
        gap: 6rpx;
        padding: 8rpx 20rpx;
        background: $gradient-primary;
        color: white;
        border: none;
        border-radius: $radius-button;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        box-shadow: $shadow-primary;
        transition: all $duration-fast;

        &:active {
          transform: scale(0.95);
        }

        .btn-icon {
          font-size: 24rpx;
        }
      }
    }
  }
}

// Feed 空状态
.feed-empty {
  @include flex-center;
  padding: 120rpx 40rpx;

  .empty-content {
    text-align: center;

    .empty-icon {
      font-size: 120rpx;
      margin-bottom: 24rpx;
      opacity: 0.5;
    }

    .empty-title {
      font-size: $font-size-lg;
      font-weight: $font-weight-bold;
      color: $text-primary;
      margin-bottom: 12rpx;
    }

    .empty-desc {
      font-size: $font-size-sm;
      color: $text-secondary;
    }
  }
}

// Feed 底部安全距离
.feed-safe-area {
  height: 80rpx;
}

@keyframes heartBeat {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.3); }
}

// 回复弹窗样式
.reply-modal {
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
    max-width: 650rpx;
    max-height: 80vh;
    background: white;
    border-radius: $radius-xl;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    animation: modalSlideUp 0.3s ease-out;
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

      &:active {
        background: $bg-hover;
        transform: scale(0.9);
      }

      .close-icon {
        font-size: 48rpx;
        color: $text-tertiary;
        line-height: 1;
      }
    }
  }

  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 24rpx;
    max-height: 50vh;

    .order-info {
      background: $bg-section;
      border-radius: $radius-lg;
      padding: 16rpx;
      margin-bottom: 20rpx;

      .order-user {
        display: flex;
        align-items: center;
        gap: 12rpx;

        .user-avatar {
          width: 48rpx;
          height: 48rpx;
          border-radius: 50%;

          &.placeholder {
            background: $gradient-primary;
            @include flex-center;

            .avatar-text {
              font-size: $font-size-sm;
              font-weight: $font-weight-bold;
              color: white;
            }
          }
        }

        .user-name {
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
        }

        .order-note {
          flex: 1;
          font-size: $font-size-sm;
          color: $text-secondary;
          @include text-ellipsis(1);
        }
      }
    }

    .replies-list {
      .reply-item {
        display: flex;
        gap: 12rpx;
        padding: 16rpx 0;
        border-bottom: 1rpx solid $border-light;

        &:last-child {
          border-bottom: none;
        }

        .reply-avatar {
          width: 56rpx;
          height: 56rpx;
          border-radius: 50%;
          flex-shrink: 0;

          &.placeholder {
            background: $gradient-primary;
            @include flex-center;

            .avatar-text {
              font-size: $font-size-sm;
              font-weight: $font-weight-bold;
              color: white;
            }
          }
        }

        .reply-content {
          flex: 1;

          .reply-header {
            display: flex;
            align-items: center;
            gap: 12rpx;
            margin-bottom: 8rpx;

            .reply-name {
              font-size: $font-size-base;
              font-weight: $font-weight-bold;
              color: $text-primary;
            }

            .reply-time {
              font-size: $font-size-xs;
              color: $text-tertiary;
            }
          }

          .reply-text {
            font-size: $font-size-base;
            color: $text-primary;
            line-height: $line-height-base;
          }
        }
      }
    }

    .replies-empty,
    .replies-loading {
      @include flex-center;
      padding: 60rpx 20rpx;

      .empty-text,
      .loading-text {
        font-size: $font-size-sm;
        color: $text-tertiary;
      }
    }
  }

  .reply-input-area {
    display: flex;
    gap: 12rpx;
    padding: 16rpx 24rpx;
    border-top: 1rpx solid $border-light;
    background: $bg-section;

    .reply-input {
      flex: 1;
      height: 72rpx;
      background: white;
      border: 1rpx solid $border-light;
      border-radius: $radius-button;
      padding: 0 20rpx;
      font-size: $font-size-base;

      &:focus {
        border-color: $primary;
      }
    }

    .send-btn {
      width: 120rpx;
      height: 72rpx;
      background: $gradient-primary;
      color: white;
      border: none;
      border-radius: $radius-button;
      font-size: $font-size-base;
      font-weight: $font-weight-bold;
      @include flex-center;

      &:disabled {
        opacity: 0.5;
      }

      &:active:not(:disabled) {
        transform: scale(0.95);
      }
    }
  }
}
</style>
