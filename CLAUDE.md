# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Love Order 是一个温馨的情侣/家庭点餐微信小程序。

**核心定位：**
这不是一个商业化的点餐系统，而是一个充满爱意的家庭互动工具。主要场景包括：
- 👫 **情侣日常**：一方想吃什么，另一方看到后为TA准备
- 👨‍👩‍👧‍👦 **家庭互动**：家人之间分享美食愿望，互相烹饪
- 🏠 **朋友来访**：偶尔有朋友来家里做客时临时点餐

**设计理念：**
- ❤️ **温馨互动**：不是冰冷的订单管理，而是充满爱的美食分享
- 😊 **简单自然**：去除繁琐的商业化流程，让点餐和做饭都变得轻松有趣
- 💕 **情感连接**：通过食物传递爱意，记录美好的共餐时光

**技术栈：**
- 前端：uni-app + Vue 3 + TypeScript
- 后端：Go + Gin + GORM
- 数据库：MySQL 8.0+
- 认证：JWT + 微信小程序登录

## 常用命令

### 后端（Go）

```bash
cd backend

# 安装依赖
go mod tidy

# 启动服务（端口 8081）
go run cmd/main.go

# 初始化数据库（测试数据）
go run cmd/init_data.go

# 强制迁移数据库（删除重建，会丢失数据）
go run cmd/force_migrate.go

# 检查用户数据
go run cmd/check_user_data.go

# 添加丰富测试数据
go run cmd/add_rich_data.go
```

### 前端（uni-app）

```bash
cd frontend

# 安装依赖
npm install

# 开发微信小程序
npm run dev

# 构建微信小程序
npm run build
```

### 数据库

```bash
# 使用 SQL 文件初始化
mysql -u root -p < init_database.sql

# 或手动创建数据库
mysql -u root -p -e "CREATE DATABASE love_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## 架构说明

### 后端架构

**入口：** `backend/cmd/main.go` - 配置 Gin 服务器、中间件和路由

**分层结构：**
- `internal/api/` - HTTP 处理器（authHandler、recipeHandler、orderHandler 等）
- `internal/service/` - 业务逻辑层
- `internal/model/` - 数据库模型和 GORM 操作
- `internal/middleware/` - 认证、管理员、家庭成员中间件
- `internal/config/` - 配置加载（使用 Viper）
- `pkg/` - 共享工具（jwt、wechat）

**主要 API 路由：**
- `/api/v1/auth` - 微信登录、刷新令牌、登出（无需认证）
- `/api/v1/guest` - 访客注册和邀请码验证（无需认证）
- `/api/v1/dev` - 开发测试接口（无需认证）
- `/api/v1/user` - 用户资料（需要认证）
- `/api/v1/admin` - 管理员操作（需要认证 + 管理员权限）
- `/api/v1/recipes` - 菜谱 CRUD（需要认证 + 家庭成员）
- `/api/v1/categories` - 分类管理（需要认证 + 家庭成员）
- `/api/v1/orders` - 订单管理（需要认证 + 家庭成员）
- `/api/v1/family` - 家庭操作（需要认证）

**中间件链：**
1. `AuthMiddleware()` - 验证 JWT token，设置用户上下文
2. `FamilyMemberMiddleware()` - 确保用户属于某个家庭
3. `AdminMiddleware()` - 确保用户具有管理员角色

**数据库连接：**
- `model.InitDB()` 从 `config.yaml` 加载配置并初始化 GORM
- `model.AutoMigrate()` 按依赖顺序创建/更新表
- 连接池参数在 config.yaml 中配置

### 前端架构

**入口：** `frontend/src/main.ts`

**页面结构：**
- `pages/login/` - 微信登录流程
- `pages/index/` - 首页，浏览菜谱
- `pages/recipes/` - 菜谱管理
- `pages/orders/` - 订单历史和管理
- `pages/profile/` - 用户资料
- `pages/family/` - 家庭管理
- `pages/guest/` - 访客点餐和分享

**API 层：**
- `src/api/config.ts` - API 基础 URL 配置
- `src/api/request.ts` - Axios 封装和拦截器
- `src/api/auth.ts` - 认证接口
- `src/api/recipe.ts` - 菜谱接口
- `src/api/family.ts` - 家庭接口
- `src/api/mockData.ts` - 开发用 Mock 数据

**路由配置：**
- 在 `src/pages.json` 中配置
- TabBar 导航：首页、菜谱、订单、我的

**UI 设计系统：**
- 详细设计规范：`SOCIAL_DESIGN_SYSTEM.md`
- SCSS 变量文件：`frontend/src/styles/design-system.scss`
- 设计风格：社交互动风格（融合 Instagram Stories + Pinterest Grid + Facebook Timeline）
- 主色调：#FF8A65（珊瑚橙）温暖而充满食欲感
- 核心特征：
  - Instagram Stories 动态条 - 圆形头像 + 渐变边框
  - Pinterest 双列网格 - 视觉优先的美食卡片
  - Facebook 时间线 - 状态节点 + 连接线设计
  - 社交互动元素 - 点赞、收藏、评论、分享

### 数据模型关系

**核心实体：**
1. `Family` - 中心实体，拥有多个用户和菜谱
2. `User` - 属于一个家庭，有角色（admin/member/guest）
3. `RecipeCategory` - 属于家庭，有多个菜谱
4. `Recipe` - 属于家庭和分类，由用户创建
5. `Order` - 属于用户和家庭，有多个订单项
6. `OrderItem` - 属于订单，引用菜谱（保存快照数据）
7. `Favorite` - 用户和菜谱的关联表
8. `RecipeReview` - 用户对菜谱的评价，可关联订单
9. `FamilyInvitation` - 家庭邀请码，用于加入家庭（成员/访客）

**关键设计模式：**
- 大多数表通过 `deleted_at` 字段实现软删除
- 快照模式：OrderItem 存储菜谱名称/图片/描述以保留历史数据
- 访客用户有 `guest_expires_at` 时间戳控制临时访问权限
- GORM 模型结构体中定义关系和钩子

## 配置说明

**后端配置：** `backend/config.yaml`
- 服务端口：8081（默认）
- 数据库凭据：root/root（默认）
- JWT 密钥和过期时间
- 微信 app_id 和 app_secret（生产环境需替换）
- CORS 设置（开发环境允许所有来源）

**前端配置：**
- Vite 开发服务器端口：3000
- API 代理：`/api` → `http://localhost:8081`
- 微信小程序配置：`src/manifest.json`

## 开发流程

1. **数据库设置：** 运行 `init_database.sql` 或使用 `go run cmd/init_data.go`
2. **启动后端：** `cd backend && go run cmd/main.go`（运行在 8081 端口）
3. **启动前端：** `cd frontend && npm run dev`（编译到 `dist/dev/mp-weixin`）
4. **打开微信开发者工具：** 导入 `dist/dev/mp-weixin` 目录
5. **测试 API：** 健康检查 `http://localhost:8081/health`

## 重要说明

**微信集成：**
- 微信登录需要在 `config.yaml` 中配置有效的 `app_id` 和 `app_secret`
- 本地开发无微信环境时，使用 `/api/v1/dev/*` 接口
- 访客流程允许非家庭成员通过邀请码点餐

**角色权限：**
- `admin` - 完全访问家庭管理，可修改菜谱/分类/订单（通常是做饭的人）
- `member` - 可创建菜谱、下单、查看家庭数据
- `guest` - 临时访问权限，可查看和点餐（有过期时间）

**订单流程设计：**

订单系统采用温馨互动的设计理念，而非传统商业化流程：

**4个核心状态：**
1. **💭 想吃（pending）** - 点餐人提交心愿
   - 显示："Ta想吃这些～"
   - 温馨提示点餐人的昵称和菜品

2. **👨‍🍳 在做啦（cooking）** - 做饭人接单并开始烹饪
   - 显示："正在为你准备中❤️"
   - 显示预计烹饪时间
   - 管理员可以一键"开始做"（pending → cooking）

3. **🔔 做好啦（completed）** - 美食完成
   - 显示："爱的美食做好啦，快来品尝～"
   - 发送通知提醒点餐人
   - 管理员点击"做好啦"完成订单

4. **😋 已品尝（reviewed）** - 用餐完成并反馈
   - 点餐人可以留下爱的评价
   - 可以打分、发表情、留言
   - 记录最喜欢吃的菜品统计

**特殊状态：**
- **❌ 已取消（cancelled）** - 改变主意或特殊情况

**状态转换规则：**
- pending → cooking：管理员点击"开始做"
- pending → cancelled：任何人都可以取消
- cooking → completed：管理员点击"做好啦"
- cooking → cancelled：做饭过程中可以取消
- completed → reviewed：点餐人品尝后留下评价（可选）

**交互设计原则：**
- 使用温馨的语言：不说"订单"说"心愿"，不说"确认"说"开始做"
- 突出情感连接：显示"为你准备"而不是"处理中"
- 简化操作流程：去掉"已确认"等冗余状态
- 增加互动反馈：完成后可以评价、表情、留言

**数据库迁移：**
- 服务启动时自动运行 `model.AutoMigrate()`
- 使用 `force_migrate.go` 可删除并重建所有表（会丢失数据）

**API 版本：**
- 所有接口以 `/api/v1` 为前缀

## 社交互动风格设计系统

Love Order 采用**社交媒体互动风格**，将传统点餐应用转变为充满温情的家庭社交平台。

### 设计灵感来源

**融合三大社交平台精髓：**

1. **Instagram Stories 动态条**
   - 圆形头像 + 渐变边框（Instagram 彩虹渐变）
   - 横向滚动的动态列表
   - "+" 添加按钮突出显示
   - 使用场景：聚会模式、大家庭模式

2. **Pinterest 网格布局**
   - 双列响应式网格
   - 图片优先的卡片设计
   - 浮动标签（时间、难度）
   - 快速操作（收藏、加购物车）
   - 使用场景：菜谱浏览、美食发现

3. **Facebook Timeline 时间线**
   - 左侧圆形状态节点（emoji 图标）
   - 节点之间渐变连接线
   - 右侧内容卡片
   - 不同状态使用不同颜色
   - 使用场景：订单历史、状态追踪

### 首页动态适配设计

首页根据家庭成员数量和访客状态自动切换显示模式，兼顾情侣日常和朋友聚会两种场景。

**模式切换逻辑：**
```typescript
displayMode = computed(() => {
  const memberCount = members.filter(m => m.role !== 'guest').length
  const hasGuests = members.some(m => m.role === 'guest')

  if (hasGuests) return 'party'        // 有访客 → 聚会模式
  if (memberCount === 2) return 'couple' // 2人 → 情侣模式
  return 'family'                       // >2人 → 家庭模式
})
```

**访客流程设计：**

主人侧（发起聚会）：
1. 点击"邀请"按钮
2. 生成临时邀请码（24小时有效）
3. 分享邀请码给朋友
4. 访客加入后首页自动切换为聚会模式
5. 聚会结束（访客过期）后自动恢复原模式

访客侧（朋友点餐）：
1. 通过邀请码注册（guest 角色）
2. 输入昵称进入点餐界面
3. 可浏览菜谱、点餐、查看动态
4. 24小时后自动退出

访客权限：
- ✅ 浏览菜谱、创建订单、查看动态
- ❌ 不能修改菜谱、不能"开始做"、不能管理家庭

### 核心页面布局

**首页 - 情侣模式（2人家庭）**
```
┌─────────────────────────────────────┐
│ 💕 我们的小食堂                       │
│ [我的头像]  ←→  [Ta的头像]            │
└─────────────────────────────────────┘

💭 Ta想吃这些
  - 显示对方的 pending 订单
  - 大卡片设计，温馨文案
  - 一键"开始做"按钮
  - "回复Ta"爱的消息

👨‍🍳 我在做的
  - 显示 cooking 状态订单
  - 倒计时/进度条
  - "做好啦"按钮

📖 Ta最爱的菜
  - 双列网格，4个推荐菜谱
  - 基于对方喜好推荐

[底部固定] 💭 我想吃 | 📖 浏览菜谱 | 🎉 邀请
```

**首页 - 聚会模式（有访客时）**
```
┌─────────────────────────────────────┐
│ 🎉 今日聚会 · 5位朋友                 │
│ [邀请码: ABC123] [结束聚会]           │
└─────────────────────────────────────┘

Stories 横向滚动条
  - 主人头像 + 访客头像列表
  ↓
社交动态卡片流(Feed)
  - 用户头像 + 昵称 + 时间
  - 动态内容(文字 + 图片)
  - 互动栏(❤️ 点赞、💬 评论)
  - 主人可"开始做"
```

**首页 - Instagram Feed 风格（大家庭模式）**
```
Stories 横向滚动条
  ↓
分类筛选 Chips
  ↓
社交动态卡片流（Feed）
  - 用户头像 + 昵称 + 时间
  - 动态内容（文字 + 图片）
  - 互动栏（❤️ 点赞、💬 评论、📤 分享）
```

**菜谱页 - Pinterest Grid 风格**
```
搜索栏
  ↓
分类横向滚动
  ↓
双列网格卡片
  - 菜品大图（悬浮标签）
  - 菜品标题
  - 创建者信息
  - 快速操作（🤍 收藏、🛒 加购物车）
```

**订单页 - Facebook Timeline 风格**
```
状态筛选 Chips
  ↓
时间线布局
  ●━━━ 💭 想吃状态（橙色）
  │
  ●━━━ 👨‍🍳 在做状态（珊瑚色）
  │
  ●━━━ 🔔 做好啦状态（绿色）

  每个节点展开为：
  - 用户信息 + 状态徽章
  - 心愿文字（温馨语言）
  - 菜品照片网格（最多3张）
  - 互动操作（🔄 再来一次）
```

### 社交互动元素

**点赞/收藏动画**
```scss
// 心跳动画
@keyframes heartBeat {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.3); }
}

.action-icon.liked {
  animation: heartBeat 0.5s ease-out;
}
```

**按压反馈**
```scss
.card, .button {
  transition: all 0.2s ease-out;

  &:active {
    transform: scale(0.98);
    box-shadow: $shadow-sm;
  }
}
```

**Instagram 渐变边框**
```scss
$instagram-gradient: linear-gradient(
  45deg,
  #f09433 0%,
  #e6683c 25%,
  #dc2743 50%,
  #cc2366 75%,
  #bc1888 100%
);

.story-avatar.has-story {
  background: $instagram-gradient;
  padding: 4rpx;
}
```

### 使用方式

**1. 引入设计系统（现代 Sass 语法）**
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

**2. 社交组件示例**
```vue
<!-- Stories 动态条 -->
<scroll-view class="stories-container" scroll-x>
  <view class="story-item add-story">
    <view class="story-avatar">
      <text class="add-icon">+</text>
    </view>
    <text class="story-name">发布动态</text>
  </view>
</scroll-view>

<!-- Pinterest 网格卡片 -->
<view class="pinterest-grid">
  <view class="grid-item">
    <image class="item-image" :src="recipe.image" />
    <view class="item-actions">
      <view class="action-btn" @click="toggleFavorite">
        <text class="action-icon">{{ isFavorite ? '❤️' : '🤍' }}</text>
      </view>
    </view>
  </view>
</view>

<!-- Timeline 时间线 -->
<view class="timeline-item">
  <view class="timeline-dot status-pending">
    <text class="dot-icon">💭</text>
  </view>
  <view class="timeline-card">
    <!-- 卡片内容 -->
  </view>
</view>
```

### 设计文件

- **完整设计规范**：`SOCIAL_DESIGN_SYSTEM.md` - 包含所有组件的完整设计说明和代码示例
- **SCSS 变量文件**：`frontend/src/styles/design-system.scss` - 统一的设计 tokens
- **已实现页面**：
  - `pages/index/index.vue` - Instagram Feed 风格首页
  - `pages/recipes/index.vue` - Pinterest Grid 风格菜谱页
  - `pages/orders/index.vue` - Facebook Timeline 风格订单页

### 设计原则

1. **社交感优先** - 让每个功能都像社交互动
2. **视觉优先** - 美食照片是核心，图片大而清晰
3. **情感化语言** - 用温馨的文字传递爱意（"想吃"、"在做"、"做好啦"）
4. **即时反馈** - 所有交互都有动画和视觉反馈
5. **简化流程** - 去除冗余状态，保持简洁流畅

## 代码标准

### 命名约定

- **包名**：简短、全小写，避免下划线或混合大小写
- **变量名**：驼峰命名法，导出变量首字母大写
- **函数名**：驼峰命名法，名称应清晰描述功能
- **接口名**：单方法接口以"-er"结尾（如 `Reader`、`Writer`）
- **模型**：单数 PascalCase（如 `User`）
- **API 端点**：复数名词（如 `/users`）
- **数据库表**：复数形式，带 `ay_` 前缀

### 函数与方法

- **保持简短**：一个函数只做一件事，避免过长函数
- **减少嵌套**：使用卫哨子句提前返回，避免深层嵌套
- **参数控制**：参数不超过 3-4 个，多则使用结构体封装
- **错误处理**：错误作为最后一个返回值

### 错误处理

- **绝不忽略错误**：必须检查所有返回的 `error`
- **提供上下文**：使用 `fmt.Errorf("...: %w", err)` 包装错误
- **避免重复日志**：只在最高层或最终处理处记录日志

### 代码组织

- **避免硬编码**：配置、密钥、模板等放入配置文件
- **敏感信息**：密钥绝不能出现在代码中，使用环境变量
- **大块文本**：长提示词等存放在独立文件中

### 注释规范

- **公共 API 文档**：所有导出的类型、函数都应有注释
- **解释"为什么"**：注释应说明设计决策，而非重复代码
- **避免无用注释**：不写显而易见的注释

## 开发规则

### 编码要求-严格遵守

- 接口请求方式只允许使用 POST 和 GET 这两种
- 所有回复必须使用中文
- 为 API 编写正确、最新、无 bug、功能完整、安全且高效的 Go 代码
- 严格按照用户的要求一丝不苟地执行
- 禁止生成测试数据或演示内容
- 代码必须添加简洁有效的注释
- 不得包含个人信息或开发者署名
- 不确定需求时应主动询问
- 开始前制定任务规划，多方案时需确认
- 避免过度设计，方法名简洁明确
- 不可自动重启程序
- 在 API 实现中不留 todos、占位符或缺失部分
- 如果对最佳实践或实现细节不确定，请说明而不是猜测
- 代码应当简洁且易于理解
- 严重禁止生成文档 .md文件 或者说明等其他类似的文档说明

### 回答规范

每次回答结尾添加：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 模型：[模型名称]

📋 当前问题：
[项目问题描述]

💡 解决方案：
[解决办法说明]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
