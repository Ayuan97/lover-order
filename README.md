# 我们这顿 · lover-order

面向情侣的「今天吃什么」决策工具。两个人共享一份菜单，把每一顿饭一起定下来：

> 点菜 → 就这些 → 吃完了 →（可选）写两句

不是商家点餐 App，而是两个人之间的菜单共享与决策。先做 iOS（SwiftUI），后端 Go。

## 核心概念

- **一个家（Household）**：情侣共享同一份菜单库，一个账号只属于一个家
- **这一顿（MealSession）**：日常固定为「我们这顿」；从点菜到吃完。状态机 `planning → confirmed → completed`（可 `cancelled`）
- **心情（Mood）**：轻松点 / 正常吃 / 认真吃 / 换换口味（怎么吃，不是场景切换）
- **点菜房间（偶发）**：家里来客时临时开房，客人扫码或手输房间号一起点菜；**共用主人家菜单**；离开就走，不改变家庭归属
- **以后想吃**：支线清单，不上首页主路径

## 功能

- **登录**：Sign in with Apple；开发登录（非 release，真机/模拟器未配 Apple 时用）
- **一个家**：创建、邀请码 / 扫餐券加入、退出；创建者退出时移交或解散
- **菜谱**：分类、增删改、收藏、筛选、图片上传
- **我们这顿**：推荐、加菜、就这些、购物清单、吃完留评
- **点菜房间**：主人出示房间二维码（`lo://room/…`）→ 客人扫码或手输房间号 → 实时同步 → 关房后不能再加菜（菜保留在这一顿）
- **历史 & 统计**：回看与家庭统计
- **以后想吃**：先记下，不急着今天做

## 技术栈

| 层 | 技术 |
|---|---|
| iOS 客户端 | Swift 5.10 + SwiftUI + Combine |
| iOS 登录 | Sign in with Apple |
| iOS 工程 | XcodeGen（`project.yml` 生成 `.xcodeproj`） |
| 后端 | Go + Gin + GORM |
| 数据库 | MySQL 8.0+ |
| 认证 | Apple identity_token 验签 + 自签 JWT（HS256） |
| 接口风格 | 仅 GET / POST，路径如 `/recipes/:id/update` |

## 仓库结构

```
lover-order/
├── backend/                 # Go 后端
│   ├── cmd/server           # HTTP 服务入口（端口 8081）
│   ├── cmd/force_migrate    # 清库重建（开发用）
│   ├── cmd/cleanup_dirty    # 脏数据清理
│   ├── internal/{api,service,model,middleware,config}
│   └── pkg/{jwt,apple}
├── ios/
│   ├── project.yml
│   └── LoverOrder/
├── love/                    # 设计稿
└── CLAUDE.md                # 工程说明与产品宪法
```

## 快速开始

### 后端

```bash
cd backend
go mod tidy
mysql -u root -p -e "CREATE DATABASE lover_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
go run ./cmd/server
```

生产前在 `backend/config.yaml` 的 `apple` 段填好 `client_id`。

### iOS

```bash
cd ios
brew install xcodegen
xcodegen generate
open LoverOrder.xcodeproj
```

## 视觉

日式侘寂、米白背景、墨绿主色（#516B4A）。详见 `CLAUDE.md` 设计 token。
