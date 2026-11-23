# 自由画布方向与现有代码的对齐清单

本清单以[产品方向](../product-flow.md)为依据，记录对当前工作区的静态代码核对结果（2026-10-19 初版，后续随画布与抠图对齐迭代同步更新）。清单记录待对齐项；当前可操作的入口与行为见[画布功能说明](../features/home-canvas/feature.md)。

## 1. 双方共享的是菜单，完整画布仍各存本机

首页轮询餐次和菜单，变化判断包含状态、房间信息和菜 ID。布局、文字、背景、贴纸和笔画保存在本机 `UserDefaults`；后端餐次模型和路由没有对应的画布存储或读写能力。

影响：两人无法看到对方完整的画布操作；菜单同步不能视为同一张画布已经可以协作。画布同步暂不调整。

依据：[餐次同步](../../ios/LoverOrder/Features/Meal/MealNowView.swift)、[同步判断](../../ios/LoverOrder/Models/Meal.swift)、[本机画布存储](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)、[后端餐次模型](../../backend/internal/model/meal.go)、[餐次路由](../../backend/cmd/server/main.go)。

## 2. 来客仍进入独立点菜列表

加入成功后打开 `DiningGuestView`，页面只有参与信息、已点菜和点菜入口。外链与分享层面已补齐 `lo://room/<code>` URL Scheme 直达、`DiningHostView` 分享出口及来客入房/点菜动态通知；来客 API 也仅提供房间、菜谱和加减菜能力，没有共享画布内容操作。房间参与关系有时效，当前来客仍须登录。

影响：来客只能完善菜单，不能和日常参与者共同完善画布。来客能力暂不调整。是否需要免登录身份尚未确定，不能把“临时身份”直接解释成必须新增匿名账户。此外，主家提前关房会删除 `MealParticipant` 参与记录，历史详情通过合并家庭成员、加菜人和创建者兜底展示同行者，但来客权限与长期参与记录仍待产品规则明确。

依据：[入房后页面](../../ios/LoverOrder/Features/Meal/DiningJoinView.swift)、[来客页面](../../ios/LoverOrder/Features/Meal/DiningGuestView.swift)、[来客 API 与鉴权范围](../../backend/cmd/server/main.go)。

## 3. 历史画布依赖本机文档

记录卡片和详情已接入画布回看，按保存的尺寸还原背景、菜品、文字、图层和笔迹。画布文档仍按餐次存于当前手机；没有本机文档时省略画布区域。

影响：换手机或由另一位日常参与者打开历史时，不能据此取回这张画布。这个差距需要共享存储，按用户要求暂缓。

依据：[历史详情](../../ios/LoverOrder/Features/History/HistoryDetailView.swift)、[画布存储与回看](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)。

## 4. 已接入拍照与相册抠图，完整画布共享仍受本机存储限制

贴纸面板已按“手绘贴纸 → 我的贴图 → 表情”排列：内置 16 枚矢量/排版手绘 Plog 贴纸可自由上色与添加动效；“表情”标签已升级为 36 枚水粉白边模切手绘贴纸（按**精选 / 情绪 / 食光 / 氛围** 4 组陈列）；“我的贴图”同时提供“相册抠图”与“拍照做贴图”双入口——拍照与相册选图均调用苹果原生主体分割 `ImageCutoutService`（相册图片在主体分割失败时自动回退保留普通照片），上传后存入账号收藏并可直接添加到画布。收藏保存在账号下，可跨餐次和设备复用；独立贴图可移动、缩放、旋转、加特效、切换风格、复制、调图层、框选、20 步多步撤销/重做和删除，增删菜品时不会被清除，排版仍保存在本机画布文档中。菜谱主图也会自动生成独立保存的透明图，加入一顿时写入菜品快照供画布使用。

剩余差距：非菜品的贴纸、文字、涂鸦与画布整体排版仍受第 1、3 项所述本机存储限制，尚未做到两人或来客实时跨设备共同编辑。

依据：[画布与独立贴图](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)、[拍照贴图入口](../../ios/LoverOrder/Design/Components/PhotoStickerSheet.swift)、[原生主体分割](../../ios/LoverOrder/Network/Services/ImageCutoutService.swift)、[菜谱主图](../../ios/LoverOrder/Features/Menu/RecipeEditView.swift)。

## 5. 备注和多图分散在餐次与个人评价中

餐次自身有备注，但更新只允许在准备中。餐后文字和图片放在个人评价中，提交评价必须带 1–5 分评分；记录面板优先展示备注和最多九张图片，口味位于后面；上传期间会锁定保存和关闭操作；从历史详情再次进入记录面板时会回填当前用户已有评价内容避免误覆盖。手动补录的照片也写入默认评分的评价。

影响：补充历史的文字和多图仍通过带评分的个人评价，缺少整顿记录层面的独立补充入口。已有的多图选择和展示能力可以承载部分用餐回忆，评分要求与直接记录备注、多图的产品方向仍有差距。

依据：[备注更新限制](../../backend/internal/service/meal_service.go)、[评价输入与保存要求](../../backend/internal/service/meal_service.go)、[多图入口](../../ios/LoverOrder/Features/Meal/MealReviewView.swift)、[图片展示](../../ios/LoverOrder/Features/History/HistoryDetailView.swift)、[手动补录](../../ios/LoverOrder/Features/History/ManualHistoryEntryView.swift)。

## 6. 首页文件仍包含未挂载的视图片段

记录列表已把场景筛选收进菜单，补录中的场景选择放在表单内，详情以日期和画布为主。首页文件仍定义心情选择、已确定卡片、取消重选、底栏以及未触发的建谱/邀请弹层（`showCreateRecipe`、`showInviteTicket`）等视图片段，`MealNowViewModel.load` 也仍发出了未被当前画布消费的推荐列表请求；菜谱文件中也有未使用的手账装饰组件（`HandmadePaper`、`HandDrawnUnderline`、`DoodleSprig`、`NotebookRule`），记录与组件库中亦保留少量未挂载的旧扩展（如 `MealScene` 历史扩展、`MoodChip`）。

影响：这些片段不能作为当前入口的依据。它们不影响本轮可见页面，按精准修改约束登记位置，不顺手重构或删除。

依据：[当前首页组成与未挂载片段](../../ios/LoverOrder/Features/Meal/MealNowView.swift)、[首页模型与推荐查询](../../ios/LoverOrder/Features/Meal/MealNowViewModel.swift)、[菜谱页及装饰组件](../../ios/LoverOrder/Features/Menu/MenuView.swift)。

## 7. 远端系统推送待生产 `.p8` 密钥启用，当前由通知流与本地横幅兜底

后端已落库 `device_tokens` 与 `notification_events`，并在加菜、定餐、完成、评价、来客点菜与成员入伙事件发生时异步写入通知并尝试发送 APNs HTTP/2 请求；iOS 端已配置 `aps-environment` 并注册 `lo://` 深链路由。`backend/config.yaml` 默认 `apns.enabled: false`，未配置 Apple Push `.p8` 私钥与签名证书前仅记录干跑日志，系统横幅由客户端活跃期拉取 `/api/v1/notifications` 后本地触发及“演示提醒”/饭点定时本地通知承担；离线真后台远端静默唤醒推送需在真机签名后填入 `.p8` 参数启用。

依据：[APNs 配置与路由](../../backend/internal/config/config.go)、[通知推送服务](../../backend/internal/service/notification_service.go)、[通知管理器与深链](../../ios/LoverOrder/App/AppNotifications.swift)、[应用权限描述](../../ios/LoverOrder/Resources/LoverOrder.entitlements)。

## 接口和数据约束

接口和持久化场景值为 `household`、`dining`。首页当前进行中的餐次使用 `household`，开过房的餐次完成后归入 `dining`；提前关房保留用于识别的房间时间信息。这些字段按内部数据契约管理，本轮不变更字段或数据。

依据：[场景常量](../../backend/internal/model/meal.go)、[完成归档](../../backend/internal/service/meal_service.go)、[关房保留识别信息](../../backend/internal/service/dining_service.go)。
