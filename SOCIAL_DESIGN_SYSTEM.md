# Love Order 社交互动风格设计系统

## 核心设计理念

Love Order 采用**社交媒体互动风格**，将传统点餐应用转变为充满温情的家庭社交平台。

### 设计灵感来源

- **Instagram Stories** - 动态故事条，圆形头像，渐变边框
- **Pinterest** - 瀑布流网格布局，视觉优先的卡片设计
- **Facebook Timeline** - 时间线叙事，连接线设计，状态节点

### 设计目标

1. **社交化** - 让每次点餐都像发布动态，让每道菜都像社交内容
2. **情感化** - 用温馨的语言和emoji传递爱意
3. **互动化** - 点赞、收藏、评论等社交互动元素
4. **视觉化** - 图片优先，美食照片是核心内容

---

## 色彩系统

### 主色调 - 温暖珊瑚橙

```scss
// 主色
$primary: #FF8A65;                // 珊瑚橙 - 温暖、活泼、食欲感
$primary-dark: #FF7043;           // 深橙 - 渐变深色端
$primary-light: #FFAB91;          // 浅橙 - 高亮和淡化

// 辅助色
$secondary: #FFB4A2;              // 蜜桃粉 - 柔和、浪漫
$accent: #FFA726;                 // 琥珀橙 - 强调和吸引注意

// 渐变
$gradient-primary: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
$gradient-secondary: linear-gradient(135deg, #FFB4A2 0%, #FF8A65 100%);
$gradient-accent: linear-gradient(135deg, #FFA726 0%, #FF8A65 100%);
```

### 功能色

```scss
$success: #66BB6A;    // 绿色 - 完成、成功
$warning: #FFA726;    // 橙色 - 提醒、警告
$danger: #F44336;     // 红色 - 错误、取消
$info: #42A5F5;       // 蓝色 - 信息提示
```

### 中性色系统

```scss
// 文本颜色
$text-primary: #333333;           // 主要文字
$text-secondary: #666666;         // 次要文字
$text-tertiary: #999999;          // 辅助文字
$text-placeholder: #CCCCCC;       // 占位符文字

// 背景颜色
$bg-page: #FAFAFA;                // 页面背景
$bg-card: #FFFFFF;                // 卡片背景
$bg-section: #F5F5F5;             // 区块背景
$bg-hover: #F0F0F0;               // 悬停背景
$bg-disabled: #E0E0E0;            // 禁用背景

// 边框颜色
$border-light: #F0F0F0;           // 浅边框
$border-base: #E0E0E0;            // 基础边框
$border-dark: #D0D0D0;            // 深边框
```

### 社交互动色彩

```scss
// 点赞红心
$heart-color: #FF4458;
$heart-gradient: linear-gradient(135deg, #FF4458 0%, #FF6B7A 100%);

// Instagram 渐变边框（Stories）
$instagram-gradient: linear-gradient(
  45deg,
  #f09433 0%,
  #e6683c 25%,
  #dc2743 50%,
  #cc2366 75%,
  #bc1888 100%
);
```

---

## 字体系统

### 字号层级（8 级）

```scss
$font-size-xxs: 20rpx;     // 注释、标签、徽章
$font-size-xs: 24rpx;      // 辅助信息、时间戳
$font-size-sm: 26rpx;      // 描述文字、说明
$font-size-base: 28rpx;    // 正文基准 ⭐
$font-size-md: 30rpx;      // 中标题
$font-size-lg: 32rpx;      // 小标题、重要信息
$font-size-xl: 36rpx;      // 大标题
$font-size-xxl: 40rpx;     // 超大标题、主要标题
```

### 字重

```scss
$font-weight-normal: 400;   // 正常文本
$font-weight-medium: 500;   // 强调文本
$font-weight-bold: 700;     // 标题、按钮
```

### 行高

```scss
$line-height-tight: 1.2;    // 紧凑标题
$line-height-base: 1.5;     // 基础正文 ⭐
$line-height-relaxed: 1.8;  // 宽松段落
```

---

## 间距系统（8rpx 基准）

```scss
$spacing-xs: 8rpx;          // 最小间距 - 紧密元素
$spacing-sm: 12rpx;         // 小间距 - 相关元素
$spacing-md: 16rpx;         // 中间距 - 标准元素
$spacing-base: 24rpx;       // 基础间距 ⭐ - 常用间距
$spacing-lg: 32rpx;         // 大间距 - 区块内部
$spacing-xl: 48rpx;         // 超大间距 - 区块之间
$spacing-xxl: 64rpx;        // 巨大间距 - 页面分区
```

### 间距使用原则

- **8rpx 倍数** - 所有间距必须是 8 的倍数
- **视觉层级** - 间距大小体现内容的关联程度
- **呼吸感** - 适当的留白让页面不拥挤

---

## 圆角系统

```scss
$radius-sm: 8rpx;           // 小圆角 - 标签、徽章
$radius-base: 12rpx;        // 基础圆角 - 输入框
$radius-md: 16rpx;          // 中圆角 - 小卡片
$radius-lg: 20rpx;          // 大圆角 - 卡片、弹窗 ⭐
$radius-xl: 24rpx;          // 超大圆角 - 大卡片
$radius-button: 48rpx;      // 按钮圆角 - 胶囊形状
$radius-round: 50%;         // 圆形 - 头像、图标按钮
```

### 圆角使用原则

- **统一性** - 同类元素使用相同圆角
- **层级性** - 重要元素使用更大圆角
- **品牌感** - 适度圆润体现温馨友好

---

## 阴影系统

```scss
// 基础阴影
$shadow-sm: 0 2rpx 8rpx rgba(0, 0, 0, 0.04);         // 极轻阴影 - 悬停
$shadow-base: 0 4rpx 12rpx rgba(0, 0, 0, 0.08);      // 基础阴影 - 卡片 ⭐
$shadow-md: 0 8rpx 24rpx rgba(0, 0, 0, 0.12);        // 中等阴影 - 弹窗
$shadow-lg: 0 16rpx 48rpx rgba(0, 0, 0, 0.16);       // 大阴影 - 模态框

// 彩色阴影（品牌色）
$shadow-primary: 0 8rpx 24rpx rgba(255, 138, 101, 0.4);           // 主按钮阴影
$shadow-primary-hover: 0 4rpx 12rpx rgba(255, 138, 101, 0.3);     // 按钮按下阴影
$shadow-success: 0 4rpx 12rpx rgba(102, 187, 106, 0.3);           // 成功状态阴影
$shadow-danger: 0 4rpx 12rpx rgba(244, 67, 54, 0.3);              // 危险状态阴影
```

---

## 核心组件设计

### 1. Stories 动态条（Instagram 风格）

```vue
<scroll-view class="stories-container" scroll-x :show-scrollbar="false">
  <!-- 添加动态按钮 -->
  <view class="story-item add-story">
    <view class="story-avatar">
      <text class="add-icon">+</text>
    </view>
    <text class="story-name">发布动态</text>
  </view>

  <!-- 家庭成员 Stories -->
  <view class="story-item" v-for="member in members" :key="member.id">
    <view class="story-avatar" :class="{ 'has-story': member.hasStory }">
      <image class="avatar-img" :src="member.avatar" mode="aspectFill" />
    </view>
    <text class="story-name">{{ member.name }}</text>
  </view>
</scroll-view>
```

**样式特点：**
- 圆形头像带渐变边框（has-story 时使用 Instagram 渐变）
- 横向滚动，隐藏滚动条
- 添加按钮用 + 号突出显示

```scss
.stories-container {
  padding: 20rpx 24rpx;
  white-space: nowrap;
  background: white;

  .story-item {
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    margin-right: 20rpx;

    .story-avatar {
      width: 88rpx;
      height: 88rpx;
      border-radius: 50%;
      padding: 4rpx;
      background: $bg-section;
      margin-bottom: 8rpx;

      &.has-story {
        background: $instagram-gradient;
      }

      .avatar-img {
        width: 100%;
        height: 100%;
        border-radius: 50%;
        border: 4rpx solid white;
      }
    }

    &.add-story .story-avatar {
      background: $gradient-primary;
      @include flex-center;

      .add-icon {
        font-size: 40rpx;
        color: white;
        font-weight: bold;
      }
    }

    .story-name {
      font-size: $font-size-xs;
      color: $text-secondary;
      max-width: 88rpx;
      @include text-ellipsis(1);
    }
  }
}
```

### 2. 社交动态卡片（Feed Card）

```vue
<view class="feed-card">
  <!-- 卡片头部 - 用户信息 -->
  <view class="card-header">
    <view class="user-info">
      <image class="avatar" :src="feed.user.avatar" mode="aspectFill" />
      <view class="info">
        <text class="username">{{ feed.user.name }}</text>
        <text class="timestamp">{{ feed.time }}</text>
      </view>
    </view>
    <view class="more-btn">
      <text class="icon">⋯</text>
    </view>
  </view>

  <!-- 卡片内容 - 图片/文字 -->
  <view class="card-content">
    <text class="content-text" v-if="feed.text">{{ feed.text }}</text>
    <image class="content-image" :src="feed.image" mode="aspectFill" />
  </view>

  <!-- 卡片底部 - 互动按钮 -->
  <view class="card-interactions">
    <view class="interaction-btn" @click="toggleLike">
      <text class="action-icon" :class="{ liked: feed.isLiked }">
        {{ feed.isLiked ? '❤️' : '🤍' }}
      </text>
      <text class="action-text">{{ feed.likes }}</text>
    </view>
    <view class="interaction-btn" @click="comment">
      <text class="action-icon">💬</text>
      <text class="action-text">{{ feed.comments }}</text>
    </view>
    <view class="interaction-btn" @click="share">
      <text class="action-icon">📤</text>
    </view>
  </view>
</view>
```

**样式特点：**
- 白色卡片背景，轻阴影
- 圆形头像 + 用户名 + 时间戳
- 图片铺满宽度
- 底部互动栏：点赞、评论、分享

```scss
.feed-card {
  background: white;
  border-radius: $radius-lg;
  margin-bottom: $spacing-base;
  box-shadow: $shadow-base;
  overflow: hidden;

  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20rpx 24rpx;

    .user-info {
      display: flex;
      align-items: center;
      gap: 16rpx;

      .avatar {
        width: 64rpx;
        height: 64rpx;
        border-radius: 50%;
      }

      .info {
        .username {
          display: block;
          font-size: $font-size-base;
          font-weight: $font-weight-bold;
          color: $text-primary;
        }

        .timestamp {
          font-size: $font-size-xs;
          color: $text-tertiary;
        }
      }
    }

    .more-btn {
      width: 48rpx;
      height: 48rpx;
      @include flex-center;

      .icon {
        font-size: 24rpx;
        color: $text-tertiary;
      }
    }
  }

  .card-content {
    .content-text {
      display: block;
      padding: 0 24rpx 16rpx;
      font-size: $font-size-base;
      color: $text-primary;
      line-height: $line-height-base;
    }

    .content-image {
      width: 100%;
      height: 500rpx;
    }
  }

  .card-interactions {
    display: flex;
    align-items: center;
    gap: 24rpx;
    padding: 16rpx 24rpx;
    border-top: 1rpx solid $border-light;

    .interaction-btn {
      display: flex;
      align-items: center;
      gap: 8rpx;
      transition: transform 0.2s;

      &:active {
        transform: scale(0.95);
      }

      .action-icon {
        font-size: 32rpx;

        &.liked {
          animation: heartBeat 0.3s ease-out;
        }
      }

      .action-text {
        font-size: $font-size-sm;
        color: $text-secondary;
      }
    }
  }
}

@keyframes heartBeat {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.3); }
}
```

### 3. Pinterest 网格布局

```vue
<view class="pinterest-grid">
  <view
    class="grid-item"
    v-for="recipe in recipes"
    :key="recipe.id"
    @click="viewRecipe(recipe)"
  >
    <view class="item-image-wrapper">
      <image class="item-image" :src="recipe.image" mode="aspectFill" />
      <view class="image-badges">
        <view class="badge time">⏱️ {{ recipe.cooking_time }}分</view>
        <view class="badge difficulty">{{ recipe.difficulty }}</view>
      </view>
    </view>

    <view class="item-content">
      <text class="item-title">{{ recipe.name }}</text>
      <view class="item-meta">
        <image class="creator-avatar" :src="recipe.creator.avatar" mode="aspectFill" />
        <text class="creator-name">{{ recipe.creator.name }}</text>
      </view>

      <view class="item-actions">
        <view class="action-btn" @click.stop="toggleFavorite(recipe)">
          <text class="action-icon">{{ recipe.isFavorite ? '❤️' : '🤍' }}</text>
        </view>
        <view class="action-btn" @click.stop="addToCart(recipe)">
          <text class="action-icon">🛒</text>
        </view>
      </view>
    </view>
  </view>
</view>
```

**样式特点：**
- 双列网格布局
- 图片上方浮动徽章（时间、难度）
- 卡片下方显示标题、创建者、操作按钮
- 点击缩放效果

```scss
.pinterest-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16rpx;
  padding: 24rpx;

  .grid-item {
    background: white;
    border-radius: $radius-lg;
    overflow: hidden;
    box-shadow: $shadow-base;
    transition: all 0.3s;

    &:active {
      transform: scale(0.98);
      box-shadow: $shadow-sm;
    }

    .item-image-wrapper {
      position: relative;
      width: 100%;
      height: 320rpx;

      .item-image {
        width: 100%;
        height: 100%;
      }

      .image-badges {
        position: absolute;
        top: 12rpx;
        right: 12rpx;
        display: flex;
        flex-direction: column;
        gap: 8rpx;

        .badge {
          padding: 6rpx 12rpx;
          border-radius: $radius-button;
          backdrop-filter: blur(10rpx);
          font-size: $font-size-xs;
          font-weight: $font-weight-bold;
          color: white;

          &.time {
            background: rgba(255, 138, 101, 0.9);
          }

          &.difficulty {
            background: rgba(0, 0, 0, 0.5);
          }
        }
      }
    }

    .item-content {
      padding: 16rpx;

      .item-title {
        display: block;
        font-size: $font-size-base;
        font-weight: $font-weight-bold;
        color: $text-primary;
        margin-bottom: 12rpx;
        @include text-ellipsis(2);
      }

      .item-meta {
        display: flex;
        align-items: center;
        gap: 8rpx;
        margin-bottom: 12rpx;

        .creator-avatar {
          width: 32rpx;
          height: 32rpx;
          border-radius: 50%;
        }

        .creator-name {
          font-size: $font-size-xs;
          color: $text-secondary;
        }
      }

      .item-actions {
        display: flex;
        gap: 12rpx;

        .action-btn {
          flex: 1;
          height: 56rpx;
          border-radius: $radius-button;
          background: $bg-section;
          @include flex-center;
          transition: all 0.2s;

          &:active {
            transform: scale(0.95);
            background: $bg-hover;
          }

          .action-icon {
            font-size: 28rpx;
          }
        }
      }
    }
  }
}
```

### 4. 时间线布局（Facebook Timeline）

```vue
<scroll-view class="timeline-container" scroll-y>
  <view
    class="timeline-item"
    v-for="order in orders"
    :key="order.id"
  >
    <!-- 时间线节点 -->
    <view class="timeline-dot" :class="`status-${order.status}`">
      <text class="dot-icon">{{ getStatusIcon(order.status) }}</text>
    </view>

    <!-- 时间线内容卡片 -->
    <view class="timeline-card">
      <view class="card-header">
        <image class="user-avatar" :src="order.user.avatar" mode="aspectFill" />
        <view class="user-info">
          <text class="user-name">{{ order.user.name }}</text>
          <text class="order-time">{{ order.time }}</text>
        </view>
        <view class="status-badge">{{ order.statusText }}</view>
      </view>

      <view class="card-content">
        <text class="wish-text">{{ order.wishText }}</text>
        <view class="dish-photos">
          <image
            class="dish-photo"
            v-for="(dish, index) in order.dishes.slice(0, 3)"
            :key="index"
            :src="dish.image"
            mode="aspectFill"
          />
        </view>
      </view>

      <view class="card-footer">
        <text class="info-text">{{ order.dishCount }}道菜</text>
        <view class="action-btn" v-if="canRepeat(order)" @click="repeatOrder(order)">
          <text class="action-icon">🔄</text>
          <text class="action-text">再来一次</text>
        </view>
      </view>
    </view>
  </view>
</scroll-view>
```

**样式特点：**
- 左侧时间线节点（圆形 + emoji 图标）
- 节点之间的连接线（渐变色）
- 右侧卡片内容
- 不同状态使用不同颜色

```scss
.timeline-container {
  padding: 24rpx;

  .timeline-item {
    position: relative;
    padding-left: 80rpx;
    margin-bottom: 32rpx;

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

      // 连接线
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

    // 最后一个不显示连接线
    &:last-child .timeline-dot::after {
      display: none;
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

    // 时间线卡片
    .timeline-card {
      background: white;
      border-radius: $radius-lg;
      box-shadow: $shadow-base;
      overflow: hidden;
      transition: all 0.3s;

      &:active {
        transform: scale(0.98);
      }

      .card-header {
        display: flex;
        align-items: center;
        gap: 16rpx;
        padding: 20rpx 24rpx;

        .user-avatar {
          width: 64rpx;
          height: 64rpx;
          border-radius: 50%;
        }

        .user-info {
          flex: 1;

          .user-name {
            display: block;
            font-size: $font-size-base;
            font-weight: $font-weight-bold;
            color: $text-primary;
          }

          .order-time {
            font-size: $font-size-xs;
            color: $text-tertiary;
          }
        }

        .status-badge {
          padding: 6rpx 16rpx;
          border-radius: $radius-button;
          background: rgba(255, 138, 101, 0.15);
          font-size: $font-size-xxs;
          font-weight: $font-weight-bold;
          color: $primary;
        }
      }

      .card-content {
        padding: 16rpx 24rpx;

        .wish-text {
          display: block;
          font-size: $font-size-sm;
          color: $text-secondary;
          margin-bottom: 16rpx;
        }

        .dish-photos {
          display: flex;
          gap: 8rpx;

          .dish-photo {
            flex: 1;
            height: 200rpx;
            border-radius: $radius-md;
          }
        }
      }

      .card-footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 16rpx 24rpx;
        border-top: 1rpx solid $border-light;

        .info-text {
          font-size: $font-size-sm;
          color: $text-secondary;
        }

        .action-btn {
          display: flex;
          align-items: center;
          gap: 6rpx;
          padding: 8rpx 20rpx;
          border-radius: $radius-button;
          background: rgba(255, 138, 101, 0.1);
          transition: all 0.2s;

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
}
```

---

## 动画效果

### 点赞动画（心跳效果）

```scss
@keyframes heartBeat {
  0%, 100% {
    transform: scale(1);
  }
  25% {
    transform: scale(1.3);
  }
  50% {
    transform: scale(1.1);
  }
  75% {
    transform: scale(1.25);
  }
}

.action-icon.liked {
  animation: heartBeat 0.5s ease-out;
}
```

### 卡片按压效果

```scss
.card, .button, .action-btn {
  transition: all 0.2s ease-out;

  &:active {
    transform: scale(0.98);
    box-shadow: $shadow-sm;
  }
}
```

### 加载动画

```scss
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.loading-spinner {
  width: 60rpx;
  height: 60rpx;
  border-radius: 50%;
  border: 4rpx solid $bg-section;
  border-top-color: $primary;
  animation: spin 0.8s linear infinite;
}
```

### 淡入动画

```scss
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(20rpx);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.fade-in {
  animation: fadeIn 0.3s ease-out;
}
```

---

## 交互规范

### 触摸反馈

1. **按压缩放** - 所有可点击元素按压时缩小至 0.95-0.98
2. **颜色变化** - 悬停/按压时背景色稍微加深
3. **阴影变化** - 按压时阴影减小

### 手势操作

1. **下拉刷新** - 所有列表页支持下拉刷新
2. **横向滑动** - Stories、分类标签支持横向滑动
3. **长按操作** - 卡片长按显示更多操作选项

### 加载状态

1. **骨架屏** - 首次加载时显示占位符
2. **加载动画** - 使用旋转动画表示加载中
3. **加载更多** - 列表底部显示"加载更多"按钮

---

## 页面布局结构

### 首页（Instagram Feed 风格）

```
┌─────────────────────────────────┐
│  💭 美食心愿        🔍 ➕       │ ← 顶部导航栏
├─────────────────────────────────┤
│ ○ ○ ○ ○ ○ →                    │ ← Stories 横向滚动
├─────────────────────────────────┤
│ 🍳 🥗 🍝 🍰 全部 →               │ ← 分类筛选（chips）
├─────────────────────────────────┤
│  👤 张三                     ⋯ │
│  想吃这道菜～                   │
│  ┌───────────────────────────┐ │
│  │                           │ │
│  │       [菜品图片]          │ │ ← 动态卡片
│  │                           │ │
│  └───────────────────────────┘ │
│  ❤️ 5  💬 2  📤                │
├─────────────────────────────────┤
│  [更多动态卡片...]             │
└─────────────────────────────────┘
```

### 菜谱页（Pinterest Grid 风格）

```
┌─────────────────────────────────┐
│  📖 菜谱大全        🔍 ➕       │ ← 顶部导航栏
├─────────────────────────────────┤
│  [搜索框: 搜索菜谱...]          │ ← 搜索栏
├─────────────────────────────────┤
│ 🍳 家常菜  🥗 沙拉  🍝 面食 →   │ ← 分类筛选
├─────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐    │
│  │  [图片]  │  │  [图片]  │    │
│  │  宫保鸡丁 │  │  番茄炒蛋 │    │
│  │  👤 张三  │  │  👤 李四  │    │
│  │  🤍  🛒  │  │  ❤️  🛒  │    │ ← 双列网格
│  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐    │
│  │  [图片]  │  │  [图片]  │    │
│  │  红烧肉   │  │  清蒸鱼   │    │
│  └──────────┘  └──────────┘    │
└─────────────────────────────────┘
```

### 订单页（Timeline 风格）

```
┌─────────────────────────────────┐
│  💭 美食心愿        🔍          │ ← 顶部导航栏
├─────────────────────────────────┤
│ 全部 💭想吃 👨‍🍳在做 🔔做好啦 →  │ ← 状态筛选
├─────────────────────────────────┤
│  ●─┬─────────────────────────┐  │
│    │ 👤 张三          💭想吃  │  │
│    │ 张三想吃这些～           │  │
│    │ [菜品照片] [菜品照片]    │  │
│  | │ 3道菜  🔄 再来一次       │  │
│  | └─────────────────────────┘  │
│  |                              │
│  ●─┬─────────────────────────┐  │ ← 时间线布局
│    │ 👤 李四        👨‍🍳在做   │  │
│    │ 正在为李四准备中❤️        │  │
│    │ [菜品照片] [菜品照片]    │  │
│  | │ 2道菜                    │  │
│  | └─────────────────────────┘  │
│  |                              │
│  ●─┬─────────────────────────┐  │
│    │ 👤 王五        🔔做好啦  │  │
│    │ 王五的美食做好啦🎉       │  │
│    └─────────────────────────┘  │
└─────────────────────────────────┘
```

---

## Emoji 使用规范

### 功能性 Emoji

```scss
// 状态类
💭 想吃（pending）
👨‍🍳 在做（cooking）
🔔 做好啦（completed）
❌ 已取消（cancelled）
✅ 确认

// 操作类
🔍 搜索
➕ 添加
🔄 重复/再来一次
❤️ 喜欢/收藏
🤍 未收藏
💬 评论
📤 分享
🛒 加入购物车

// 分类类
🍳 家常菜
🥗 沙拉
🍝 面食
🍰 甜点
🥘 炖菜
🍲 汤类

// 提示类
😋 好吃
😍 超赞
👍 点赞
💯 满分
🔥 热门
⭐ 收藏
```

### Emoji 使用原则

1. **功能明确** - 每个 emoji 对应特定功能
2. **适度使用** - 不过度使用，保持简洁
3. **统一语义** - 同一 emoji 在不同场景保持相同含义
4. **视觉平衡** - emoji 大小与周围文字协调

---

## 响应式设计

### 屏幕适配

```scss
// 小屏幕（iPhone SE）
@media screen and (max-width: 375px) {
  .pinterest-grid {
    gap: 12rpx;
  }

  .feed-card .card-content .content-image {
    height: 400rpx;
  }
}

// 大屏幕（iPhone Pro Max）
@media screen and (min-width: 430px) {
  .pinterest-grid {
    gap: 20rpx;
  }

  .feed-card .card-content .content-image {
    height: 600rpx;
  }
}
```

### 安全区域适配

```scss
// iOS 刘海屏适配
.page-container {
  padding-top: constant(safe-area-inset-top);
  padding-top: env(safe-area-inset-top);
  padding-bottom: constant(safe-area-inset-bottom);
  padding-bottom: env(safe-area-inset-bottom);
}

// 底部导航栏适配
.tab-bar {
  padding-bottom: calc(var(--status-bar-height) + 20rpx);
}
```

---

## 性能优化

### 图片优化

1. **懒加载** - 使用 `lazy-load` 属性
2. **压缩格式** - 使用 WebP 格式
3. **缩略图** - 列表中使用缩略图
4. **占位符** - 加载前显示模糊占位图

```vue
<image
  class="recipe-image"
  :src="recipe.thumbnail"
  lazy-load
  mode="aspectFill"
/>
```

### 列表优化

1. **虚拟滚动** - 长列表使用虚拟滚动
2. **分页加载** - 每次加载 20 条数据
3. **节流防抖** - 搜索输入使用防抖

### 动画优化

1. **GPU 加速** - 使用 `transform` 和 `opacity`
2. **避免重排** - 不改变布局的动画
3. **控制帧率** - 动画控制在 60fps

---

## 可访问性

### 语义化

```vue
<!-- 使用语义化的类名和结构 -->
<view role="button" aria-label="添加到购物车" @click="addToCart">
  <text class="btn-icon">🛒</text>
  <text class="btn-text">加入订单</text>
</view>
```

### 对比度

- 确保文本与背景对比度至少 4.5:1
- 重要按钮使用高对比度颜色
- 禁用状态使用低对比度

### 触摸目标

- 所有可点击元素最小尺寸 88rpx × 88rpx
- 按钮之间保持足够间距（至少 16rpx）

---

## 开发工具和资源

### SCSS Mixins

```scss
// 使用设计系统
@use '@/styles/design-system.scss' as *;

// Flex 居中
@include flex-center;

// 文本省略
@include text-ellipsis(2); // 2行省略

// 点击缩放
@include tap-scale;
```

### 设计系统文件

- **主文件**：`frontend/src/styles/design-system.scss`
- **使用方式**：在每个 `.vue` 文件的 `<style>` 中引入

```vue
<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.my-component {
  background: $gradient-primary;
  padding: $spacing-lg;
  border-radius: $radius-lg;
  box-shadow: $shadow-base;
}
</style>
```

---

## 设计检查清单

在完成设计后，使用此清单验证：

### 视觉一致性
- [ ] 所有圆角使用设计系统定义的值
- [ ] 所有间距是 8rpx 的倍数
- [ ] 所有颜色来自设计系统
- [ ] 所有阴影使用统一规范

### 交互体验
- [ ] 所有按钮有按压反馈
- [ ] 所有列表支持下拉刷新
- [ ] 所有卡片有点击效果
- [ ] 加载状态有明确提示

### 性能优化
- [ ] 图片使用懒加载
- [ ] 长列表使用分页
- [ ] 动画使用 GPU 加速
- [ ] 无不必要的重绘

### 可访问性
- [ ] 触摸目标足够大
- [ ] 颜色对比度符合标准
- [ ] 重要操作有文字说明
- [ ] 支持语义化标签

---

## 总结

Love Order 的社交互动风格设计系统融合了三大社交平台的精髓：

- **Instagram Stories** - 动态感、社交感、视觉冲击力
- **Pinterest Grid** - 美食照片优先、瀑布流布局、收藏互动
- **Facebook Timeline** - 时间叙事、连接感、状态流转

通过统一的色彩系统、字体规范、间距原则和组件设计，打造一个温馨有趣、充满互动性的家庭美食社交平台。
