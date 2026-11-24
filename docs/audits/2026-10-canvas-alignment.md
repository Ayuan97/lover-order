# 自由画布方向与现有代码的对齐清单

本清单以[产品方向](../product-flow.md)为依据，记录对当前工作区的静态代码核对结果（2026-10-19 初版，后续随画布与抠图对齐迭代同步更新）。清单记录待对齐项；当前可操作的入口与行为见[画布功能说明](../features/home-canvas/feature.md)。

## 1. 日常双方与画布已接入实时多人协同（已对齐）

后端新增 `meal_canvases` 表与 `CanvasHub` / `CanvasService`，提供 `GET/POST /api/v1/meals/:id/canvas` 与 `WS /api/v1/meals/:id/canvas/ws`。客户端 `MealCanvasView` 通过 `CanvasRealtimeSession` 在打开当前餐次时建立 WebSocket 连接（并保留 4 秒餐次轮询与 REST 全量保存在断网重连时兜底），将贴纸、菜品贴纸、文字、手绘涂鸦、Normalized 笔迹、背景/滤镜/虚化及拖动/旋转/缩放实时预览（`live_preview`）实时广播给同餐次所有在线成员。

结果：日常两人（及家庭其他成员）在各自手机打开「这一顿」时可实时共同编辑同一张自由画布，不再局限于仅同步菜单列表。

依据：[后端画布模型](../../backend/internal/model/canvas.go)、[画布服务与网关](../../backend/internal/service/canvas_service.go)、[画布处理器](../../backend/internal/api/canvas_handler.go)、[WebSocket 会话](../../ios/LoverOrder/Network/Services/MealService.swift)、[协同画布视图](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)。

## 2. 临时来客已直接进入主家实时画布，身份与留存规则待定（部分对齐）

加入成功后打开的 `DiningGuestView` 已内嵌访客模式 `MealCanvasView(isGuestMode: true)`；来客可与主家日常成员实时共编画布全部元素，且可通过 `DiningDishPicker` 或画布删除菜品贴纸移除桌上任意菜品（后端 `DiningService.RemoveDish` 已放开为房间成员平等移除，同时增删菜、关房/进退房均通过 `BroadcastMealSync` 实时推送同步信号）。主家的流程操作（定下这一顿、吃完了、收摊关房、邀请一起点、买菜清单、补写记录）仅保留在家庭端，来客端仅保留「收起」与「退出」。

未对齐/待用户决定事项：来客目前仍须先登录账号；临时身份是否允许免登录、除共同编辑外的细粒度权限、来客参与有效期（当前房间仍为 6 小时），以及主家提前关房会删除 `MealParticipant` 参与记录的留存规则尚未由用户最终确定。

依据：[来客协同画布](../../ios/LoverOrder/Features/Meal/DiningGuestView.swift)、[来客点菜器](../../ios/LoverOrder/Features/Meal/DiningDishPicker.swift)、[点菜房服务](../../backend/internal/service/dining_service.go)、[餐次路由](../../backend/cmd/server/main.go)。

## 3. 历史画布已接入云端回看与跨设备还原（已对齐，历史再编辑待定）

`HistoryView`、`HistoryDetailView`、`MealCanvasSnapshotView` 与分享海报渲染均会在本地缺少缓存时调用 `syncRemoteMealCanvasIfNeeded` 从后端 `GET /api/v1/meals/:id/canvas` 拉取云端保存的 `CanvasDocument`（并在进入详情时强制与云端校准），按原画布尺寸与百分比坐标还原背景、氛围滤镜、菜品与独立贴纸、手绘文字与笔迹，并支持只读 Live 播放与 Live Photo / 海报导出。

剩余未决定事项：历史画布是否允许在完成后再次编辑，目前按产品边界保持只读回看。

依据：[历史列表](../../ios/LoverOrder/Features/History/HistoryView.swift)、[历史详情](../../ios/LoverOrder/Features/History/HistoryDetailView.swift)、[画布快照与同步](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)。

## 4. 拍照/相册抠图、自选背景与全部创作元素均已支持跨设备持久化与实时同步（已对齐）

贴纸面板按“手绘贴纸 → 我的贴图 → 表情”排列：内置 16 枚矢量/排版手绘 Plog 贴纸、36 枚水粉白边模切贴纸（`StickerEmoji_*`）及“相册抠图 / 拍照做贴图”生成的透明 PNG / 照片贴纸均通过服务端文件路径与元素操作同步；自定义相册背景在立即本地预览的同时后台通过 `UploadService` 上传原图并将 `customBackgroundURL` 经 `update_background` 广播并持久化，跨设备进入画布或查看历史时可通过 `RemoteImageCache` 自动加载展示。

依据：[画布与实时操作](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)、[拍照贴图入口](../../ios/LoverOrder/Design/Components/PhotoStickerSheet.swift)、[原生主体分割](../../ios/LoverOrder/Network/Services/ImageCutoutService.swift)、[上传服务](../../ios/LoverOrder/Network/Services/UploadService.swift)。

## 5. 备注和多图分散在餐次与个人评价中

餐次自身有备注，但更新只允许在准备中。餐后文字和图片放在个人评价中，提交评价必须带 1–5 分评分；记录面板优先展示备注和最多九张图片，口味位于后面；上传期间会锁定保存和关闭操作；从历史详情再次进入记录面板时会回填当前用户已有评价内容避免误覆盖。手动补录的照片也写入默认评分的评价。

影响：补充历史的文字和多图仍通过带评分的个人评价，缺少整顿记录层面的独立补充入口。已有的多图选择和展示能力可以承载部分用餐回忆，评分要求与直接记录备注、多图的产品方向仍有差距。

依据：[备注更新限制](../../backend/internal/service/meal_service.go)、[评价输入与保存要求](../../backend/internal/service/meal_service.go)、[多图入口](../../ios/LoverOrder/Features/Meal/MealReviewView.swift)、[图片展示](../../ios/LoverOrder/Features/History/HistoryDetailView.swift)、[手动补录](../../ios/LoverOrder/Features/History/ManualHistoryEntryView.swift)。

## 6. 首页文件仍包含未挂载的视图片段

记录列表已把场景筛选收进菜单，补录中的场景选择放在表单内，详情以日期和画布为主。首页文件仍定义心情选择、已确定卡片、取消重选、底栏以及未触发的建谱/邀请弹层（`showCreateRecipe`、`showInviteTicket`）等视图片段，`MealNowViewModel.load` 也仍发出了未被当前画布消费的推荐列表请求；菜谱文件中也有未使用的手账装饰组件（`HandmadePaper`、`HandDrawnUnderline`、`DoodleSprig`、`NotebookRule`），记录与组件库中亦保留少量未挂载的旧扩展（如 `MealScene` 历史扩展、`MoodChip`）。

影响：这些片段不能作为当前入口的依据。它们不影响本轮可见页面，按精准修改约束登记位置，不顺手重构或删除。

依据：[当前首页组成与未挂载片段](../../ios/LoverOrder/Features/Meal/MealNowView.swift)、[首页模型与推荐查询](../../ios/LoverOrder/Features/Meal/MealNowViewModel.swift)、[菜谱页及装饰组件](../../ios/LoverOrder/Features/Menu/MenuView.swift)。

## 7. 远端系统推送待生产 `.p8` 密钥启用，当前由通知流、WebSocket 传呼与本地富媒体横幅兜底

后端已落库 `device_tokens` 与 `notification_events`，支持加菜（45 秒连加合并）、定餐、完成、评价、来客点菜、成员入伙以及家庭日常成员间的阶段化主动提醒（`POST /api/v1/notifications/nudge`）与快捷轻回应（`POST /api/v1/notifications/reply`），并在双方在线浏览画布时经 WebSocket `canvas_nudge` 秒级推送桌面粒子/音效互动；iOS 端已配置 `aps-environment`、内置 3 款 `.caf` 定制提示音、交互式横幅快捷动作与 `lo://` 深链路由（含 `lo://shopping/` 直达买菜清单）。`backend/config.yaml` 默认 `apns.enabled: false`，未配置 Apple Push `.p8` 私钥前仅记录干跑日志，系统横幅（含菜品抠图/水粉贴纸缩略图附件）由客户端活跃期拉取 `/api/v1/notifications` 后本地触发及智能饭点定时通知承担；离线真后台远端静默唤醒需在真机签名后填入 `.p8` 参数启用（若需锁屏远端 APNs 直接下载远程图片附件，后续可按需扩展 Notification Service Extension，内置 `.caf` 音效与快捷回应类别在启用 `.p8` 后直接生效）。

依据：[APNs 配置与路由](../../backend/internal/config/config.go)、[通知推送服务](../../backend/internal/service/notification_service.go)、[通知管理器与深链](../../ios/LoverOrder/App/AppNotifications.swift)、[应用权限描述](../../ios/LoverOrder/Resources/LoverOrder.entitlements)。

## 接口和数据约束

接口和持久化场景值为 `household`、`dining`。首页当前进行中的餐次使用 `household`，开过房的餐次完成后归入 `dining`；提前关房保留用于识别的房间时间信息。这些字段按内部数据契约管理，本轮不变更字段或数据。

依据：[场景常量](../../backend/internal/model/meal.go)、[完成归档](../../backend/internal/service/meal_service.go)、[关房保留识别信息](../../backend/internal/service/dining_service.go)。
