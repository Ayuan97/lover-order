<template>
  <view class="demo-page">
    <view class="demo-header">
      <text class="demo-title">访客分享功能演示</text>
      <text class="demo-subtitle">体验完整的访客邀请流程</text>
    </view>

    <!-- 功能流程图 -->
    <view class="flow-diagram card">
      <view class="flow-title">功能流程</view>
      
      <view class="flow-steps">
        <view class="step-item" :class="{ active: currentStep >= 1 }">
          <view class="step-number">1</view>
          <view class="step-content">
            <text class="step-title">家庭成员创建邀请</text>
            <text class="step-desc">在家庭管理页面点击"邀请朋友"</text>
          </view>
        </view>
        
        <view class="step-arrow">↓</view>
        
        <view class="step-item" :class="{ active: currentStep >= 2 }">
          <view class="step-number">2</view>
          <view class="step-content">
            <text class="step-title">设置邀请参数</text>
            <text class="step-desc">选择有效期、添加备注信息</text>
          </view>
        </view>
        
        <view class="step-arrow">↓</view>
        
        <view class="step-item" :class="{ active: currentStep >= 3 }">
          <view class="step-number">3</view>
          <view class="step-content">
            <text class="step-title">分享邀请码</text>
            <text class="step-desc">通过微信、复制链接等方式分享</text>
          </view>
        </view>
        
        <view class="step-arrow">↓</view>
        
        <view class="step-item" :class="{ active: currentStep >= 4 }">
          <view class="step-number">4</view>
          <view class="step-content">
            <text class="step-title">朋友进入访客模式</text>
            <text class="step-desc">通过邀请码注册访客身份</text>
          </view>
        </view>
        
        <view class="step-arrow">↓</view>
        
        <view class="step-item" :class="{ active: currentStep >= 5 }">
          <view class="step-number">5</view>
          <view class="step-content">
            <text class="step-title">浏览菜谱下订单</text>
            <text class="step-desc">访客可以查看菜谱并下订单</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 功能特色 -->
    <view class="features-section card">
      <view class="features-title">功能特色</view>
      
      <view class="features-grid">
        <view class="feature-card">
          <text class="feature-icon">⏰</text>
          <text class="feature-title">时效控制</text>
          <text class="feature-desc">可设置1小时到7天的有效期</text>
        </view>
        
        <view class="feature-card">
          <text class="feature-icon">🔒</text>
          <text class="feature-title">权限隔离</text>
          <text class="feature-desc">访客只能查看和点餐，无法修改</text>
        </view>
        
        <view class="feature-card">
          <text class="feature-icon">📊</text>
          <text class="feature-title">使用统计</text>
          <text class="feature-desc">实时查看邀请使用情况</text>
        </view>
        
        <view class="feature-card">
          <text class="feature-icon">🎯</text>
          <text class="feature-title">精准分享</text>
          <text class="feature-desc">一码一用，安全可控</text>
        </view>
      </view>
    </view>

    <!-- 使用场景 -->
    <view class="scenarios-section card">
      <view class="scenarios-title">使用场景</view>
      
      <view class="scenario-list">
        <view class="scenario-item">
          <text class="scenario-icon">🏠</text>
          <view class="scenario-content">
            <text class="scenario-title">朋友来访</text>
            <text class="scenario-desc">朋友来家里做客时，可以提前查看菜谱并点餐</text>
          </view>
        </view>
        
        <view class="scenario-item">
          <text class="scenario-icon">🎉</text>
          <view class="scenario-content">
            <text class="scenario-title">聚会活动</text>
            <text class="scenario-desc">组织聚会时，让参与者提前选择喜欢的菜品</text>
          </view>
        </view>
        
        <view class="scenario-item">
          <text class="scenario-icon">💼</text>
          <view class="scenario-content">
            <text class="scenario-title">商务招待</text>
            <text class="scenario-desc">商务客户可以提前了解菜品并预订</text>
          </view>
        </view>
        
        <view class="scenario-item">
          <text class="scenario-icon">👨‍👩‍👧‍👦</text>
          <view class="scenario-content">
            <text class="scenario-title">亲友聚餐</text>
            <text class="scenario-desc">亲戚朋友聚餐时，大家一起选择菜品</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 操作按钮 -->
    <view class="demo-actions">
      <button class="demo-btn primary" @click="startDemo">
        <text class="btn-icon">🚀</text>
        <text class="btn-text">开始体验</text>
      </button>
      
      <button class="demo-btn secondary" @click="viewGuestPage">
        <text class="btn-icon">👀</text>
        <text class="btn-text">查看访客页面</text>
      </button>
    </view>

    <!-- 技术说明 -->
    <view class="tech-info card">
      <view class="tech-title">技术实现</view>
      
      <view class="tech-list">
        <view class="tech-item">
          <text class="tech-label">邀请码生成</text>
          <text class="tech-value">随机字符串 + 时间戳</text>
        </view>
        
        <view class="tech-item">
          <text class="tech-label">权限控制</text>
          <text class="tech-value">基于JWT的访客token</text>
        </view>
        
        <view class="tech-item">
          <text class="tech-label">有效期管理</text>
          <text class="tech-value">服务端时间验证</text>
        </view>
        
        <view class="tech-item">
          <text class="tech-label">分享方式</text>
          <text class="tech-value">微信分享 + 链接复制</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

// 响应式数据
const currentStep = ref(1)

// 开始演示
const startDemo = () => {
  // 模拟步骤进度
  let step = 1
  const timer = setInterval(() => {
    currentStep.value = step
    step++
    if (step > 5) {
      clearInterval(timer)
      uni.showToast({
        title: '演示完成',
        icon: 'success'
      })
    }
  }, 1000)
  
  // 跳转到家庭管理页面
  setTimeout(() => {
    uni.navigateTo({
      url: '/pages/family/index'
    })
  }, 2000)
}

// 查看访客页面
const viewGuestPage = () => {
  // 使用演示邀请码
  const demoInviteCode = 'DEMO123'
  uni.navigateTo({
    url: `/pages/guest/index?invite=${demoInviteCode}`
  })
}
</script>

<style lang="scss" scoped>
.demo-page {
  padding: 24rpx;
  background-color: #FAFAFA;
  min-height: 100vh;
}

.card {
  background-color: #fff;
  border-radius: 16rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.1);
  margin-bottom: 24rpx;
  padding: 32rpx;
}

// 页面头部
.demo-header {
  text-align: center;
  padding: 32rpx 0 48rpx;
  
  .demo-title {
    display: block;
    font-size: 40rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 8rpx;
  }
  
  .demo-subtitle {
    display: block;
    font-size: 28rpx;
    color: #FF8A65;
  }
}

// 流程图
.flow-diagram {
  .flow-title {
    font-size: 32rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 32rpx;
    text-align: center;
  }
  
  .flow-steps {
    .step-item {
      display: flex;
      align-items: center;
      margin-bottom: 24rpx;
      opacity: 0.5;
      transition: all 0.3s ease;
      
      &.active {
        opacity: 1;
        transform: scale(1.02);
      }
      
      .step-number {
        width: 48rpx;
        height: 48rpx;
        border-radius: 24rpx;
        background-color: #E0E0E0;
        color: #999;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24rpx;
        font-weight: bold;
        margin-right: 24rpx;
        transition: all 0.3s ease;
      }
      
      &.active .step-number {
        background-color: #FF8A65;
        color: white;
      }
      
      .step-content {
        flex: 1;
        
        .step-title {
          display: block;
          font-size: 28rpx;
          font-weight: bold;
          color: #333;
          margin-bottom: 4rpx;
        }
        
        .step-desc {
          display: block;
          font-size: 24rpx;
          color: #666;
        }
      }
    }
    
    .step-arrow {
      text-align: center;
      font-size: 24rpx;
      color: #CCC;
      margin: 16rpx 0;
    }
  }
}

// 功能特色
.features-section {
  .features-title {
    font-size: 32rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 32rpx;
    text-align: center;
  }
  
  .features-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 16rpx;
    
    .feature-card {
      background-color: #F8F8F8;
      padding: 24rpx;
      border-radius: 12rpx;
      text-align: center;
      
      .feature-icon {
        font-size: 48rpx;
        display: block;
        margin-bottom: 16rpx;
      }
      
      .feature-title {
        display: block;
        font-size: 26rpx;
        font-weight: bold;
        color: #333;
        margin-bottom: 8rpx;
      }
      
      .feature-desc {
        display: block;
        font-size: 22rpx;
        color: #666;
        line-height: 1.4;
      }
    }
  }
}

// 使用场景
.scenarios-section {
  .scenarios-title {
    font-size: 32rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 32rpx;
    text-align: center;
  }
  
  .scenario-list {
    .scenario-item {
      display: flex;
      align-items: center;
      margin-bottom: 24rpx;
      
      .scenario-icon {
        font-size: 40rpx;
        width: 80rpx;
        text-align: center;
        margin-right: 24rpx;
      }
      
      .scenario-content {
        flex: 1;
        
        .scenario-title {
          display: block;
          font-size: 28rpx;
          font-weight: bold;
          color: #333;
          margin-bottom: 4rpx;
        }
        
        .scenario-desc {
          display: block;
          font-size: 24rpx;
          color: #666;
          line-height: 1.5;
        }
      }
    }
  }
}

// 操作按钮
.demo-actions {
  display: flex;
  gap: 16rpx;
  margin: 32rpx 0;
  
  .demo-btn {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12rpx;
    padding: 20rpx;
    border-radius: 12rpx;
    font-size: 28rpx;
    font-weight: bold;
    border: none;
    
    &.primary {
      background: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
      color: white;
    }
    
    &.secondary {
      background-color: #F5F5F5;
      color: #333;
    }
    
    .btn-icon {
      font-size: 24rpx;
    }
  }
}

// 技术说明
.tech-info {
  .tech-title {
    font-size: 32rpx;
    font-weight: bold;
    color: #333;
    margin-bottom: 32rpx;
    text-align: center;
  }
  
  .tech-list {
    .tech-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16rpx 0;
      border-bottom: 1rpx solid #F0F0F0;
      
      &:last-child {
        border-bottom: none;
      }
      
      .tech-label {
        font-size: 26rpx;
        color: #333;
        font-weight: bold;
      }
      
      .tech-value {
        font-size: 24rpx;
        color: #666;
      }
    }
  }
}
</style>
