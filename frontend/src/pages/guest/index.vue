<template>
  <view class="guest-page">
    <!-- 加载状态 -->
    <view class="loading-state" v-if="isLoading">
      <view class="loading-content">
        <text class="loading-icon">🍽️</text>
        <text class="loading-text">正在验证邀请...</text>
      </view>
    </view>

    <!-- 邀请无效 -->
    <view class="invalid-invite" v-else-if="!isValidInvite">
      <view class="invalid-content">
        <text class="invalid-icon">😔</text>
        <text class="invalid-title">邀请已失效</text>
        <text class="invalid-desc">该邀请码已过期或不存在，请联系邀请人获取新的邀请码</text>
        
        <view class="invalid-actions">
          <button class="action-btn secondary" @click="goBack">
            返回
          </button>
          <button class="action-btn primary" @click="showInputInvite = true">
            输入邀请码
          </button>
        </view>
      </view>
    </view>

    <!-- 访客欢迎页面 -->
    <view class="guest-welcome" v-else-if="!isGuestRegistered">
      <view class="welcome-header">
        <view class="welcome-bg"></view>
        <view class="welcome-content">
          <image 
            class="family-avatar" 
            :src="familyInfo?.avatar || defaultFamilyAvatar" 
            mode="aspectFill"
          />
          <text class="welcome-title">欢迎来到</text>
          <text class="family-name">{{ familyInfo?.name }}</text>
          <text class="welcome-desc">{{ familyInfo?.description || '品尝温馨家庭料理' }}</text>
          
          <view class="family-features">
            <view class="feature-item">
              <text class="feature-icon">📖</text>
              <text class="feature-text">{{ recipeCount }} 道精选菜谱</text>
            </view>
            <view class="feature-item">
              <text class="feature-icon">⭐</text>
              <text class="feature-text">家庭特色料理</text>
            </view>
            <view class="feature-item">
              <text class="feature-icon">🚀</text>
              <text class="feature-text">快速点餐服务</text>
            </view>
          </view>
        </view>
      </view>
      
      <view class="guest-info-form card">
        <view class="form-header">
          <text class="form-title">完善信息</text>
          <text class="form-subtitle">让我们更好地为您服务</text>
        </view>
        
        <view class="form-content">
          <view class="form-item">
            <text class="form-label">昵称</text>
            <input 
              class="form-input" 
              v-model="guestInfo.nickname" 
              placeholder="请输入您的昵称"
              maxlength="20"
            />
          </view>
          
          <view class="form-item">
            <text class="form-label">联系方式（可选）</text>
            <input 
              class="form-input" 
              v-model="guestInfo.phone" 
              placeholder="方便联系时使用"
              maxlength="11"
            />
          </view>
        </view>
        
        <view class="form-actions">
          <button 
            class="submit-btn primary" 
            :disabled="!guestInfo.nickname.trim() || isRegistering"
            @click="registerGuest"
          >
            <text class="btn-text">
              {{ isRegistering ? '注册中...' : '开始体验' }}
            </text>
          </button>
        </view>
      </view>
      
      <view class="guest-tips">
        <text class="tips-title">温馨提示</text>
        <text class="tips-item">• 访客模式下可以浏览菜谱和下订单</text>
        <text class="tips-item">• 您的信息仅用于本次访问，不会被保存</text>
        <text class="tips-item">• 访客权限在邀请有效期内自动失效</text>
      </view>
    </view>

    <!-- 访客主页面 -->
    <view class="guest-main" v-else>
      <!-- 访客状态栏 -->
      <view class="guest-status-bar">
        <view class="status-info">
          <text class="status-icon">👋</text>
          <text class="status-text">您好，{{ guestInfo.nickname }}</text>
        </view>
        <view class="status-family">
          <text class="family-label">正在访问</text>
          <text class="family-name">{{ familyInfo?.name }}</text>
        </view>
      </view>
      
      <!-- 菜谱展示区域 -->
      <view class="recipe-section">
        <view class="section-header">
          <text class="section-title">精选菜谱</text>
          <text class="recipe-count">{{ recipes.length }} 道菜品</text>
        </view>
        
        <view class="recipe-grid" v-if="recipes.length > 0">
          <view 
            class="recipe-card" 
            v-for="recipe in recipes" 
            :key="recipe.id"
            @click="viewRecipe(recipe)"
          >
            <image 
              class="recipe-image" 
              :src="recipe.image || defaultRecipeImage" 
              mode="aspectFill"
            />
            <view class="recipe-info">
              <text class="recipe-name">{{ recipe.name }}</text>
              <text class="recipe-price">¥{{ recipe.price || '时价' }}</text>
            </view>
            <button class="order-btn" @click.stop="addToCart(recipe)">
              <text class="btn-text">点餐</text>
            </button>
          </view>
        </view>
        
        <view class="empty-recipes" v-else>
          <text class="empty-icon">📖</text>
          <text class="empty-text">暂无可用菜谱</text>
        </view>
      </view>
    </view>

    <!-- 输入邀请码弹窗 -->
    <uni-popup ref="inputInvitePopup" type="center" :mask-click="false">
      <view class="popup-content">
        <view class="popup-header">
          <text class="popup-title">输入邀请码</text>
          <text class="popup-close" @click="showInputInvite = false">✕</text>
        </view>
        
        <view class="popup-body">
          <input 
            class="invite-input" 
            v-model="inputInviteCode" 
            placeholder="请输入邀请码"
            maxlength="20"
          />
        </view>
        
        <view class="popup-actions">
          <button class="popup-btn secondary" @click="showInputInvite = false">
            取消
          </button>
          <button 
            class="popup-btn primary" 
            :disabled="!inputInviteCode.trim()"
            @click="checkInputInvite"
          >
            确定
          </button>
        </view>
      </view>
    </uni-popup>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { FamilyService } from '@/api/family'

// 响应式数据
const isLoading = ref(true)
const isValidInvite = ref(false)
const isGuestRegistered = ref(false)
const isRegistering = ref(false)

// 邀请和家庭信息
const inviteCode = ref('')
const familyInfo = ref(null)
const recipeCount = ref(0)

// 访客信息
const guestInfo = ref({
  nickname: '',
  phone: ''
})

// 菜谱数据
const recipes = ref([])

// 弹窗控制
const showInputInvite = ref(false)
const inputInviteCode = ref('')

// 默认图片
const defaultFamilyAvatar = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjYwIiBoZWlnaHQ9IjYwIiByeD0iMzAiIGZpbGw9IiNGRkY4QTY1Ii8+Cjx0ZXh0IHg9IjMwIiB5PSIzOCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjI0IiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+PoDwvdGV4dD4KPHN2Zz4=')
const defaultRecipeImage = ref('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==')

// 页面加载
onMounted(async () => {
  await initGuestPage()
})

// 监听弹窗状态
watch(showInputInvite, (newVal) => {
  if (newVal) {
    inputInviteCode.value = ''
  }
})

// 初始化访客页面
const initGuestPage = async () => {
  try {
    isLoading.value = true

    // 从URL参数获取邀请码
    const pages = getCurrentPages()
    const currentPage = pages[pages.length - 1]
    const options = currentPage.options || {}
    inviteCode.value = options.invite || ''

    if (!inviteCode.value) {
      isValidInvite.value = false
      return
    }

    await checkInviteCode(inviteCode.value)

  } catch (error) {
    console.error('初始化访客页面失败:', error)
    isValidInvite.value = false
  } finally {
    isLoading.value = false
  }
}

// 检查邀请码
const checkInviteCode = async (code: string) => {
  try {
    const inviteInfo = await FamilyService.checkGuestInvite(code)
    
    if (inviteInfo && inviteInfo.is_valid) {
      isValidInvite.value = true
      familyInfo.value = inviteInfo.family
      recipeCount.value = inviteInfo.recipe_count || 0
      
      // 检查是否已经注册为访客
      const guestToken = uni.getStorageSync('guest_token')
      if (guestToken) {
        isGuestRegistered.value = true
        await loadGuestData()
      }
    } else {
      isValidInvite.value = false
    }
  } catch (error) {
    console.error('检查邀请码失败:', error)
    isValidInvite.value = false
  }
}

// 注册访客
const registerGuest = async () => {
  if (!guestInfo.value.nickname.trim()) {
    uni.showToast({
      title: '请输入昵称',
      icon: 'none'
    })
    return
  }

  try {
    isRegistering.value = true

    const params = {
      invite_code: inviteCode.value,
      user_info: {
        nickname: guestInfo.value.nickname.trim(),
        avatar_url: '',
        gender: 0
      }
    }

    const result = await FamilyService.guestRegister(params)
    
    // 保存访客token
    uni.setStorageSync('guest_token', result.token)
    uni.setStorageSync('guest_info', result.guest_info)
    
    isGuestRegistered.value = true
    await loadGuestData()

    uni.showToast({
      title: '欢迎体验',
      icon: 'success'
    })

  } catch (error: any) {
    console.error('注册访客失败:', error)
    uni.showToast({
      title: error.message || '注册失败',
      icon: 'error'
    })
  } finally {
    isRegistering.value = false
  }
}

// 加载访客数据
const loadGuestData = async () => {
  try {
    // TODO: 加载菜谱数据
    // const recipeList = await RecipeService.getGuestRecipes()
    // recipes.value = recipeList
    
    // 临时数据
    recipes.value = []
  } catch (error) {
    console.error('加载访客数据失败:', error)
  }
}

// 查看菜谱详情
const viewRecipe = (recipe: any) => {
  uni.navigateTo({
    url: `/pages/guest/recipe-detail?id=${recipe.id}`
  })
}

// 添加到购物车
const addToCart = (recipe: any) => {
  uni.showToast({
    title: '已添加到购物车',
    icon: 'success'
  })
  // TODO: 实现购物车功能
}

// 返回
const goBack = () => {
  uni.navigateBack()
}

// 检查输入的邀请码
const checkInputInvite = async () => {
  if (!inputInviteCode.value.trim()) return

  try {
    inviteCode.value = inputInviteCode.value.trim()
    showInputInvite.value = false
    isLoading.value = true
    
    await checkInviteCode(inviteCode.value)
  } catch (error) {
    console.error('检查邀请码失败:', error)
  } finally {
    isLoading.value = false
  }
}
</script>

<style lang="scss" scoped>
.guest-page {
  min-height: 100vh;
  background-color: #FAFAFA;
}

.card {
  background-color: #fff;
  border-radius: 16rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
  margin-bottom: 24rpx;
}

// 加载状态
.loading-state {
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

// 邀请无效
.invalid-invite {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 40rpx;

  .invalid-content {
    text-align: center;
    max-width: 500rpx;

    .invalid-icon {
      font-size: 120rpx;
      display: block;
      margin-bottom: 32rpx;
    }

    .invalid-title {
      display: block;
      font-size: 36rpx;
      font-weight: bold;
      color: #333;
      margin-bottom: 16rpx;
    }

    .invalid-desc {
      display: block;
      font-size: 28rpx;
      color: #666;
      line-height: 1.6;
      margin-bottom: 48rpx;
    }

    .invalid-actions {
      display: flex;
      gap: 16rpx;

      .action-btn {
        flex: 1;
        padding: 16rpx 24rpx;
        border-radius: 12rpx;
        font-size: 28rpx;
        font-weight: bold;
        border: none;

        &.primary {
          background-color: #FF8A65;
          color: white;
        }

        &.secondary {
          background-color: #F5F5F5;
          color: #333;
        }
      }
    }
  }
}

// 访客欢迎页面
.guest-welcome {
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

      .family-avatar {
        width: 120rpx;
        height: 120rpx;
        border-radius: 60rpx;
        border: 4rpx solid rgba(255, 255, 255, 0.3);
        margin-bottom: 24rpx;
      }

      .welcome-title {
        font-size: 28rpx;
        opacity: 0.9;
        margin-bottom: 8rpx;
      }

      .family-name {
        font-size: 40rpx;
        font-weight: bold;
        margin-bottom: 16rpx;
      }

      .welcome-desc {
        font-size: 26rpx;
        opacity: 0.8;
        margin-bottom: 32rpx;
      }

      .family-features {
        display: flex;
        gap: 32rpx;

        .feature-item {
          display: flex;
          flex-direction: column;
          align-items: center;

          .feature-icon {
            font-size: 32rpx;
            margin-bottom: 8rpx;
          }

          .feature-text {
            font-size: 22rpx;
            opacity: 0.8;
          }
        }
      }
    }
  }

  .guest-info-form {
    margin: 24rpx;
    padding: 32rpx;

    .form-header {
      text-align: center;
      margin-bottom: 32rpx;

      .form-title {
        display: block;
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
        margin-bottom: 8rpx;
      }

      .form-subtitle {
        display: block;
        font-size: 26rpx;
        color: #666;
      }
    }

    .form-content {
      .form-item {
        margin-bottom: 24rpx;

        .form-label {
          display: block;
          font-size: 28rpx;
          color: #333;
          margin-bottom: 12rpx;
        }

        .form-input {
          width: 100%;
          padding: 20rpx;
          border: 2rpx solid #E0E0E0;
          border-radius: 12rpx;
          font-size: 28rpx;
          color: #333;
          background-color: #FAFAFA;
        }
      }
    }

    .form-actions {
      margin-top: 32rpx;

      .submit-btn {
        width: 100%;
        padding: 20rpx;
        background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
        color: white;
        border-radius: 12rpx;
        font-size: 28rpx;
        font-weight: bold;
        border: none;

        &:disabled {
          opacity: 0.6;
        }
      }
    }
  }

  .guest-tips {
    padding: 32rpx;

    .tips-title {
      display: block;
      font-size: 28rpx;
      font-weight: bold;
      color: #333;
      margin-bottom: 16rpx;
    }

    .tips-item {
      display: block;
      font-size: 24rpx;
      color: #666;
      line-height: 1.6;
      margin-bottom: 8rpx;
    }
  }
}

// 访客主页面
.guest-main {
  .guest-status-bar {
    background-color: white;
    padding: 24rpx 32rpx;
    display: flex;
    justify-content: space-between;
    align-items: center;
    box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.1);

    .status-info {
      display: flex;
      align-items: center;
      gap: 12rpx;

      .status-icon {
        font-size: 24rpx;
      }

      .status-text {
        font-size: 28rpx;
        color: #333;
        font-weight: bold;
      }
    }

    .status-family {
      text-align: right;

      .family-label {
        display: block;
        font-size: 22rpx;
        color: #999;
        margin-bottom: 4rpx;
      }

      .family-name {
        display: block;
        font-size: 24rpx;
        color: #FF8A65;
        font-weight: bold;
      }
    }
  }

  .recipe-section {
    padding: 24rpx;

    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24rpx;

      .section-title {
        font-size: 32rpx;
        font-weight: bold;
        color: #333;
      }

      .recipe-count {
        font-size: 24rpx;
        color: #666;
      }
    }

    .recipe-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 16rpx;

      .recipe-card {
        background-color: white;
        border-radius: 12rpx;
        overflow: hidden;
        box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);

        .recipe-image {
          width: 100%;
          height: 200rpx;
        }

        .recipe-info {
          padding: 16rpx;

          .recipe-name {
            display: block;
            font-size: 28rpx;
            font-weight: bold;
            color: #333;
            margin-bottom: 8rpx;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }

          .recipe-price {
            display: block;
            font-size: 24rpx;
            color: #FF8A65;
            font-weight: bold;
          }
        }

        .order-btn {
          width: 100%;
          padding: 12rpx;
          background-color: #FF8A65;
          color: white;
          border: none;
          font-size: 24rpx;
          font-weight: bold;
        }
      }
    }

    .empty-recipes {
      text-align: center;
      padding: 80rpx 40rpx;

      .empty-icon {
        font-size: 80rpx;
        display: block;
        margin-bottom: 24rpx;
        opacity: 0.6;
      }

      .empty-text {
        font-size: 28rpx;
        color: #666;
      }
    }
  }
}

// 弹窗样式
.popup-content {
  width: 600rpx;
  background-color: white;
  border-radius: 16rpx;
  overflow: hidden;

  .popup-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 32rpx;
    border-bottom: 1rpx solid #E0E0E0;

    .popup-title {
      font-size: 32rpx;
      font-weight: bold;
      color: #333;
    }

    .popup-close {
      font-size: 32rpx;
      color: #999;
      width: 48rpx;
      height: 48rpx;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }

  .popup-body {
    padding: 32rpx;

    .invite-input {
      width: 100%;
      padding: 20rpx;
      border: 2rpx solid #E0E0E0;
      border-radius: 12rpx;
      font-size: 28rpx;
      color: #333;
      text-align: center;
    }
  }

  .popup-actions {
    display: flex;
    border-top: 1rpx solid #E0E0E0;

    .popup-btn {
      flex: 1;
      height: 88rpx;
      border: none;
      font-size: 28rpx;

      &.primary {
        background-color: #FF8A65;
        color: white;
      }

      &.secondary {
        background-color: #F5F5F5;
        color: #333;
      }

      &:disabled {
        opacity: 0.6;
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
</style>
