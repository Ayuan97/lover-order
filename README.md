# 我们这顿 · lover-order

“我们这顿”是给家庭成员一起决定吃什么的 iOS 应用。当前版本的主路径是：在“这一顿”里加菜 → 定下这一顿 → 吃完后记录。它不是商家点餐系统。

当前可用行为、页面入口、状态和协作房间规则见[当前版本说明](docs/product-flow.md)。首页画布的编辑交互见[首页画布说明](docs/features/home-canvas/feature.md)。

## 项目结构

```text
lover-order/
├── backend/                 # Go + Gin + GORM 服务
├── ios/project.yml          # XcodeGen 工程配置
├── ios/LoverOrder/          # SwiftUI 客户端
├── docs/                    # 当前版本功能说明与清理审查
└── love/                    # 设计参考图
```

## 启动后端

```bash
cd backend
go mod tidy
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS lover_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
go run ./cmd/server
```

服务默认监听 `:8081`，健康检查为 `GET /health`。配置文件是 `backend/config.yaml`，服务必须从 `backend/` 目录启动。

## 构建 iOS

```bash
cd ios
xcodegen generate
open LoverOrder.xcodeproj
```

客户端使用 SwiftUI 和系统框架，不依赖第三方 Swift 包。模拟器默认请求 `http://localhost:8081/api/v1`；真机地址由 `Info.plist` 中的 `API_BASE_URL` 提供。

## 认证与数据

正式登录使用 Sign in with Apple；非 release 构建提供开发登录。后端使用 MySQL、GORM 和自签 JWT。餐次、菜谱、家庭、评价和临时点菜房间均由后端持久化。

当前代码和可达页面优先于旧设计稿、截图和历史说明。无入口的遗留页面及旧画布组件的审查结果记录在[清理审查](docs/audits/2026-09-current-version.md)。
