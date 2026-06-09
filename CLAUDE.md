# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

lover-order 是一个面向情侣 / 家庭的日常吃饭决策工具，移动端原生应用。**先做 iOS（SwiftUI），后期做 Android（Jetpack Compose）。**

**产品理念：**
- 解决日常痛点："今天吃什么 / 周末吃什么 / 家里来人吃什么"
- 不是商家点餐 App，而是两个人或一家人之间的菜单共享与决策
- 核心动词：**选菜 → 定下这一顿 → 做了 → 吃了 → 留下记录**

**核心概念：**
- **一个家（Household）**：一两个人 / 一家人共享同一份菜单库
- **这一顿（MealSession）**：一次吃饭的载体；从"挑菜"开始，到"吃完留评"结束
- **场景（Scene）**：`我们这顿` / `家里这顿` / `未来这顿`
- **心情（Mood）**：`轻松点` / `正常吃` / `认真吃` / `换换口味`

**视觉风格：**
- 日式侘寂、米白背景、墨绿主色（#516B4A）
- 大留白、细圆角、衬线大标题
- 设计稿位于 `love/` 目录

## 技术栈

| 层 | 技术 |
|---|---|
| iOS 客户端 | Swift 5.10 + SwiftUI + Combine |
| iOS 登录 | Sign in with Apple |
| iOS 项目工程 | XcodeGen（通过 project.yml 生成 .xcodeproj） |
| 后端 | Go + Gin + GORM |
| 数据库 | MySQL 8.0+ |
| 认证 | Apple identity_token 验签 + 自签 JWT（HS256，access + refresh） |
| 接口风格 | 仅 GET / POST，路径风格如 `/recipes/:id/update` |

## 仓库结构

```
lover-order/
├── backend/                    # Go 后端
│   ├── cmd/
│   │   ├── server/main.go     # HTTP 服务入口（端口 8081）
│   │   └── force_migrate/     # 清库重建（开发用）
│   ├── config.yaml            # 后端配置
│   ├── internal/
│   │   ├── api/               # HTTP handler
│   │   ├── service/           # 业务层
│   │   ├── model/             # GORM 模型 + DB 初始化
│   │   ├── middleware/        # JWT / 家庭中间件
│   │   └── config/            # Viper 配置加载
│   └── pkg/
│       ├── jwt/               # 签发/解析自签 JWT
│       └── apple/             # Apple identity_token JWKS 验签
├── ios/                        # iOS 原生工程
│   ├── project.yml            # XcodeGen 配置
│   └── LoverOrder/
│       ├── App/               # @main、AppState、根视图、TabBar
│       ├── Design/            # 颜色 / 字体 / 间距 / 通用组件
│       ├── Models/            # 领域模型 与后端字段一一对应
│       ├── Network/           # APIClient + 各 Service
│       ├── Features/          # Auth / Meal / Menu / History / Profile
│       └── Resources/         # Assets.xcassets / Info.plist / entitlements
├── love/                       # 设计稿 PNG（不要删）
└── CLAUDE.md
```

## 常用命令

### 后端

```bash
cd backend

# 安装依赖
go mod tidy

# 启动服务（端口 8081）
go run ./cmd/server

# 重建所有表（清空数据）
go run ./cmd/force_migrate

# 编译验证
go build ./...
go vet ./...
```

### iOS

iOS 工程通过 **XcodeGen** 生成 .xcodeproj，源代码就是事实，避免 .xcodeproj 进 git 后冲突。

```bash
cd ios

# 首次：安装 XcodeGen（一次性）
brew install xcodegen

# 生成 / 更新 .xcodeproj
xcodegen generate

# 打开
open LoverOrder.xcodeproj
```

修改 `ios/project.yml` 或新增 .swift 文件后，需要重新跑 `xcodegen generate`。

### 数据库

```bash
mysql -u root -p -e "CREATE DATABASE lover_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

服务启动会自动 GORM AutoMigrate。

## 数据模型（后端 GORM）

| 表 | 含义 | 备注 |
|---|---|---|
| `households` | 一个家 | 1-N 成员共用一份菜单 |
| `users` | 用户 | 绑定一个家 |
| `household_invites` | 临时邀请码 | 支持过期 + 限次 |
| `recipe_categories` | 菜谱分类 | 属于一个家 |
| `recipes` | 菜谱 | 含 `mood_tags` / `scene_tags` 让首页可按心情/场景推荐 |
| `favorites` | 收藏 | 用户对菜谱 |
| `meal_sessions` | 这一顿 | scene + mood + status |
| `meal_dishes` | 一顿里的菜 | 保留菜名/图快照，菜谱删除不丢失记录 |
| `meal_reviews` | 一顿的评价 | 吃完后留下评分/留言/照片 |

**一顿状态机：** `planning → confirmed → completed`（可任意状态 `cancelled`）

## API 路由

所有路径以 `/api/v1` 开头，方法仅 `POST` / `GET`。

| 类别 | 路径 | 方法 | 说明 |
|---|---|---|---|
| 登录 | `/auth/apple` | POST | Apple 登录或注册 |
| | `/auth/refresh` | POST | 刷新 access token |
| | `/auth/logout` | POST | 登出 |
| | `/auth/dev` | POST | 开发登录（仅非 release 模式启用，真机/模拟器未配 Apple 时用） |
| 用户 | `/user/profile` | GET / POST | 资料读 / 写 |
| 上传 | `/upload/image` | POST | 上传图片（multipart/form-data，返回 url + path） |
| 家 | `/household/create` | POST | 创建并自动加入 |
| | `/household/info` | GET | 当前家详情含成员 |
| | `/household/join` | POST | 邀请码加入 |
| | `/household/leave` | POST | 退出 |
| | `/household/invite` | POST | 生成临时邀请码 |
| | `/household/invitations` | GET | 邀请记录 |
| 分类 | `/categories/list` | GET | |
| | `/categories/create` | POST | |
| | `/categories/:id/update` | POST | |
| | `/categories/:id/delete` | POST | |
| 菜谱 | `/recipes/list` | GET | 支持 mood / scene / keyword / category_id / favorite 过滤 |
| | `/recipes/:id` | GET | 详情 |
| | `/recipes/create` | POST | |
| | `/recipes/:id/update` | POST | |
| | `/recipes/:id/delete` | POST | |
| | `/recipes/:id/favorite` | POST | 切换收藏 |
| 一顿 | `/meals/current` | GET | 拿当前规划中的一顿，没有就创建 |
| | `/meals/list` | GET | 历史列表 支持 status / scene |
| | `/meals/stats` | GET | 家庭统计（总顿数 / 总菜数 / 近 30 天 / 高频菜 / 场景分布） |
| | `/meals/:id` | GET | 详情含菜与评价 |
| | `/meals/create` | POST | 显式新建 |
| | `/meals/:id/update` | POST | 改场景 / 心情 / 备注 |
| | `/meals/:id/confirm` | POST | 定下这一顿 |
| | `/meals/:id/complete` | POST | 标记吃完 |
| | `/meals/:id/cancel` | POST | 取消 |
| | `/meals/:id/review` | POST | 留下评价 |
| | `/meals/:id/dishes/add` | POST | 加菜 |
| | `/meals/:id/dishes/:dish_id/remove` | POST | 移除 |
| | `/meals/:id/shopping-list` | GET | 这一顿的购物清单（按食材聚合） |

统一响应体：`{ "code": 0, "message": "ok", "data": ... }`。`code != 0` 表示业务错误，HTTP 状态码与之对齐。

## Apple Sign In 接入要点

后端：`backend/pkg/apple/apple.go`
- 拉取 `https://appleid.apple.com/auth/keys` JWKS，缓存 1 小时
- 用 `kid` 找对应 RSA 公钥校验 identity_token 签名
- 校验 `iss = https://appleid.apple.com` 与 `aud = config.apple.client_id`

iOS：`ios/LoverOrder/Features/Auth/LoginView.swift`
- 使用 `AuthenticationServices.SignInWithAppleButton`
- 拿到 `identityToken` 后调用 `/auth/apple` 换 access + refresh
- 令牌存 Keychain（`TokenStorage`）

**生产前需配置**：在 `backend/config.yaml` 的 `apple` 段填好 `client_id`（App Bundle ID）等字段。

## iOS 设计 token

定义在 `ios/LoverOrder/Design/`：

| 颜色资源 | 用途 |
|---|---|
| `AppBackground` | 主背景米白 #F3EEE6 |
| `CardBackground` | 卡片米色 #F8F5F1 |
| `BrandGreen` | 主色墨绿 #516B4A |
| `AccentInk` | 深墨绿强调 #495F42 |
| `InkPrimary` / `InkSecondary` / `InkMuted` | 文本灰阶 |
| `Divider` | 分割线 |

字体：`AppFont.title/headline/body/caption/mono`，标题用 `.serif` 设计风格贴合衬线大标题。

## 编码规则（必须遵守）

- 接口方法只允许 GET / POST
- 所有回复使用中文
- 严格按用户要求执行，不要过度设计
- 不生成测试数据 / 演示内容 / 占位符
- 不留 TODO，缺少能力先问
- 注释只解释 WHY，不重复 WHAT
- 不写 Markdown 文档（除已存在的 CLAUDE.md）
- 不在代码里放个人信息或署名
- 不要自动重启程序
- iOS 代码风格：SwiftUI 优先，避免 ViewController；View 层不直接发请求，过 ViewModel 或 Service

## 回答规范

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
