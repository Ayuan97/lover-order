# 🏠 Love Order - 家庭点餐小程序

一个专为家庭使用的微信点餐小程序，支持家庭菜谱管理、家人点餐和访客点餐功能。

## 📋 项目概述

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

### 功能特点
- 🍳 家庭菜谱管理（上传、编辑、分类）
- 👨‍👩‍👧‍👦 家庭成员权限管理
- 🛒 社交互动风格的点餐界面（Instagram + Pinterest + Facebook 设计）
- 👥 访客点餐功能（朋友来做客时使用）
- 📊 订单管理和统计
- 💝 收藏和评价系统

### 技术栈
- **前端**: uni-app + Vue 3 + TypeScript
- **后端**: Go + Gin + GORM
- **数据库**: MySQL 8.0+
- **认证**: JWT + 微信小程序登录

## 🛠 开发环境准备

### 必需软件
- Node.js 18+
- Go 1.19+
- MySQL 8.0+
- 微信开发者工具 (小程序调试)

## 📁 项目结构

```
love-order/
├── backend/                 # Go后端
│   ├── cmd/                # 应用入口
│   │   └── server/        # 主服务器
│   ├── internal/           # 内部包
│   │   ├── api/           # API路由和处理器
│   │   ├── model/         # 数据模型
│   │   ├── service/       # 业务逻辑
│   │   ├── middleware/    # 中间件
│   │   └── config/        # 配置
│   ├── pkg/               # 公共包
│   ├── config.yaml        # 配置文件
│   ├── go.mod
│   └── go.sum
├── frontend/              # uni-app + Vue前端
│   ├── src/              # 源代码
│   │   ├── api/          # API接口
│   │   ├── pages/        # 页面
│   │   ├── styles/       # 样式文件（设计系统）
│   │   ├── App.vue       # 应用入口
│   │   ├── main.ts       # 主入口文件
│   │   ├── manifest.json # 应用配置
│   │   └── pages.json    # 页面路由配置
│   ├── package.json      # 依赖配置
│   ├── tsconfig.json     # TypeScript配置
│   └── vite.config.ts    # Vite配置
├── CLAUDE.md             # Claude Code 项目说明
├── SOCIAL_DESIGN_SYSTEM.md  # 社交互动设计系统文档
├── TODO.md               # 开发任务清单
├── init_database.sql     # 数据库初始化脚本
└── README.md
```

## 🗄 数据库设计

### 核心表结构
- `families` - 家庭信息表
- `users` - 用户表（家庭成员+访客）
- `recipe_categories` - 菜谱分类表
- `recipes` - 菜谱表
- `orders` - 订单表
- `order_items` - 订单详情表
- `favorites` - 收藏表
- `recipe_reviews` - 评价表
- `family_invitations` - 家庭邀请表

## 🎨 UI设计规范

### 社交互动风格设计系统

Love Order 采用**社交媒体互动风格**，融合三大社交平台精髓：

1. **Instagram Stories 动态条** - 圆形头像 + 渐变边框
2. **Pinterest 网格布局** - 双列响应式美食卡片
3. **Facebook Timeline 时间线** - 状态节点 + 连接线设计

详细设计规范请参考 `SOCIAL_DESIGN_SYSTEM.md`

### 色彩方案
- **主色调**: 珊瑚橙 `#FF8A65`
- **辅助色**: 柔和粉色 `#FFB4A2`
- **强调色**: 清新绿色 `#66BB6A`
- **背景色**: 米白色 `#FAFAFA`

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd love-order
```

### 2. 数据库初始化
```bash
# 创建数据库
mysql -u root -p -e "CREATE DATABASE love_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 导入初始数据（可选）
mysql -u root -p love_order < init_database.sql
```

### 3. 后端启动
```bash
cd backend

# 安装依赖
go mod tidy

# 启动服务（端口 8081）
go run cmd/server/main.go
```

### 4. 前端启动
```bash
cd frontend

# 安装依赖
npm install

# 开发微信小程序
npm run dev

# 构建生产版本
npm run build
```

### 5. 微信开发者工具
1. 打开微信开发者工具
2. 导入项目：选择 `frontend/dist/dev/mp-weixin` 目录
3. 开始开发

## 📚 开发文档

- **项目说明**: `CLAUDE.md` - 详细的项目架构和开发指南
- **设计系统**: `SOCIAL_DESIGN_SYSTEM.md` - UI设计规范和组件库
- **任务清单**: `TODO.md` - 功能实现进度追踪

## 🔄 订单流程设计

订单系统采用温馨互动的设计理念：

**4个核心状态：**
1. **💭 想吃（pending）** - 点餐人提交心愿
2. **👨‍🍳 在做啦（cooking）** - 做饭人接单并开始烹饪
3. **🔔 做好啦（completed）** - 美食完成
4. **😋 已品尝（reviewed）** - 用餐完成并反馈

详细流程说明请参考 `CLAUDE.md`

## 📝 配置说明

### 后端配置
编辑 `backend/config.yaml`:
- 服务端口：默认 8081
- 数据库凭据：根据实际环境配置
- JWT 密钥：生产环境请更换
- 微信 app_id 和 app_secret：需要真实的微信小程序凭据

### 前端配置
- API 地址：`frontend/src/api/config.ts`
- 微信小程序配置：`frontend/src/manifest.json`

## 🤝 贡献指南

详细开发规范请参考 `CLAUDE.md` 中的"开发规则"章节。

## 📄 许可证

MIT License

---

💡 **提示**: 这是一个家庭使用的私人项目，专注于温馨的家庭互动体验。
