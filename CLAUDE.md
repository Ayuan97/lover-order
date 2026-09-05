# lover-order 工程说明

## 产品边界

这是一个家庭成员共同决定吃什么的 iOS 应用，不是商家点餐系统。当前客户端有四个固定入口：`这一顿`、`菜谱`、`记录`、`我的`。

首页固定使用家庭餐次餐次 `household`。用户从菜谱加入菜品，在首页画布编辑菜品、文字、表情、动效、画笔和背景，然后按“定下这一顿 → 记录吃完”的顺序完成餐次。记录页支持历史筛选、详情、购物清单、评价和手动补录。朋友聚餐使用临时点菜房间或历史补录，不是首页场景切换。

当前行为说明以 [`docs/current-version.md`](docs/current-version.md) 为准；画布交互以 [`docs/features/home-canvas/feature.md`](docs/features/home-canvas/feature.md) 为准；遗留代码和文档冲突见 [`docs/audits/2026-09-current-version.md`](docs/audits/2026-09-current-version.md)。

## 技术结构

- iOS：SwiftUI、Combine、AuthenticationServices、PhotosUI、AVFoundation、CoreImage。
- 后端：Go、Gin、GORM、MySQL。
- 认证：Sign in with Apple 换取自签 access/refresh JWT。
- 工程：`ios/project.yml` 使用 XcodeGen 生成 Xcode 工程。
- API：当前路由使用 GET/POST，统一前缀 `/api/v1`。

目录职责：

```text
backend/internal/api/          HTTP handler
backend/internal/service/      业务规则
backend/internal/model/        GORM 模型与数据库
backend/internal/middleware/   JWT 与家庭权限
backend/pkg/                   Apple 验签与 JWT
ios/LoverOrder/App/            启动、登录态、TabBar
ios/LoverOrder/Design/         颜色、字体、通用组件
ios/LoverOrder/Models/         客户端领域模型
ios/LoverOrder/Network/        API client 与 service
ios/LoverOrder/Features/       Auth、Meal、Menu、History、Profile
```

## 本地运行

后端配置在 `backend/config.yaml`，服务默认监听 `8081`；从 `backend/` 目录运行 `go run ./cmd/server`。服务启动时执行 GORM AutoMigrate，但不会自动创建数据库。`GET /health` 用于探活。

iOS 首次构建需要完整 Xcode 和 XcodeGen：

```bash
cd ios
xcodegen generate
xcodebuild -project LoverOrder.xcodeproj -scheme LoverOrder -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

模拟器使用 `http://localhost:8081/api/v1`，真机使用 `Info.plist` 的 `API_BASE_URL`。正式构建需要 Apple 开发者签名；开发登录只在非 release 模式注册。

## 修改规则

- View 不直接发网络请求；通过 ViewModel 或 Network Service。
- 修改 `project.yml` 或新增 Swift 文件后重新运行 `xcodegen generate`。
- 注释解释原因，不重复代码本身。
- 修改功能行为时同步更新 `docs/` 中对应说明。
- 不把截图、模拟器缓存、`.idea/`、`.xcodebuildmcp/` 等本地产物提交到仓库。
- 删除 Swift 页面前先确认它不在已生成的 Xcode 工程输入中，再重新生成工程并编译。

## 开发维护命令

`backend/cmd/force_migrate` 会重建数据库表，`backend/cmd/cleanup_dirty` 会清理历史脏数据。它们是开发维护工具，不是用户功能，运行前需要确认数据环境。
