# 我们这顿 · lover-order

“我们这顿”围绕一张对应今天这一顿的自由画布展开。日常主要由用户和对象共同添加内容、放上想吃的菜、摆放和商量，决定今天吃什么；在家吃完后，把菜、画布当时的样子、备注和多张照片留进历史。来客以临时身份加入同一张画布，继续共同完善这一顿。

这是产品方向，现有实现尚未全部对齐。阅读时请区分：

- [产品方向与目标流程](docs/product-flow.md)：自由画布、日常协作、临时来客和历史记录。
- [产品视觉与操作规范](docs/design/product-visual-system.md)：以吃一点为参考的页面与控件规范。
- [当前画布与餐次入口](docs/features/home-canvas/feature.md)：现在实际能用的内容与操作。
- [代码对齐清单](docs/audits/2026-10-canvas-alignment.md)：尚未对齐的代码、影响和定位依据。

## 项目结构

```text
lover-order/
├── backend/                 # Go + Gin + GORM 服务
├── ios/project.yml          # XcodeGen 工程配置
├── ios/LoverOrder/          # SwiftUI 客户端
├── docs/                    # 产品方向、当前行为与代码对齐清单
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

正式登录使用 Sign in with Apple；iOS Debug 构建显示开发登录，后端仅在非 release 模式提供开发登录接口。后端使用 MySQL、GORM 和自签 JWT。餐次、菜谱、家庭、评价和房间参与关系由后端持久化；完整画布目前存于本机，记录页可回看当前手机保存的餐次画布；共享存储暂缓。

产品方向以用户明确的决定及同步后的文档为准；当前可用行为以实际可达代码为准。两者不一致时登记到代码对齐清单。
