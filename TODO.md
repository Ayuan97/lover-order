# Love Order 待完成功能清单

> 最后更新时间：2025-10-17
>
> 项目完成度：~75%（社交互动风格重设计已完成）

---

## 🎨 社交互动风格重设计 - 已完成 ✅

### 设计系统升级（2025-10-17 完成）

- ✅ **删除旧设计文档** - UI_DESIGN_SYSTEM.md 已删除
- ✅ **创建新设计文档** - SOCIAL_DESIGN_SYSTEM.md（30KB 完整设计规范）
- ✅ **更新项目文档** - CLAUDE.md 已更新社交风格说明

### 核心页面重设计（Instagram + Pinterest + Facebook 风格）

#### ✅ 首页 - Instagram Feed 风格
**文件：** `frontend/src/pages/index/index.vue`

完成功能：
- ✅ Stories 动态条（圆形头像 + 渐变边框）
- ✅ 横向滚动，添加动态按钮
- ✅ 分类筛选 Chips（横向滚动）
- ✅ 社交动态卡片流（Feed）
- ✅ 用户头像 + 昵称 + 时间戳
- ✅ 点赞、评论、分享互动按钮
- ✅ 心跳动画效果
- ✅ 下拉刷新

#### ✅ 菜谱页 - Pinterest Grid 风格
**文件：** `frontend/src/pages/recipes/index.vue`

完成功能：
- ✅ 双列响应式网格布局
- ✅ 图片优先的卡片设计
- ✅ 浮动标签（烹饪时间、难度）
- ✅ 创建者信息显示
- ✅ 快速操作（❤️ 收藏、🛒 加购物车）
- ✅ 搜索栏和分类筛选
- ✅ 点击缩放反馈
- ✅ 下拉刷新

#### ✅ 订单页 - Facebook Timeline 风格
**文件：** `frontend/src/pages/orders/index.vue`

完成功能：
- ✅ 时间线布局（左侧节点 + 右侧卡片）
- ✅ 圆形状态节点（💭 想吃、👨‍🍳 在做、🔔 做好啦）
- ✅ 节点之间渐变连接线
- ✅ 不同状态不同颜色
- ✅ 用户头像 + 状态徽章
- ✅ 温馨心愿文字（"Ta想吃这些～"）
- ✅ 菜品照片网格（最多3张）
- ✅ 🔄 再来一次功能
- ✅ 状态筛选 Chips
- ✅ 下拉刷新

#### ✅ 其他页面设计系统对齐
**文件：** `frontend/src/pages/family/index.vue`
- ✅ 使用设计系统变量（`@use` 语法）
- ✅ 统一圆角、间距、阴影

**文件：** `frontend/src/pages/orders/detail.vue`
- ✅ Sass 现代语法更新

**文件：** `frontend/src/pages/orders/create.vue`
- ✅ Sass 现代语法更新

**文件：** `frontend/src/pages/recipes/detail.vue`
- ✅ Sass 现代语法更新

**文件：** `frontend/src/pages/recipes/add.vue`
- ✅ Sass 现代语法更新

### 设计规范文档

✅ **SOCIAL_DESIGN_SYSTEM.md** - 完整的社交互动风格设计系统
- 设计灵感来源（Instagram/Pinterest/Facebook）
- 色彩系统（包含 Instagram 渐变）
- 字体、间距、圆角、阴影系统
- 核心组件设计和代码示例
- Stories 动态条、社交卡片、网格布局、时间线
- 社交互动元素（点赞动画、按压反馈）
- 页面布局结构图
- Emoji 使用规范
- 响应式设计、性能优化指南

---

## 📊 完成度统计

| 模块 | 完成度 | 优先级 | 状态 |
|------|--------|--------|------|
| UI 设计系统 | 100% | ⭐⭐⭐⭐⭐ | ✅ 已完成 |
| 首页（Feed） | 95% | ⭐⭐⭐⭐⭐ | ✅ 基本完成 |
| 菜谱页（Grid） | 90% | ⭐⭐⭐⭐⭐ | ✅ 基本完成 |
| 订单页（Timeline） | 85% | ⭐⭐⭐⭐⭐ | ✅ 基本完成 |
| 菜谱详情 | 80% | ⭐⭐⭐⭐ | 部分完成 |
| 订单详情 | 80% | ⭐⭐⭐⭐ | 部分完成 |
| 创建订单 | 75% | ⭐⭐⭐⭐ | 部分完成 |
| 家庭管理 | 80% | ⭐⭐⭐ | 部分完成 |
| 访客功能 | 70% | ⭐⭐⭐ | 部分完成 |
| 个人中心 | 60% | ⭐⭐ | 部分完成 |

---

## 🔥 高优先级功能（待完善）

### 1. 聚会模式完整功能 ⭐⭐⭐⭐⭐

**当前状态：** 需要重构，改为手动开关聚会模式

**文件：** `frontend/src/pages/index/index.vue`, `frontend/src/pages/profile/index.vue`

**设计目标：** 手动开启聚会模式，而非自动判断人数

#### 1.1 个人中心 - 聚会模式开关 ⭐⭐⭐⭐⭐
**文件：** `frontend/src/pages/profile/index.vue`

**功能需求：**
- ❌ 添加"聚会模式"开关 UI
- ❌ 开关状态保存到后端（或本地）
- ❌ 开关状态变化时刷新首页
- ❌ 聚会模式说明文案
  - "开启后可以邀请朋友来点餐"
  - "访客可以上传图片+文字点餐"

**UI 设计：**
```
个人中心
  ↓
┌────────────────────┐
│ 🎉 聚会模式        │
│ [开关]  关闭/开启   │
│                    │
│ 💡 开启后可以邀请   │
│    朋友来点餐      │
└────────────────────┘
```

#### 1.2 首页模式切换逻辑 ⭐⭐⭐⭐⭐
**文件：** `frontend/src/pages/index/index.vue`

**当前状态：**
- ✅ 情侣模式 UI 已完成（couple-home）
- ✅ 聚会模式 UI 已完成（party-home）
- ❌ displayMode 逻辑需要改为检查开关状态

**修改内容：**
```typescript
// 旧逻辑：根据成员数量自动判断
const displayMode = computed(() => {
  const memberCount = members.value.filter(m => m.role !== 'guest').length
  const hasGuests = members.value.some(m => m.role === 'guest')

  if (hasGuests) return 'party'
  if (memberCount === 2) return 'couple'
  return 'family'
})

// 新逻辑：检查聚会模式开关
const displayMode = computed(() => {
  // 读取聚会模式开关状态
  const partyModeEnabled = getPartyModeStatus()

  if (partyModeEnabled) {
    return 'party'  // 聚会模式：Instagram Feed 风格
  } else {
    return 'couple' // 日常模式：简洁温馨风格
  }
})
```

待实现：
- ❌ 修改 displayMode 计算逻辑
- ❌ 添加聚会模式状态读取
- ❌ 聚会模式开启时显示邀请按钮
- ❌ 聚会模式关闭时隐藏访客相关功能

#### 1.3 访客图片点餐功能 ⭐⭐⭐⭐⭐
**文件：** `frontend/src/pages/orders/create.vue`（需要增强）

**功能需求：**
访客可以不从菜谱选择，直接上传图片+文字点餐

**流程设计：**
```
访客点击"发布心愿"
  ↓
┌─────────────────────┐
│ 📷 上传美食图片      │
│ [选择图片] [拍照]    │
│                     │
│ 💬 描述你想吃的      │
│ [文本输入框]         │
│                     │
│ 🕐 用餐时间（可选）  │
│                     │
│ [发布心愿] 按钮      │
└─────────────────────┘
```

待实现：
- ❌ 创建订单页面添加"图片点餐"选项
- ❌ 图片上传组件（支持多图）
- ❌ 文字描述输入框
- ❌ 后端API：支持图片订单（order.images 字段）
- ❌ 首页 Feed 展示：优先显示图片而非菜谱图片

**后端数据结构：**
```go
// Order 订单表添加字段
type Order struct {
    // ... 其他字段
    Images string `json:"images"` // JSON数组，存储图片URL
    IsImageOrder bool `json:"is_image_order"` // 是否为图片订单
}
```

#### 1.4 聚餐总结功能 ⭐⭐⭐⭐
**新页面：** `frontend/src/pages/party/summary.vue`

**功能需求：**
聚餐结束后，所有参与者可以：
1. 评论这次聚餐
2. 上传聚餐照片
3. 分享聚餐感受

**页面设计：**
```
┌──────────────────────┐
│ 🎉 聚餐总结           │
│                      │
│ 📅 2025年10月17日    │
│ 👥 5位朋友参与       │
├──────────────────────┤
│ 📸 聚餐照片墙        │
│ [照片网格展示]       │
│ [+ 添加照片]         │
├──────────────────────┤
│ 💬 大家的评论        │
│                      │
│ 👤 小明：今天的菜...  │
│ 👤 小红：超级好吃...  │
│                      │
│ [发表评论]           │
└──────────────────────┘
```

待实现：
- ❌ 创建聚餐总结页面
- ❌ 聚餐总结数据模型（PartyEvent）
- ❌ 照片上传和展示
- ❌ 评论列表和发表评论
- ❌ 结束聚会时自动创建总结
- ❌ 从"我的"页面查看历史聚餐

**后端数据结构：**
```go
// PartyEvent 聚餐活动表
type PartyEvent struct {
    ID          uint      `json:"id"`
    FamilyID    uint      `json:"family_id"`
    Title       string    `json:"title"`        // 聚餐标题
    Description string    `json:"description"`  // 描述
    EventDate   time.Time `json:"event_date"`   // 聚餐日期
    Images      string    `json:"images"`       // 照片JSON数组
    Participants string   `json:"participants"` // 参与者ID JSON数组
    CreatedAt   time.Time `json:"created_at"`
}

// PartyComment 聚餐评论表
type PartyComment struct {
    ID       uint      `json:"id"`
    EventID  uint      `json:"event_id"`
    UserID   uint      `json:"user_id"`
    Content  string    `json:"content"`
    Images   string    `json:"images"`  // 评论附带的图片
    CreatedAt time.Time `json:"created_at"`
}
```

#### 1.5 访客邀请系统 ⭐⭐⭐⭐
**当前状态：** 部分完成

**已完成：**
- ✅ 访客加入页面（`/pages/guest/join.vue`）
- ✅ 邀请弹窗 UI
- ✅ 邀请码生成 API

**待完成：**
主人侧：
- ✅ 邀请弹窗（已实现）
- ✅ 生成邀请码 API（已对接）
- ✅ 复制/分享邀请码（已实现）
- ❌ 查看已加入访客列表
- ❌ 结束聚会功能（同时创建聚餐总结）
- ❌ 只在聚会模式开启时显示邀请按钮

访客侧：
- ✅ 访客加入页面 UI（已实现）
- ❌ 邀请码验证 API 对接
- ❌ 输入昵称注册 API 对接
- ❌ 24小时自动退出机制

---

### 2. 菜谱页功能完善 ⭐⭐⭐⭐⭐

**当前状态：** 90% 完成，UI 完美，待数据对接

**文件：** `frontend/src/pages/recipes/index.vue`

**待完善任务：**

#### 2.1 数据加载优化
- ✅ 网格布局完成
- ✅ 搜索和筛选 UI 完成
- ❌ 真实 API 数据加载（当前使用 Mock）
- ❌ 搜索防抖优化
- ❌ 分类筛选后端对接
- ❌ 分页加载实现

#### 2.2 收藏功能
- ✅ 收藏 UI 和动画完成（❤️ 心跳动画）
- ❌ 收藏 API 对接
- ❌ 收藏状态持久化
- ❌ 我的收藏页面

#### 2.3 加入购物车优化
- ✅ 添加购物车 UI 完成
- ✅ 本地存储实现
- ❌ 购物车数量徽章显示
- ❌ 购物车详情弹窗（见 3.1）

---

### 3. 订单页功能完善 ⭐⭐⭐⭐⭐

**当前状态：** 85% 完成，时间线 UI 完美

**文件：** `frontend/src/pages/orders/index.vue`

**待完善任务：**

#### 3.1 订单列表数据对接
- ✅ 时间线布局完成
- ✅ 状态筛选 UI 完成
- ✅ 温馨文字展示完成
- ❌ 真实订单数据加载（API 对接）
- ❌ 状态统计数量显示
- ❌ 分页加载

#### 3.2 订单操作功能
- ✅ "再来一次" UI 和逻辑完成
- ✅ 取消订单 UI 完成
- ❌ API 对接
  - 重复下单 API
  - 取消订单 API
  - 状态更新 API

#### 3.3 管理员操作（做饭人）
- ✅ 状态转换 UI（pending → cooking → completed）
- ❌ 管理员权限判断
- ❌ "开始做" API 对接
- ❌ "做好啦" API 对接
- ❌ 通知点餐人

---

### 4. 购物车详情弹窗 ⭐⭐⭐⭐

**当前状态：** 50% 完成

**待完成任务：**

#### 4.1 购物车弹窗 UI
- ❌ 底部抽屉式弹窗
- ❌ 菜品列表展示
- ❌ 数量增减按钮（+ / -）
- ❌ 删除单个菜品
- ❌ 清空购物车
- ❌ 总计显示
- ❌ "去下单" 按钮

**UI 设计要求：**
- 从底部滑出动画
- 圆角顶部（20rpx）
- 白色背景 + 阴影
- 关闭按钮（X）

---

## 🎯 中优先级功能

### 5. 菜谱详情页增强 ⭐⭐⭐⭐

**文件：** `frontend/src/pages/recipes/detail.vue`

**当前状态：** 80% 完成，基础功能已实现

**待完善任务：**

#### 5.1 社交互动元素
- ✅ 收藏功能 UI
- ✅ 添加购物车功能
- ❌ 点赞功能（给菜谱点赞）
- ❌ 评论功能
  - 评论列表展示
  - 发表评论
  - 回复评论
- ❌ 分享功能
  - 分享到微信好友
  - 分享到朋友圈
  - 生成分享海报

#### 5.2 创作者信息增强
- ✅ 创作者头像和名称显示
- ❌ 点击查看创作者主页
- ❌ 关注创作者功能
- ❌ 创作者其他菜谱推荐

---

### 6. 订单详情页完善 ⭐⭐⭐⭐

**文件：** `frontend/src/pages/orders/detail.vue`

**当前状态：** 80% 完成

**待完善任务：**

#### 6.1 评价功能
- ✅ 评价弹窗 UI（星级、表情、留言）
- ✅ 提交评价逻辑
- ❌ API 对接
- ❌ 评价展示优化
- ❌ 图片评价功能

#### 6.2 订单操作优化
- ✅ 管理员状态转换 UI
- ✅ 取消订单功能
- ❌ 订单分享功能
- ❌ 订单打印功能（可选）

---

### 7. 创建订单页面完善 ⭐⭐⭐⭐

**文件：** `frontend/src/pages/orders/create.vue`

**当前状态：** 75% 完成

**待完善任务：**

#### 7.1 购物车展示优化
- ✅ 购物车菜品列表
- ✅ 菜品缩略图展示
- ❌ 编辑菜品数量（跳转回购物车弹窗）
- ❌ 删除菜品功能

#### 7.2 下单体验优化
- ✅ 用餐时间选择
- ✅ 订单备注
- ❌ 预计烹饪时间计算
- ❌ 下单按钮状态优化
- ❌ 下单成功动画

---

### 8. 添加菜谱页面完善 ⭐⭐⭐

**文件：** `frontend/src/pages/recipes/add.vue`

**当前状态：** 已存在，待测试和优化

**待完善任务：**

#### 8.1 图片上传优化
- ✅ 图片选择 UI
- ❌ 图片压缩
- ❌ 图片裁剪
- ❌ 多图上传（步骤图）

#### 8.2 表单验证
- ✅ 基础表单验证
- ❌ 实时验证反馈
- ❌ 错误提示优化

---

## 💡 低优先级功能

### 9. 家庭管理功能增强 ⭐⭐⭐

**文件：** `frontend/src/pages/family/index.vue`

**待完成：**
- ❌ 编辑家庭信息弹窗
- ❌ 上传家庭头像
- ❌ 隐私设置页面
- ❌ 通知设置页面
- ❌ 成员权限管理

---

### 10. 个人中心功能 ⭐⭐

**文件：** `frontend/src/pages/profile/index.vue`

**待完成：**
- ❌ 我的收藏列表页（`/pages/favorites/index.vue`）
- ❌ 我的菜谱列表
- ❌ 个人信息编辑
- ❌ 修改昵称和头像
- ❌ 个人主页（展示创作内容）

---

### 11. 搜索功能增强 ⭐⭐

**待完成：**
- ❌ 全局搜索页面（`/pages/search/index.vue`）
- ❌ 搜索历史记录
- ❌ 搜索建议（热门搜索）
- ❌ 搜索结果页（菜谱 + 用户）
- ❌ 搜索过滤器（分类、难度、时间）

---

### 12. 通知功能 ⭐⭐

**待完成：**
- ❌ 通知列表页面（`/pages/notifications/index.vue`）
- ❌ 通知红点显示
- ❌ 通知类型：
  - 订单状态变化
  - 新评论
  - 新点赞
  - 新关注
  - 家庭邀请

---

## 📋 实施计划（更新）

### ✅ 第零阶段：设计系统重构（已完成）
- ✅ 删除旧设计文档
- ✅ 创建社交互动风格设计文档
- ✅ 更新 CLAUDE.md
- ✅ 首页 Instagram Feed 风格重设计
- ✅ 菜谱页 Pinterest Grid 风格重设计
- ✅ 订单页 Facebook Timeline 风格重设计
- ✅ 其他页面设计系统对齐

### 🔥 第一阶段：聚会模式核心功能（当前阶段）

**预计时间：** 2-3 天

**任务列表：**
1. ⏳ 个人中心 - 聚会模式开关
   - 添加开关 UI
   - 状态保存（优先本地存储，后续对接后端）
   - 开关变化时通知首页刷新

2. ⏳ 首页模式切换逻辑重构
   - 修改 displayMode 计算逻辑
   - 读取聚会模式开关状态
   - 测试两种模式切换

3. ⏳ 访客图片点餐功能
   - 创建订单页面添加图片上传选项
   - 后端 Order 模型添加 images 字段
   - 首页 Feed 适配图片订单展示

4. ⏳ 聚餐总结页面
   - 创建 PartyEvent 和 PartyComment 数据模型
   - 实现聚餐总结页面 UI
   - 照片墙和评论功能

### 第二阶段：数据 API 对接

**预计时间：** 2-3 天

**任务列表：**
5. 菜谱页数据 API 对接
   - 菜谱列表真实数据
   - 搜索和筛选 API
   - 收藏功能 API

6. 订单页数据 API 对接
   - 订单列表真实数据（已完成基础）
   - 状态筛选和统计
   - 订单操作 API

7. 购物车详情弹窗实现

8. 访客邀请系统后端对接
   - 邀请码验证 API
   - 访客注册 API
   - 24小时自动退出机制

### 第三阶段：社交互动功能增强

**预计时间：** 2-3 天

**任务列表：**
9. 菜谱详情社交互动（点赞、评论、分享）
10. 订单详情评价功能完善
11. 创建订单体验优化
12. 添加菜谱功能测试和优化

### 第四阶段：辅助功能完善

**预计时间：** 1-2 天

**任务列表：**
13. 家庭管理功能增强
14. 个人中心功能完善
15. 搜索功能实现
16. 通知功能实现

---

## 📝 开发规范提醒（更新）

在实现这些功能时，请严格遵循社交互动风格设计系统：

### 社交互动风格设计原则

1. **社交感优先** - 让每个功能都像社交互动
2. **视觉优先** - 美食照片是核心，图片大而清晰
3. **情感化语言** - 用温馨的文字传递爱意
4. **即时反馈** - 所有交互都有动画和视觉反馈
5. **简化流程** - 去除冗余状态，保持简洁流畅

### 设计系统变量使用

**引入方式（现代 Sass 语法）：**
```vue
<style lang="scss" scoped>
@use '@/styles/design-system.scss' as *;

.my-component {
  background: $gradient-primary;
  padding: $spacing-lg;
  border-radius: $radius-lg;
}
</style>
```

**核心变量：**
```scss
// 颜色
$primary: #FF8A65;              // 珊瑚橙
$gradient-primary: linear-gradient(135deg, #FF8A65 0%, #FF7043 100%);
$instagram-gradient: linear-gradient(...);  // Instagram 渐变边框

// 圆角
$radius-lg: 20rpx;              // 卡片圆角
$radius-button: 48rpx;          // 按钮圆角
$radius-round: 50%;             // 圆形头像

// 间距（8rpx 倍数）
$spacing-xs: 8rpx;
$spacing-base: 24rpx;
$spacing-lg: 32rpx;

// 阴影
$shadow-base: 0 4rpx 12rpx rgba(0, 0, 0, 0.08);
$shadow-primary: 0 8rpx 24rpx rgba(255, 138, 101, 0.4);
```

### 社交互动组件使用

**Stories 动态条：**
```vue
<scroll-view class="stories-container" scroll-x>
  <view class="story-item" :class="{ 'has-story': member.hasStory }">
    <view class="story-avatar">
      <image :src="member.avatar" mode="aspectFill" />
    </view>
    <text class="story-name">{{ member.name }}</text>
  </view>
</scroll-view>
```

**Pinterest 网格卡片：**
```vue
<view class="pinterest-grid">
  <view class="grid-item">
    <view class="item-image-wrapper">
      <image :src="recipe.image" mode="aspectFill" />
      <view class="image-badges">
        <view class="badge time">⏱️ {{ recipe.cooking_time }}分</view>
      </view>
    </view>
    <view class="item-actions">
      <view class="action-btn" @click="toggleFavorite">
        <text class="action-icon">{{ isFavorite ? '❤️' : '🤍' }}</text>
      </view>
    </view>
  </view>
</view>
```

**Timeline 时间线：**
```vue
<view class="timeline-item">
  <view class="timeline-dot" :class="`status-${order.status}`">
    <text class="dot-icon">{{ getStatusIcon(order.status) }}</text>
  </view>
  <view class="timeline-card">
    <!-- 卡片内容 -->
  </view>
</view>
```

### 动画效果

**心跳动画（点赞）：**
```scss
@keyframes heartBeat {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.3); }
}

.action-icon.liked {
  animation: heartBeat 0.5s ease-out;
}
```

**按压缩放：**
```scss
.card, .button {
  transition: all 0.2s ease-out;

  &:active {
    transform: scale(0.98);
  }
}
```

### 代码规范

- ✅ 所有文本使用中文
- ✅ 使用温馨的语言（"想吃"、"在做"、"做好啦"）
- ✅ 添加简洁有效的注释
- ✅ 不留 TODO 或占位符
- ✅ 完整的错误处理
- ✅ 加载状态显示
- ✅ 使用 Emoji 增强情感表达

---

## ✅ 完成标准

每个功能完成时需要确保：

1. **功能完整**：所有需求点都已实现
2. **社交风格统一**：符合 Instagram/Pinterest/Facebook 设计风格
3. **视觉优先**：图片展示大而清晰
4. **情感化交互**：温馨的文字和 Emoji
5. **即时反馈**：所有操作有动画和提示
6. **错误处理**：有完整的错误处理和提示
7. **用户体验**：加载状态、动画过渡流畅
8. **代码质量**：有注释、无 TODO、无硬编码
9. **测试通过**：基本功能测试无问题

---

## 📚 参考文档

- **设计系统文档：** `SOCIAL_DESIGN_SYSTEM.md`
- **项目文档：** `CLAUDE.md`
- **设计变量：** `frontend/src/styles/design-system.scss`

**已实现页面参考：**
- 首页：`frontend/src/pages/index/index.vue`
- 菜谱页：`frontend/src/pages/recipes/index.vue`
- 订单页：`frontend/src/pages/orders/index.vue`

---

**当前进度：** 第一阶段 - 聚会模式核心功能
**下一步：**
1. 在个人中心添加聚会模式开关
2. 修改首页 displayMode 逻辑
3. 实现访客图片点餐功能
4. 创建聚餐总结页面
