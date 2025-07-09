# 🏠 Love Order - 家庭点餐小程序

一个专为家庭使用的微信点餐小程序，支持家庭菜谱管理、家人点餐和访客点餐功能。

## 📋 项目概述

### 功能特点
- 🍳 家庭菜谱管理（上传、编辑、分类）
- 👨‍👩‍👧‍👦 家庭成员权限管理
- 🛒 可爱简约的点餐界面
- 👥 访客点餐功能（朋友来做客时使用）
- 📊 订单管理和统计
- 💝 收藏和评价系统

### 技术栈
- **前端**: uni-app + Vue 3 + TypeScript + uni-ui
- **后端**: Go + Gin + GORM
- **数据库**: MySQL 8.0+
- **认证**: JWT + 微信小程序登录
- **部署**: Docker + Nginx
- **跨端支持**: 微信小程序、H5、支付宝小程序等

## 🛠 开发环境准备

### 必需软件
- Node.js 18+
- Go 1.19+
- MySQL 8.0+
- 微信开发者工具 (小程序调试)
- Git

### 开发工具推荐
- VS Code + Volar插件 (Vue开发)
- HBuilderX (uni-app官方IDE，可选)
- 微信开发者工具 (小程序开发调试)
- Chrome DevTools (H5调试)
- Navicat/DBeaver (数据库管理)
- Postman (API测试)

## 📁 项目结构

```
love-order/
├── backend/                 # Go后端
│   ├── cmd/                # 应用入口
│   ├── internal/           # 内部包
│   │   ├── api/           # API路由和处理器
│   │   ├── model/         # 数据模型
│   │   ├── service/       # 业务逻辑
│   │   ├── middleware/    # 中间件
│   │   └── config/        # 配置
│   ├── pkg/               # 公共包
│   ├── migrations/        # 数据库迁移
│   ├── docs/             # API文档
│   ├── go.mod
│   └── go.sum
├── frontend/              # uni-app + Vue前端
│   ├── src/              # 源代码
│   │   ├── components/   # 组件
│   │   ├── pages/        # 页面
│   │   ├── composables/  # 组合式函数
│   │   ├── store/        # 状态管理(Pinia)
│   │   ├── utils/        # 工具函数
│   │   ├── api/          # API接口
│   │   ├── types/        # TypeScript类型定义
│   │   ├── styles/       # 样式文件
│   │   ├── static/       # 静态资源
│   │   ├── uni_modules/  # uni-app插件
│   │   ├── App.vue       # 应用入口
│   │   ├── main.ts       # 主入口文件
│   │   ├── manifest.json # 应用配置
│   │   └── pages.json    # 页面路由配置
│   ├── package.json      # 依赖配置
│   ├── tsconfig.json     # TypeScript配置
│   ├── vite.config.ts    # Vite配置
│   └── index.html        # H5入口文件
├── docs/                 # 项目文档
├── docker/               # Docker配置
├── scripts/              # 脚本文件
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

详细的数据库设计请参考 `docs/database.md`

## 🎨 UI设计规范

### 色彩方案
- **主色调**: 温暖橙色 `#FF8A65`
- **辅助色**: 柔和粉色 `#F8BBD9`
- **强调色**: 清新绿色 `#81C784`
- **背景色**: 米白色 `#FAFAFA`
- **文字色**: 深灰色 `#424242`

### 设计原则
- 圆角设计（12px统一圆角）
- 卡片式布局
- 轻微阴影效果
- 可爱友好的图标
- 流畅的动画过渡

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd love-order
```

### 2. 后端启动
```bash
cd backend
go mod tidy
go run cmd/main.go
```

### 3. 前端启动
```bash
cd frontend
npm install

# 开发微信小程序
npm run dev:mp-weixin

# 开发H5版本
npm run dev:h5

# 构建生产版本
npm run build:mp-weixin  # 构建微信小程序
npm run build:h5         # 构建H5版本
```

### 4. 数据库初始化
```bash
# 创建数据库
mysql -u root -p -e "CREATE DATABASE love_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 运行迁移
cd backend
go run cmd/migrate.go
```

## 📚 开发文档

- [开发指南](docs/development-guide.md)
- [API文档](docs/api.md)
- [数据库设计](docs/database.md)
- [部署指南](docs/deployment.md)
- [测试指南](docs/testing.md)

## 🔄 开发流程

详细的开发步骤请参考 `docs/development-guide.md`

## 📝 更新日志

### v1.0.0 (计划中)
- [ ] 基础项目架构搭建
- [ ] 用户认证系统
- [ ] 菜谱管理功能
- [ ] 基础点餐功能
- [ ] 访客功能
- [ ] UI美化和优化

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 📄 许可证

MIT License

## 👥 团队

- 开发者: [Your Name]
- 设计师: [Designer Name]

---

💡 **提示**: 这是一个家庭使用的私人项目，请根据实际需求调整功能和配置。
