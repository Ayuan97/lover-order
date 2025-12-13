# Love Order

情侣/家庭点餐微信小程序，通过食物传递爱意。

## 技术栈

- **前端**: uni-app + Vue 3 + TypeScript + Pinia
- **后端**: Go 1.24 + Gin + GORM
- **数据库**: MySQL 8.0+
- **认证**: JWT + 微信小程序登录

## 快速开始

### 数据库

```bash
mysql -u root -p -e "CREATE DATABASE love_order CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

### 后端

```bash
cd backend
go mod tidy
go run cmd/server/main.go  # 端口 8081
```

### 前端

```bash
cd frontend
npm install
npm run dev  # 输出到 dist/dev/mp-weixin
```

用微信开发者工具导入 `frontend/dist/dev/mp-weixin` 目录。

## 项目结构

```
├── backend/
│   ├── cmd/server/main.go     # 入口
│   ├── internal/
│   │   ├── api/               # HTTP 处理器
│   │   ├── service/           # 业务逻辑
│   │   ├── model/             # 数据模型
│   │   ├── middleware/        # 认证中间件
│   │   └── config/            # 配置
│   ├── pkg/                   # JWT、微信工具
│   └── config.yaml            # 配置文件
├── frontend/
│   ├── src/
│   │   ├── pages/             # 页面组件
│   │   ├── api/               # API 服务
│   │   ├── styles/            # 设计系统
│   │   └── pages.json         # 路由配置
│   └── vite.config.ts
└── init_database.sql
```

## 核心功能

**角色权限**
- `admin` - 管理菜谱、分类、订单、访客
- `member` - 创建菜谱、下单
- `guest` - 临时访客，有过期时间

**订单状态**
- `pending` - 想吃
- `cooking` - 在做
- `completed` - 做好啦
- `cancelled` - 已取消

**页面模式**
- 情侣模式（2人）
- 家庭模式（多人）
- 聚会模式（有访客）

## API 路由

| 路由 | 说明 | 权限 |
|------|------|------|
| `/api/v1/auth/*` | 微信登录、刷新 | 无 |
| `/api/v1/guest/*` | 访客注册 | 无 |
| `/api/v1/user/*` | 用户资料 | 认证 |
| `/api/v1/recipes/*` | 菜谱 CRUD | 家庭成员 |
| `/api/v1/categories/*` | 分类管理 | 家庭成员 |
| `/api/v1/orders/*` | 订单管理 | 家庭成员 |
| `/api/v1/family/*` | 家庭操作 | 认证 |
| `/api/v1/admin/*` | 管理员操作 | 管理员 |

## 数据模型

- `Family` - 家庭，拥有成员、菜谱、订单
- `User` - 用户，属于家庭，有角色
- `RecipeCategory` - 菜谱分类
- `Recipe` - 菜谱，包含食材、步骤、营养
- `Order` / `OrderItem` - 订单及详情（快照模式）
- `Favorite` - 收藏
- `RecipeReview` - 评价
- `FamilyInvitation` - 邀请码

## 配置

后端 `backend/config.yaml`:
- 端口、数据库、JWT 密钥、微信凭据

前端 `frontend/src/api/config.ts`:
- API 基础地址

## 开发命令

```bash
# 初始化测试数据
cd backend && go run cmd/init_data/main.go

# 强制迁移（删除重建表）
cd backend && go run cmd/force_migrate/main.go

# 添加丰富测试数据
cd backend && go run cmd/add_rich_data/main.go
```
