<template>
  <view class="merchant-page">
    <!-- 加载状态 -->
    <view class="page-loading" v-if="isPageLoading">
      <view class="loading-content">
        <text class="loading-icon">🍳</text>
        <text class="loading-text">正在准备美味...</text>
      </view>
    </view>

    <!-- 无家庭状态 -->
    <view class="no-family-welcome" v-else-if="!hasFamily">
      <view class="welcome-header">
        <view class="welcome-bg"></view>
        <view class="welcome-content">
          <text class="welcome-icon">🏠</text>
          <text class="welcome-title">欢迎来到 Love Order</text>
          <text class="welcome-subtitle">温馨家庭，美味共享</text>
          <text class="welcome-desc">创建或加入家庭，开启美好的用餐时光</text>

          <view class="welcome-actions">
            <button class="welcome-btn primary" @click="goToFamily">
              <text class="btn-icon">✨</text>
              <text class="btn-text">开始使用</text>
            </button>
          </view>
        </view>
      </view>

      <view class="welcome-features">
        <view class="feature-card">
          <text class="feature-icon">👨‍👩‍👧‍👦</text>
          <text class="feature-title">家庭管理</text>
          <text class="feature-desc">邀请家人加入，共同管理家庭菜谱</text>
        </view>
        <view class="feature-card">
          <text class="feature-icon">📖</text>
          <text class="feature-title">菜谱分享</text>
          <text class="feature-desc">记录美味菜谱，与家人分享烹饪心得</text>
        </view>
        <view class="feature-card">
          <text class="feature-icon">🛒</text>
          <text class="feature-title">便捷点餐</text>
          <text class="feature-desc">家人可以轻松点餐，享受贴心服务</text>
        </view>
      </view>
    </view>

    <!-- 有家庭状态 - 美团风格点餐页面 -->
    <view class="meituan-style-page" v-else>
      <!-- 家庭信息头部 - 统一背景设计 -->
      <view class="family-header">
        <!-- 统一背景层 -->
        <view class="header-background">
          <image
            class="bg-illustration"
            :src="merchantInfo.backgroundImage || defaultBackgroundImage"
            mode="aspectFill"
          />
          <view class="bg-overlay"></view>
          <!-- 可爱装饰元素 -->
          <view class="decoration-elements">
            <text class="deco-item carrot">🥕</text>
            <text class="deco-item pot">🍲</text>
            <text class="deco-item chef">👨‍🍳</text>
            <text class="deco-item veggie">🥬</text>
            <text class="deco-item spoon">🥄</text>
          </view>
        </view>

        <!-- 内容层 -->
        <view class="header-content">
          <!-- 家庭信息区域 -->
          <view class="family-info">
            <view class="family-avatar-container">
              <view class="family-avatar">
                <text class="avatar-text">{{ merchantInfo.name.charAt(0) }}</text>
              </view>
              <view class="avatar-badge">
                <text class="badge-text">家</text>
              </view>
            </view>

            <view class="family-details">
              <view class="family-name-row">
                <text class="family-name">{{ merchantInfo.name }}</text>
                <text class="family-emoji">🏠</text>
              </view>
              <view class="family-stats">
                <text class="stat-text">{{ recipes.length }}道菜品</text>
                <text class="stat-divider">·</text>
                <text class="stat-text">{{ categories.length }}个分类</text>
              </view>
            </view>

            <!-- 设置和二维码按钮 -->
            <view class="header-actions">
              <view class="action-btn qr-btn" @click="showQRCode">
                <text class="action-icon">📱</text>
              </view>
              <view class="action-btn settings-btn" @click="showBackgroundSettings">
                <text class="action-icon">⚙️</text>
              </view>
            </view>
          </view>

          <!-- 滚动公告模块 -->
          <view class="announcement-module">
            <view class="announcement-icon">
              <text class="icon">📢</text>
            </view>
            <view class="announcement-content">
              <scroll-view
                class="announcement-scroll"
                scroll-x
                :show-scrollbar="false"
                :scroll-left="scrollLeft"
              >
                <view class="announcement-text">
                  <text class="announcement-item">{{ familyAnnouncement }}</text>
                </view>
              </scroll-view>
            </view>
            <view class="announcement-action" @click="editAnnouncement">
              <text class="edit-icon">✏️</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 背景设置弹窗 -->
      <view class="background-modal" v-if="showBgModal" @click="closeBgModal">
        <view class="modal-content" @click.stop>
          <view class="modal-header">
            <text class="modal-title">选择背景图片</text>
            <text class="modal-close" @click="closeBgModal">✕</text>
          </view>
          <view class="bg-options">
            <view
              class="bg-option"
              :class="{ active: selectedBg === bg.url }"
              v-for="bg in backgroundOptions"
              :key="bg.id"
              @click="selectBackground(bg.url)"
            >
              <image class="option-image" :src="bg.url" mode="aspectFill" />
              <text class="option-name">{{ bg.name }}</text>
            </view>
          </view>
          <view class="modal-actions">
            <button class="cancel-btn" @click="closeBgModal">取消</button>
            <button class="confirm-btn" @click="confirmBackground">确定</button>
          </view>
        </view>
      </view>

      <!-- 公告编辑弹窗 -->
      <view class="announcement-modal" v-if="showAnnouncementModal" @click="closeAnnouncementModal">
        <view class="modal-content" @click.stop>
          <view class="modal-header">
            <text class="modal-title">编辑家庭公告</text>
            <text class="modal-close" @click="closeAnnouncementModal">✕</text>
          </view>
          <view class="modal-body">
            <textarea
              class="announcement-input"
              v-model="tempAnnouncement"
              placeholder="输入温馨的家庭公告..."
              maxlength="200"
              :show-confirm-bar="false"
            />
            <view class="input-tip">
              <text class="tip-text">{{ tempAnnouncement.length }}/200</text>
            </view>
          </view>
          <view class="modal-actions">
            <button class="cancel-btn" @click="closeAnnouncementModal">取消</button>
            <button class="confirm-btn" @click="confirmAnnouncement">确定</button>
          </view>
        </view>
      </view>

      <!-- 主要内容区域 -->
      <view class="main-content">
        <!-- 左侧分类导航 -->
        <view class="category-sidebar">
          <scroll-view class="category-list" scroll-y>
            <view
              class="category-item"
              :class="{ active: activeCategory === category.id }"
              v-for="category in categories"
              :key="category.id"
              @click="selectCategory(category.id)"
            >
              <text class="category-name">{{ category.name }}</text>
              <text class="category-count" v-if="getCategoryRecipeCount(category.id) > 0">
                {{ getCategoryRecipeCount(category.id) }}
              </text>
            </view>
          </scroll-view>
        </view>

        <!-- 右侧菜品列表 -->
        <view class="recipe-content">
          <scroll-view class="recipe-scroll" scroll-y :scroll-into-view="scrollIntoView">
            <!-- 空状态 -->
            <view class="empty-recipes" v-if="filteredRecipes.length === 0">
              <text class="empty-icon">🍽️</text>
              <text class="empty-text">该分类暂无菜品</text>
              <text class="empty-desc">快来添加美味菜谱吧</text>
            </view>

            <!-- 菜品列表 -->
            <view class="recipe-section" v-else>
              <view
                class="recipe-item"
                v-for="recipe in filteredRecipes"
                :key="recipe.id"
                @click="viewRecipeDetail(recipe)"
              >
                <view class="recipe-image-container">
                  <image
                    class="recipe-image"
                    :src="recipe.image || defaultRecipeImage"
                    mode="aspectFill"
                  />
                </view>
                <view class="recipe-info">
                  <text class="recipe-name">{{ recipe.name }}</text>
                  <text class="recipe-desc">{{ recipe.description || '暂无描述' }}</text>
                  <view class="recipe-meta">
                    <text class="recipe-time">{{ recipe.cooking_time }}分钟</text>
                    <text class="recipe-difficulty">{{ getDifficultyText(recipe.difficulty) }}</text>
                  </view>
                  <view class="recipe-actions">
                    <button class="add-to-cart-btn" @click.stop="addToCart(recipe)">
                      <text class="btn-text">加入订单</text>
                    </button>
                  </view>
                </view>
              </view>
            </view>
          </scroll-view>
        </view>
      </view>

      <!-- 底部购物车 -->
      <view class="cart-bar" v-if="cartItems.length > 0">
        <view class="cart-info" @click="toggleCartDetail">
          <view class="cart-icon-container">
            <text class="cart-icon">🛒</text>
            <view class="cart-badge" v-if="cartItemCount > 0">
              <text class="badge-text">{{ cartItemCount }}</text>
            </view>
          </view>
          <view class="cart-text">
            <text class="cart-count">已选{{ cartItemCount }}道菜</text>
            <text class="cart-total">预计{{ totalCookingTime }}分钟</text>
          </view>
        </view>
        <button class="checkout-btn" @click="goToOrders">
          <text class="checkout-text">查看订单</text>
        </button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RecipeService, CategoryService, type Recipe, type Category } from '@/api/recipe'
import { processRecipeList, getRecipeDisplayInfo } from '@/utils/recipe'
import { FamilyService } from '@/api/family'

// 页面状态
const isPageLoading = ref(true)
const hasFamily = ref(false)

// 商家信息
const merchantInfo = ref({
  name: '温馨家庭厨房',
  description: '用心烹饪，温暖每一餐',
  rating: 4.8,
  reviewCount: 128,
  monthlySales: 128,
  minOrder: 0,
  deliveryFee: 0,
  deliveryTime: 30,
  logo: '',
  backgroundImage: ''
})

// 菜谱和分类数据
const recipes = ref<Recipe[]>([])
const categories = ref<Category[]>([])
const loading = ref(false)

// 美团风格页面状态
const activeCategory = ref<number | null>(null)
const scrollIntoView = ref('')
const cartItems = ref<any[]>([])
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 背景设置相关
const showBgModal = ref(false)
const selectedBg = ref('')

// 公告模块相关
const familyAnnouncement = ref('🏠 欢迎来到温馨家庭厨房！今日推荐：红烧肉、宫保鸡丁，让我们一起享受美味时光~ ❤️')
const scrollLeft = ref(0)
const showAnnouncementModal = ref(false)
const tempAnnouncement = ref('')

// 可爱插画风格的默认背景
const defaultBackgroundImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjI0MCIgdmlld0JveD0iMCAwIDc1MCAyNDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojRkZGM0UwO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNGRkU0QjU7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIyNDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPCEtLSBUYWJsZSAtLT4KPHJlY3QgeD0iMjAwIiB5PSIxNDAiIHdpZHRoPSIzNTAiIGhlaWdodD0iODAiIHJ4PSI4IiBmaWxsPSIjRkY4QTY1IiBvcGFjaXR5PSIwLjgiLz4KPCEtLSBQb3QgLS0+CjxjaXJjbGUgY3g9IjM3NSIgY3k9IjEyMCIgcj0iNjAiIGZpbGw9IiM2NjY2NjYiLz4KPGNpcmNsZSBjeD0iMzc1IiBjeT0iMTEwIiByPSI1NSIgZmlsbD0iI0ZGRkZGRiIvPgo8IS0tIEZvb2QgaW4gcG90IC0tPgo8Y2lyY2xlIGN4PSIzNjAiIGN5PSIxMDAiIHI9IjgiIGZpbGw9IiNGRjY5NDciLz4KPGNpcmNsZSBjeD0iMzkwIiBjeT0iMTA1IiByPSI2IiBmaWxsPSIjNENBRjUwIi8+CjxjaXJjbGUgY3g9IjM3NSIgY3k9IjEyMCIgcj0iNSIgZmlsbD0iI0ZGQzEwNyIvPgo8IS0tIENhcnJvdCAtLT4KPHBhdGggZD0iTTEwMCAxNjBMMTIwIDEyMEwxNDAgMTYwWiIgZmlsbD0iI0ZGNjk0NyIvPgo8cGF0aCBkPSJNMTEwIDEyMEwxMTUgMTAwTDEyNSAxMjBaIiBmaWxsPSIjNENBRjUwIi8+CjwhLS0gTGVhZnkgZ3JlZW4gLS0+CjxwYXRoIGQ9Ik02MDAgMTAwUTYyMCA4MCA2NDAgMTAwUTYyMCAxMjAgNjAwIDEwMFoiIGZpbGw9IiM0Q0FGNTQiLz4KPCEtLSBDaGVmIGhhdCAtLT4KPHJlY3QgeD0iNTAwIiB5PSI2MCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjQwIiByeD0iMjAiIGZpbGw9IiNGRkZGRkYiLz4KPHJlY3QgeD0iNTEwIiB5PSI0MCIgd2lkdGg9IjYwIiBoZWlnaHQ9IjMwIiByeD0iMTUiIGZpbGw9IiNGRkZGRkYiLz4KPC9zdmc+')

const backgroundOptions = ref([
  {
    id: 1,
    name: '温馨橙色',
    url: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojRkY4QTY1O3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNGRjcwNDM7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMTUwIiBjeT0iMTAwIiByPSI0MCIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjEpIi8+CjxjaXJjbGUgY3g9IjYwMCIgY3k9IjIwMCIgcj0iNjAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4wOCkiLz4KPGNpcmNsZSBjeD0iNDAwIiBjeT0iNTAiIHI9IjMwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTIpIi8+Cjx0ZXh0IHg9IjM3NSIgeT0iMTYwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4zKSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+NsO+4jzwvdGV4dD4KPC9zdmc+'
  },
  {
    id: 2,
    name: '清新绿色',
    url: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojNjZCQjZBO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM0Q0FGNTQ7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMjAwIiBjeT0iODAiIHI9IjM1IiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTUpIi8+CjxjaXJjbGUgY3g9IjU1MCIgY3k9IjE4MCIgcj0iNTAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4xKSIvPgo8Y2lyY2xlIGN4PSIzNTAiIGN5PSI2MCIgcj0iMjUiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4yKSIvPgo8dGV4dCB4PSIzNzUiIHk9IjE2MCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjQwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuNCkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfjbXwn42FPC90ZXh0Pgo8L3N2Zz4='
  },
  {
    id: 3,
    name: '浪漫粉色',
    url: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojRkY4QTgwO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNGRjUwNzI7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMTgwIiBjeT0iMTIwIiByPSI0NSIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjEyKSIvPgo8Y2lyY2xlIGN4PSI1ODAiIGN5PSIxNjAiIHI9IjU1IiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMDgpIi8+CjxjaXJjbGUgY3g9IjQyMCIgY3k9IjcwIiByPSIzNSIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjE1KSIvPgo8dGV4dCB4PSIzNzUiIHk9IjE2MCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjQwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMzUpIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj7wn5GOXG4g8J+SljwvdGV4dD4KPC9zdmc+'
  },
  {
    id: 4,
    name: '优雅紫色',
    url: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojOUM4OEZGO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM3QzRERkY7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMTYwIiBjeT0iOTAiIHI9IjQwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTQpIi8+CjxjaXJjbGUgY3g9IjU2MCIgY3k9IjE5MCIgcj0iNjAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4wOSkiLz4KPGNpcmNsZSBjeD0iMzgwIiBjeT0iNDAiIHI9IjMwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTgpIi8+Cjx0ZXh0IHg9IjM3NSIgeT0iMTYwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4zKSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+MuO+4jzwvdGV4dD4KPC9zdmc+'
  }
])

// 前往家庭管理
const goToFamily = () => {
  uni.navigateTo({
    url: '/pages/family/index'
  })
}

// 前往菜谱页面
const goToRecipes = () => {
  uni.navigateTo({
    url: '/pages/recipes/index'
  })
}

// 加载分类数据
const loadCategories = async () => {
  try {
    console.log('开始加载分类...')
    console.log('API地址:', 'http://192.168.4.15:8081/api/v1/dev/categories')
    const result = await CategoryService.getCategoryList()
    console.log('分类加载成功:', result)
    console.log('分类数量:', result?.length || 0)
    categories.value = result || []
  } catch (error: any) {
    console.error('加载分类失败:', error)
    console.error('错误详情:', error.message, error.statusCode)
    categories.value = []
  }
}

// 加载菜谱数据
const loadRecipes = async () => {
  try {
    console.log('开始加载菜谱...')
    console.log('API地址:', 'http://192.168.4.15:8081/api/v1/dev/recipes')
    const result = await RecipeService.getRecipeList({
      page: 1,
      page_size: 100
    })
    console.log('菜谱加载成功:', result)
    console.log('菜谱数量:', result.recipes?.length || 0)
    recipes.value = result.recipes || []
  } catch (error: any) {
    console.error('加载菜谱失败:', error)
    console.error('错误详情:', error.message, error.statusCode)

    // 如果是权限问题或其他错误，都设置空数组，不显示错误提示
    if (error.statusCode === 403 || error.statusCode === 400) {
      console.log('用户没有菜谱访问权限或请求参数错误，设置空菜谱列表')
      recipes.value = []
    } else {
      console.log('其他错误，设置空菜谱列表')
      recipes.value = []
    }
  }
}

// 初始化数据
const initData = async () => {
  loading.value = true
  try {
    console.log('开始并行加载分类和菜谱...')

    const [categoriesResult, recipesResult] = await Promise.allSettled([
      loadCategories(),
      loadRecipes()
    ])

    if (categoriesResult.status === 'rejected') {
      console.error('加载分类失败:', categoriesResult.reason)
    }

    if (recipesResult.status === 'rejected') {
      console.error('加载菜谱失败:', recipesResult.reason)
    }

    console.log('数据加载完成')
  } catch (error) {
    console.error('初始化数据失败:', error)
  } finally {
    loading.value = false
  }
}

// 检查家庭状态
const checkFamilyStatus = async () => {
  try {
    console.log('开始检查家庭状态...')
    hasFamily.value = FamilyService.hasFamily()
    console.log('家庭状态检查结果:', hasFamily.value)

    const userInfo = uni.getStorageSync('user_info')
    console.log('用户信息:', userInfo)

    if (userInfo && userInfo.family_id) {
      console.log('用户有家庭ID:', userInfo.family_id)
      hasFamily.value = true
    } else {
      console.log('用户没有家庭ID')
      hasFamily.value = false
    }
  } catch (error) {
    console.error('检查家庭状态失败:', error)
    hasFamily.value = false
  }
}

// 计算属性
const filteredRecipes = computed(() => {
  if (!activeCategory.value) {
    return recipes.value
  }
  return recipes.value.filter(recipe => recipe.category_id === activeCategory.value)
})

const cartItemCount = computed(() => {
  return cartItems.value.reduce((total, item) => total + item.quantity, 0)
})

const totalCookingTime = computed(() => {
  return cartItems.value.reduce((total, item) => total + (item.cooking_time * item.quantity), 0)
})

// 美团风格页面方法
const selectCategory = (categoryId: number) => {
  activeCategory.value = categoryId
  scrollIntoView.value = `category-${categoryId}`
}

const getCategoryRecipeCount = (categoryId: number) => {
  return recipes.value.filter(recipe => recipe.category_id === categoryId).length
}

const getDifficultyText = (difficulty: number) => {
  const difficultyMap: { [key: number]: string } = {
    1: '简单',
    2: '中等',
    3: '困难'
  }
  return difficultyMap[difficulty] || '未知'
}

const viewRecipeDetail = (recipe: any) => {
  uni.navigateTo({
    url: `/pages/recipes/detail?id=${recipe.id}`
  })
}

const addToCart = (recipe: any) => {
  const existingItem = cartItems.value.find(item => item.id === recipe.id)
  if (existingItem) {
    existingItem.quantity += 1
  } else {
    cartItems.value.push({
      ...recipe,
      quantity: 1
    })
  }

  uni.showToast({
    title: '已加入订单',
    icon: 'success',
    duration: 1000
  })
}

const toggleCartDetail = () => {
  // TODO: 显示购物车详情弹窗
  console.log('显示购物车详情')
}

const goToOrders = () => {
  uni.navigateTo({
    url: '/pages/orders/index'
  })
}

// 背景设置相关方法
const showBackgroundSettings = () => {
  selectedBg.value = merchantInfo.value.backgroundImage || defaultBackgroundImage.value
  showBgModal.value = true
}

const closeBgModal = () => {
  showBgModal.value = false
}

const selectBackground = (bgUrl: string) => {
  selectedBg.value = bgUrl
}

const confirmBackground = () => {
  merchantInfo.value.backgroundImage = selectedBg.value
  // 这里可以调用API保存到后端
  uni.setStorageSync('family_background', selectedBg.value)
  showBgModal.value = false

  uni.showToast({
    title: '背景已更新',
    icon: 'success',
    duration: 1500
  })
}

// 新增的方法
const showQRCode = () => {
  uni.showToast({
    title: '二维码功能开发中',
    icon: 'none'
  })
}

const showAddMenu = () => {
  uni.navigateTo({
    url: '/pages/recipes/add'
  })
}

const showSearch = () => {
  uni.showToast({
    title: '搜索功能开发中',
    icon: 'none'
  })
}

// 公告相关方法
const editAnnouncement = () => {
  tempAnnouncement.value = familyAnnouncement.value
  showAnnouncementModal.value = true
}

const closeAnnouncementModal = () => {
  showAnnouncementModal.value = false
}

const confirmAnnouncement = () => {
  familyAnnouncement.value = tempAnnouncement.value
  // 保存到本地存储
  uni.setStorageSync('family_announcement', tempAnnouncement.value)
  showAnnouncementModal.value = false

  uni.showToast({
    title: '公告已更新',
    icon: 'success',
    duration: 1500
  })
}

// 启动公告滚动动画
const startAnnouncementScroll = () => {
  setInterval(() => {
    scrollLeft.value += 1
    if (scrollLeft.value > 1000) {
      scrollLeft.value = 0
    }
  }, 50)
}

// 页面加载时的初始化
onMounted(async () => {
  try {
    console.log('首页开始初始化...')
    isPageLoading.value = true

    console.log('检查家庭状态...')
    await checkFamilyStatus()
    console.log('家庭状态检查完成:', hasFamily.value)

    if (hasFamily.value) {
      console.log('开始加载数据...')
      await initData()
      console.log('数据加载完成')

      // 设置默认选中第一个分类
      if (categories.value.length > 0) {
        activeCategory.value = categories.value[0].id
      }

      // 加载保存的背景图片
      const savedBackground = uni.getStorageSync('family_background')
      if (savedBackground) {
        merchantInfo.value.backgroundImage = savedBackground
      }

      // 加载保存的公告
      const savedAnnouncement = uni.getStorageSync('family_announcement')
      if (savedAnnouncement) {
        familyAnnouncement.value = savedAnnouncement
      }

      // 启动公告滚动动画
      startAnnouncementScroll()
    } else {
      console.log('用户没有家庭，跳过数据加载')
    }
  } catch (error) {
    console.error('页面初始化失败:', error)
    uni.showToast({
      title: '页面加载失败',
      icon: 'error'
    })
  } finally {
    console.log('设置页面加载完成')
    isPageLoading.value = false
  }
})
</script>

<style lang="scss" scoped>
.merchant-page {
  min-height: 100vh;
  background-color: #FAFAFA;
}

// 页面加载状态
.page-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);

  .loading-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    color: white;

    .loading-icon {
      font-size: 80rpx;
      margin-bottom: 24rpx;
      animation: bounce 1.5s ease-in-out infinite;
    }

    .loading-text {
      font-size: 28rpx;
      opacity: 0.9;
    }
  }
}

// 无家庭欢迎页面
.no-family-welcome {
  min-height: 100vh;
  background-color: #FAFAFA;

  .welcome-header {
    position: relative;
    height: 500rpx;
    overflow: hidden;

    .welcome-bg {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);

      &::before {
        content: '';
        position: absolute;
        top: -50%;
        right: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
        animation: float 8s ease-in-out infinite;
      }
    }

    .welcome-content {
      position: relative;
      z-index: 2;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      padding: 40rpx;
      text-align: center;
      color: white;

      .welcome-icon {
        font-size: 120rpx;
        margin-bottom: 32rpx;
        animation: pulse 2s ease-in-out infinite;
      }

      .welcome-title {
        font-size: 40rpx;
        font-weight: bold;
        margin-bottom: 12rpx;
      }

      .welcome-subtitle {
        font-size: 28rpx;
        opacity: 0.9;
        margin-bottom: 24rpx;
      }

      .welcome-desc {
        font-size: 26rpx;
        opacity: 0.8;
        line-height: 1.6;
        margin-bottom: 48rpx;
        max-width: 500rpx;
      }

      .welcome-actions {
        .welcome-btn {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 12rpx;
          padding: 20rpx 40rpx;
          background-color: rgba(255, 255, 255, 0.2);
          border: 2rpx solid rgba(255, 255, 255, 0.3);
          border-radius: 50rpx;
          color: white;
          font-weight: bold;
          backdrop-filter: blur(10rpx);
          transition: all 0.3s ease;

          &:active {
            transform: translateY(2rpx);
            background-color: rgba(255, 255, 255, 0.3);
          }

          .btn-icon {
            font-size: 24rpx;
          }

          .btn-text {
            font-size: 28rpx;
          }
        }
      }
    }
  }

  .welcome-features {
    padding: 48rpx 32rpx;
    display: flex;
    flex-direction: column;
    gap: 24rpx;

    .feature-card {
      background-color: white;
      padding: 32rpx;
      border-radius: 16rpx;
      box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
      display: flex;
      align-items: center;
      gap: 24rpx;

      .feature-icon {
        font-size: 48rpx;
        width: 80rpx;
        text-align: center;
      }

      .feature-title {
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
        margin-bottom: 8rpx;
      }

      .feature-desc {
        font-size: 26rpx;
        color: #666;
        line-height: 1.5;
        flex: 1;
      }
    }
  }
}

// 有家庭状态页面
.family-home {
  padding: 24rpx;

  .home-header {
    background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
    color: white;
    padding: 48rpx 32rpx;
    border-radius: 16rpx;
    text-align: center;
    margin-bottom: 24rpx;

    .home-title {
      font-size: 36rpx;
      font-weight: bold;
      margin-bottom: 12rpx;
    }

    .home-desc {
      font-size: 26rpx;
      opacity: 0.9;
    }
  }

  .home-stats {
    display: flex;
    background-color: white;
    border-radius: 16rpx;
    padding: 32rpx;
    margin-bottom: 24rpx;
    box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);

    .stat-item {
      flex: 1;
      text-align: center;

      .stat-number {
        display: block;
        font-size: 36rpx;
        font-weight: bold;
        color: #FF8A65;
        margin-bottom: 8rpx;
      }

      .stat-label {
        font-size: 24rpx;
        color: #666;
      }
    }
  }

  .quick-actions {
    display: flex;
    gap: 16rpx;
    margin-bottom: 32rpx;

    .action-btn {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 32rpx 16rpx;
      background-color: white;
      border-radius: 16rpx;
      box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
      border: none;
      transition: all 0.3s ease;

      &:active {
        transform: scale(0.95);
      }

      .btn-icon {
        font-size: 48rpx;
        margin-bottom: 12rpx;
      }

      .btn-text {
        font-size: 26rpx;
        color: #333;
        font-weight: bold;
      }
    }
  }

  .recent-recipes {
    background-color: white;
    border-radius: 16rpx;
    padding: 32rpx;
    box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);

    .section-title {
      font-size: 32rpx;
      font-weight: bold;
      color: #333;
      margin-bottom: 24rpx;
    }

    .recipe-list {
      .recipe-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 16rpx 0;
        border-bottom: 1rpx solid #F0F0F0;

        &:last-child {
          border-bottom: none;
        }

        .recipe-name {
          font-size: 28rpx;
          color: #333;
          font-weight: bold;
        }

        .recipe-category {
          font-size: 24rpx;
          color: #FF8A65;
          background-color: #FFF3E0;
          padding: 4rpx 12rpx;
          border-radius: 12rpx;
        }
      }
    }
  }
}

@keyframes bounce {
  0%, 20%, 50%, 80%, 100% { transform: translateY(0); }
  40% { transform: translateY(-20rpx); }
  60% { transform: translateY(-10rpx); }
}

@keyframes float {
  0%, 100% { transform: translateY(0px) rotate(0deg); }
  50% { transform: translateY(-30px) rotate(180deg); }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

.merchant-page {
  min-height: 100vh;
  background-color: #FAFAFA;
}

// 页面加载状态
.page-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);

  .loading-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    color: white;

    .loading-icon {
      font-size: 80rpx;
      margin-bottom: 24rpx;
      animation: bounce 1.5s ease-in-out infinite;
    }

    .loading-text {
      font-size: 28rpx;
      opacity: 0.9;
    }
  }
}

// 无家庭欢迎页面
.no-family-welcome {
  min-height: 100vh;
  background-color: #FAFAFA;

  .welcome-header {
    position: relative;
    height: 500rpx;
    overflow: hidden;

    .welcome-bg {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);

      &::before {
        content: '';
        position: absolute;
        top: -50%;
        right: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
        animation: float 8s ease-in-out infinite;
      }
    }

    .welcome-content {
      position: relative;
      z-index: 2;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      padding: 40rpx;
      text-align: center;
      color: white;

      .welcome-icon {
        font-size: 120rpx;
        margin-bottom: 32rpx;
        animation: pulse 2s ease-in-out infinite;
      }

      .welcome-title {
        font-size: 40rpx;
        font-weight: bold;
        margin-bottom: 12rpx;
      }

      .welcome-subtitle {
        font-size: 28rpx;
        opacity: 0.9;
        margin-bottom: 24rpx;
      }

      .welcome-desc {
        font-size: 26rpx;
        opacity: 0.8;
        line-height: 1.6;
        margin-bottom: 48rpx;
        max-width: 500rpx;
      }

      .welcome-actions {
        .welcome-btn {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 12rpx;
          padding: 20rpx 40rpx;
          background-color: rgba(255, 255, 255, 0.2);
          border: 2rpx solid rgba(255, 255, 255, 0.3);
          border-radius: 50rpx;
          color: white;
          font-weight: bold;
          backdrop-filter: blur(10rpx);
          transition: all 0.3s ease;

          &:active {
            transform: translateY(2rpx);
            background-color: rgba(255, 255, 255, 0.3);
          }

          .btn-icon {
            font-size: 24rpx;
          }

          .btn-text {
            font-size: 28rpx;
          }
        }
      }
    }
  }

  .welcome-features {
    padding: 48rpx 32rpx;
    display: flex;
    flex-direction: column;
    gap: 24rpx;

    .feature-card {
      background-color: white;
      padding: 32rpx;
      border-radius: 16rpx;
      box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
      display: flex;
      align-items: center;
      gap: 24rpx;

      .feature-icon {
        font-size: 48rpx;
        width: 80rpx;
        text-align: center;
      }

      .feature-title {
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
        margin-bottom: 8rpx;
      }

      .feature-desc {
        font-size: 26rpx;
        color: #666;
        line-height: 1.5;
        flex: 1;
      }
    }
  }
}

@keyframes bounce {
  0%, 20%, 50%, 80%, 100% { transform: translateY(0); }
  40% { transform: translateY(-20rpx); }
  60% { transform: translateY(-10rpx); }
}

@keyframes float {
  0%, 100% { transform: translateY(0px) rotate(0deg); }
  50% { transform: translateY(-30px) rotate(180deg); }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

// 美团风格页面样式
.meituan-style-page {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  background-color: #FAFAFA;
}

// 家庭信息头部 - 统一背景设计
.family-header {
  position: relative;
  overflow: hidden;

  // 统一背景层
  .header-background {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 1;

    .bg-illustration {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    .bg-overlay {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: linear-gradient(135deg, rgba(255, 138, 101, 0.8) 0%, rgba(255, 112, 67, 0.9) 100%);
      z-index: 2;
    }

    // 可爱装饰元素
    .decoration-elements {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      pointer-events: none;
      z-index: 3;

      .deco-item {
        position: absolute;
        font-size: 40rpx;
        opacity: 0.6;
        animation: float 3s ease-in-out infinite;

        &.carrot {
          top: 40rpx;
          left: 60rpx;
          animation-delay: 0s;
        }

        &.pot {
          top: 30rpx;
          right: 100rpx;
          animation-delay: 0.5s;
        }

        &.chef {
          top: 15rpx;
          left: 50%;
          transform: translateX(-50%);
          animation-delay: 1s;
        }

        &.veggie {
          bottom: 80rpx;
          left: 50rpx;
          animation-delay: 1.5s;
        }

        &.spoon {
          bottom: 60rpx;
          right: 70rpx;
          animation-delay: 2s;
        }
      }
    }
  }

  // 内容层
  .header-content {
    position: relative;
    z-index: 4;
    padding: 40rpx 24rpx 24rpx;

    // 家庭信息区域
    .family-info {
      display: flex;
      align-items: center;
      margin-bottom: 32rpx;

      .family-avatar-container {
        position: relative;
        margin-right: 24rpx;

        .family-avatar {
          width: 88rpx;
          height: 88rpx;
          border-radius: 44rpx;
          background: rgba(255, 255, 255, 0.95);
          backdrop-filter: blur(10rpx);
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 8rpx 24rpx rgba(0, 0, 0, 0.15);
          border: 3rpx solid rgba(255, 255, 255, 0.5);

          .avatar-text {
            font-size: 36rpx;
            font-weight: bold;
            color: #FF8A65;
          }
        }

        .avatar-badge {
          position: absolute;
          bottom: -4rpx;
          right: -4rpx;
          width: 32rpx;
          height: 32rpx;
          border-radius: 16rpx;
          background: #4CAF50;
          display: flex;
          align-items: center;
          justify-content: center;
          border: 3rpx solid white;

          .badge-text {
            font-size: 18rpx;
            color: white;
            font-weight: bold;
          }
        }
      }

      .family-details {
        flex: 1;

        .family-name-row {
          display: flex;
          align-items: center;
          gap: 12rpx;
          margin-bottom: 12rpx;

          .family-name {
            font-size: 36rpx;
            font-weight: bold;
            color: white;
            text-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.3);
          }

          .family-emoji {
            font-size: 28rpx;
          }
        }

        .family-stats {
          display: flex;
          align-items: center;
          gap: 8rpx;

          .stat-text {
            font-size: 24rpx;
            color: rgba(255, 255, 255, 0.9);
            text-shadow: 0 1rpx 4rpx rgba(0, 0, 0, 0.2);
          }

          .stat-divider {
            font-size: 20rpx;
            color: rgba(255, 255, 255, 0.7);
          }
        }
      }

      .header-actions {
        display: flex;
        gap: 12rpx;

        .action-btn {
          width: 56rpx;
          height: 56rpx;
          border-radius: 28rpx;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: all 0.2s;
          backdrop-filter: blur(10rpx);
          border: 1rpx solid rgba(255, 255, 255, 0.3);

          &:active {
            transform: scale(0.9);
          }

          .action-icon {
            font-size: 24rpx;
            color: white;
          }

          &.qr-btn {
            background: rgba(33, 150, 243, 0.2);
          }

          &.settings-btn {
            background: rgba(255, 255, 255, 0.2);
          }
        }
      }
    }

    // 滚动公告模块
    .announcement-module {
      display: flex;
      align-items: center;
      background: rgba(255, 255, 255, 0.15);
      backdrop-filter: blur(10rpx);
      border-radius: 20rpx;
      padding: 16rpx 20rpx;
      border: 1rpx solid rgba(255, 255, 255, 0.3);
      box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);

      .announcement-icon {
        margin-right: 16rpx;

        .icon {
          font-size: 28rpx;
          color: white;
        }
      }

      .announcement-content {
        flex: 1;
        overflow: hidden;

        .announcement-scroll {
          width: 100%;
          white-space: nowrap;

          .announcement-text {
            display: inline-block;
            animation: scroll-left 20s linear infinite;

            .announcement-item {
              font-size: 24rpx;
              color: white;
              line-height: 1.4;
              text-shadow: 0 1rpx 4rpx rgba(0, 0, 0, 0.2);
            }
          }
        }
      }

      .announcement-action {
        margin-left: 16rpx;
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background: rgba(255, 255, 255, 0.2);
        backdrop-filter: blur(10rpx);
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s;
        border: 1rpx solid rgba(255, 255, 255, 0.3);

        &:active {
          transform: scale(0.9);
          background: rgba(255, 255, 255, 0.3);
        }

        .edit-icon {
          font-size: 20rpx;
          color: white;
        }
      }
    }
  }
}

// 主要内容区域
.main-content {
  display: flex;
  flex: 1;
  height: calc(100vh - 200rpx);
}

// 左侧分类导航
.category-sidebar {
  width: 200rpx;
  background-color: #F8F8F8;
  border-right: 1rpx solid #F0F0F0;

  .category-list {
    height: 100%;

    .category-item {
      position: relative;
      padding: 32rpx 16rpx;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background-color: transparent;
      border-bottom: 1rpx solid #F0F0F0;
      transition: all 0.2s;

      &.active {
        background-color: white;

        &::before {
          content: '';
          position: absolute;
          left: 0;
          top: 50%;
          transform: translateY(-50%);
          width: 6rpx;
          height: 40rpx;
          background-color: #FF8A65;
          border-radius: 0 6rpx 6rpx 0;
        }

        .category-name {
          color: #FF8A65;
          font-weight: bold;
        }
      }

      .category-name {
        font-size: 24rpx;
        color: #333;
        text-align: center;
        line-height: 1.3;
        margin-bottom: 4rpx;
      }

      .category-count {
        font-size: 20rpx;
        color: #999;
        background-color: #F0F0F0;
        padding: 2rpx 8rpx;
        border-radius: 10rpx;
        min-width: 32rpx;
        text-align: center;
      }
    }
  }
}

// 右侧菜品内容
.recipe-content {
  flex: 1;
  background-color: white;

  .recipe-scroll {
    height: 100%;
    padding: 24rpx;
  }

  .empty-recipes {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 120rpx 40rpx;
    text-align: center;

    .empty-icon {
      font-size: 120rpx;
      margin-bottom: 32rpx;
      opacity: 0.6;
    }

    .empty-text {
      font-size: 28rpx;
      color: #333;
      font-weight: bold;
      margin-bottom: 12rpx;
    }

    .empty-desc {
      font-size: 24rpx;
      color: #666;
      line-height: 1.5;
    }
  }

  .recipe-section {
    .recipe-item {
      display: flex;
      padding: 24rpx 0;
      border-bottom: 1rpx solid #F8F8F8;
      transition: all 0.2s;

      &:last-child {
        border-bottom: none;
      }

      .recipe-image-container {
        margin-right: 24rpx;

        .recipe-image {
          width: 120rpx;
          height: 120rpx;
          border-radius: 12rpx;
          background-color: #F5F5F5;
        }
      }

      .recipe-info {
        flex: 1;
        display: flex;
        flex-direction: column;
        justify-content: space-between;

        .recipe-name {
          font-size: 28rpx;
          font-weight: bold;
          color: #333;
          margin-bottom: 8rpx;
          line-height: 1.3;
        }

        .recipe-desc {
          font-size: 24rpx;
          color: #666;
          line-height: 1.4;
          margin-bottom: 12rpx;
          overflow: hidden;
          text-overflow: ellipsis;
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
        }

        .recipe-meta {
          display: flex;
          align-items: center;
          gap: 16rpx;
          margin-bottom: 16rpx;

          .recipe-time, .recipe-difficulty {
            font-size: 20rpx;
            color: #999;
            background-color: #F8F8F8;
            padding: 4rpx 12rpx;
            border-radius: 12rpx;
          }
        }

        .recipe-actions {
          display: flex;
          justify-content: flex-end;

          .add-to-cart-btn {
            background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
            color: white;
            border: none;
            border-radius: 20rpx;
            padding: 12rpx 24rpx;
            font-size: 24rpx;
            font-weight: bold;
            box-shadow: 0 4rpx 12rpx rgba(255, 138, 101, 0.3);
            transition: all 0.2s;

            &:active {
              transform: scale(0.95);
            }

            .btn-text {
              color: white;
            }
          }
        }
      }
    }
  }
}

// 底部购物车
.cart-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: white;
  border-top: 1rpx solid #F0F0F0;
  padding: 24rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-shadow: 0 -4rpx 12rpx rgba(0, 0, 0, 0.1);
  z-index: 100;

  .cart-info {
    display: flex;
    align-items: center;
    gap: 16rpx;

    .cart-icon-container {
      position: relative;
      width: 80rpx;
      height: 80rpx;
      background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
      border-radius: 40rpx;
      display: flex;
      align-items: center;
      justify-content: center;

      .cart-icon {
        font-size: 32rpx;
        color: white;
      }

      .cart-badge {
        position: absolute;
        top: -8rpx;
        right: -8rpx;
        background-color: #FF4444;
        color: white;
        border-radius: 20rpx;
        min-width: 32rpx;
        height: 32rpx;
        display: flex;
        align-items: center;
        justify-content: center;

        .badge-text {
          font-size: 20rpx;
          font-weight: bold;
        }
      }
    }

    .cart-text {
      display: flex;
      flex-direction: column;
      gap: 4rpx;

      .cart-count {
        font-size: 28rpx;
        color: #333;
        font-weight: bold;
      }

      .cart-total {
        font-size: 24rpx;
        color: #666;
      }
    }
  }

  .checkout-btn {
    background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
    color: white;
    border: none;
    border-radius: 24rpx;
    padding: 16rpx 32rpx;
    font-size: 28rpx;
    font-weight: bold;
    box-shadow: 0 4rpx 12rpx rgba(255, 138, 101, 0.3);
    transition: all 0.2s;

    &:active {
      transform: scale(0.95);
    }

    .checkout-text {
      color: white;
    }
  }
}

// 背景设置弹窗
.background-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;

  .modal-content {
    background: white;
    border-radius: 24rpx;
    width: 640rpx;
    max-height: 80vh;
    overflow: hidden;
    box-shadow: 0 16rpx 48rpx rgba(0, 0, 0, 0.2);

    .modal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 32rpx 32rpx 24rpx;
      border-bottom: 1rpx solid #F0F0F0;

      .modal-title {
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
      }

      .modal-close {
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background: #F5F5F5;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24rpx;
        color: #666;
        transition: all 0.2s;

        &:active {
          background: #E0E0E0;
        }
      }
    }

    .bg-options {
      padding: 24rpx;
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24rpx;
      max-height: 400rpx;
      overflow-y: auto;

      .bg-option {
        position: relative;
        border-radius: 16rpx;
        overflow: hidden;
        border: 3rpx solid transparent;
        transition: all 0.2s;

        &.active {
          border-color: #FF8A65;
          box-shadow: 0 8rpx 24rpx rgba(255, 138, 101, 0.3);
        }

        .option-image {
          width: 100%;
          height: 120rpx;
          object-fit: cover;
        }

        .option-name {
          position: absolute;
          bottom: 0;
          left: 0;
          right: 0;
          background: rgba(0, 0, 0, 0.6);
          color: white;
          font-size: 24rpx;
          padding: 12rpx 16rpx;
          text-align: center;
        }
      }
    }

    .modal-actions {
      display: flex;
      gap: 24rpx;
      padding: 24rpx 32rpx 32rpx;

      .cancel-btn, .confirm-btn {
        flex: 1;
        height: 80rpx;
        border-radius: 20rpx;
        font-size: 28rpx;
        font-weight: bold;
        border: none;
        transition: all 0.2s;

        &:active {
          transform: scale(0.98);
        }
      }

      .cancel-btn {
        background: #F5F5F5;
        color: #666;

        &:active {
          background: #E0E0E0;
        }
      }

      .confirm-btn {
        background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
        color: white;
        box-shadow: 0 4rpx 12rpx rgba(255, 138, 101, 0.3);

        &:active {
          box-shadow: 0 2rpx 8rpx rgba(255, 138, 101, 0.4);
        }
      }
    }
  }
}

// 公告编辑弹窗
.announcement-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;

  .modal-content {
    background: white;
    border-radius: 24rpx;
    width: 640rpx;
    overflow: hidden;
    box-shadow: 0 16rpx 48rpx rgba(0, 0, 0, 0.2);

    .modal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 32rpx 32rpx 24rpx;
      border-bottom: 1rpx solid #F0F0F0;

      .modal-title {
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
      }

      .modal-close {
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background: #F5F5F5;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24rpx;
        color: #666;
        transition: all 0.2s;

        &:active {
          background: #E0E0E0;
        }
      }
    }

    .modal-body {
      padding: 24rpx 32rpx;

      .announcement-input {
        width: 100%;
        min-height: 200rpx;
        background: #F8F8F8;
        border-radius: 16rpx;
        padding: 20rpx;
        font-size: 28rpx;
        color: #333;
        line-height: 1.5;
        border: 2rpx solid transparent;
        transition: all 0.2s;

        &:focus {
          background: white;
          border-color: #FF8A65;
          box-shadow: 0 4rpx 12rpx rgba(255, 138, 101, 0.2);
        }
      }

      .input-tip {
        display: flex;
        justify-content: flex-end;
        margin-top: 12rpx;

        .tip-text {
          font-size: 24rpx;
          color: #999;
        }
      }
    }

    .modal-actions {
      display: flex;
      gap: 24rpx;
      padding: 24rpx 32rpx 32rpx;

      .cancel-btn, .confirm-btn {
        flex: 1;
        height: 80rpx;
        border-radius: 20rpx;
        font-size: 28rpx;
        font-weight: bold;
        border: none;
        transition: all 0.2s;

        &:active {
          transform: scale(0.98);
        }
      }

      .cancel-btn {
        background: #F5F5F5;
        color: #666;

        &:active {
          background: #E0E0E0;
        }
      }

      .confirm-btn {
        background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
        color: white;
        box-shadow: 0 4rpx 12rpx rgba(255, 138, 101, 0.3);

        &:active {
          box-shadow: 0 2rpx 8rpx rgba(255, 138, 101, 0.4);
        }
      }
    }
  }
}

// 公告滚动动画
@keyframes scroll-left {
  0% {
    transform: translateX(100%);
  }
  100% {
    transform: translateX(-100%);
  }
}
</style>
