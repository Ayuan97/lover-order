# 我们这顿 · lover-order

面向情侣 / 家庭的「今天吃什么」决策工具。两个人或一家人共享一份菜单，把每一顿饭一起定下来：

> 选菜 → 定下这一顿 → 做了 → 吃了 → 留下记录

不是商家点餐 App，而是一家人之间的菜单共享与决策。先做 iOS（SwiftUI），后端 Go。

## 核心概念

- **一个家（Household）**：一两个人 / 一家人共享同一份菜单库，一个账号只属于一个家
- **这一顿（MealSession）**：一次吃饭的载体，从挑菜到吃完留评。状态机 `planning → confirmed → completed`（可随时 `cancelled`）
- **场景（Scene）**：俩人世界 / 家庭聚餐 / 未来这顿
- **心情（Mood）**：轻松点 / 正常吃 / 认真吃 / 换换口味
- **聚餐（Dining）**：家里来客时开一桌，客人扫码或输房间号临时加入，**共用主人家的菜单**一起点菜；离开就走，不改变各自的家庭归属

## 功能

- **登录**：Sign in with Apple；开发登录（非 release 模式，真机/模拟器未配 Apple 时用）
- **一个家**：创建、邀请码 / 扫码加入、退出；创建者退出时自动把家移交给最早的成员，只剩一人则解散
- **菜谱**：分类管理、增删改、收藏、按心情 / 场景 / 关键词筛选、图片上传
- **这一顿**：按场景与心情推荐、从菜单 / 收藏 / 历史 / 自定义加菜、定下、做好、吃完留评（整顿评分 + 单道菜反馈）、一键生成购物清单
- **相处模式**：俩人世界 / 家庭聚餐 切换，驱动首页呈现
- **聚餐**：开聚餐出示二维码 + 房间号 → 客人扫码 / 输码加入 → 共用主人家菜单点菜 → 实时同步参与者与菜 → 撤回自己点的菜 → 主人结束后自动散场；退出 App 再回来可一键返回进行中的聚餐
- **历史 & 统计**：历史一顿回看，家庭维度统计（总顿数 / 总菜数 / 近 30 天 / 高频菜 / 场景分布）

## 技术栈

| 层 | 技术 |
|---|---|
| iOS 客户端 | Swift 5.10 + SwiftUI + Combine |
| iOS 登录 | Sign in with Apple |
| iOS 工程 | XcodeGen（`project.yml` 生成 `.xcodeproj`，源码即事实，不提交 `.xcodeproj`） |
| 后端 | Go + Gin + GORM |
| 数据库 | MySQL 8.0+ |
| 认证 | Apple identity_token 验签 + 自签 JWT（HS256，access + refresh） |
| 接口风格 | 仅 GET / POST，路径如 `/recipes/:id/update`，统一响应体 `{ code, message, data }` |

## 仓库结构

```
lover-order/
├── backend/                 # Go 后端
│   ├── cmd/server           # HTTP 服务入口（端口 8081）
│   ├── cmd/force_migrate    # 清库重建（开发用）
│   ├── internal/{api,service,model,middleware,config}
│   └── pkg/{jwt,apple}      # 自签 JWT / Apple JWKS 验签
├── ios/                     # iOS 原生工程
│   ├── project.yml          # XcodeGen 配置
│   └── LoverOrder/{App,Design,Models,Network,Features,Resources}
├── love/                    # 设计稿 PNG
└── CLAUDE.md                # 给协作者 / AI 的详细工程说明（数据模型、完整 API 路由、设计 token）
```

## 快速开始

### 后端

```bash
cd backend
go mod tidy
mysql -u root -p -e "CREATE DATABASE lover_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
go run ./cmd/server          # 启动后自动 GORM AutoMigrate
```

生产前在 `backend/config.yaml` 的 `apple` 段填好 `client_id`（App Bundle ID）。

### iOS

```bash
cd ios
brew install xcodegen        # 首次
xcodegen generate            # 生成 / 更新 .xcodeproj（改 project.yml 或增删 .swift 后都要重跑）
open LoverOrder.xcodeproj
```

真机调试：`project.yml` 已写入 `DEVELOPMENT_TEAM`；模拟器走 `localhost:8081`，真机改 `Info.plist` 的 `API_BASE_URL` 为局域网地址。

## 视觉

日式侘寂风：米白背景（#F3EEE6）、墨绿主色（#516B4A）、大留白、细圆角、衬线大标题。设计稿在 `love/`，设计 token 见 `CLAUDE.md`。
