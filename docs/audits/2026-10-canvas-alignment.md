# 自由画布方向与现有代码的对齐清单

本清单以[产品方向](../product-flow.md)为依据，记录 2026-10-19 对当前工作区的静态代码核对结果。清单记录待对齐项；当前可操作的入口与行为见[画布功能说明](../features/home-canvas/feature.md)。

## 1. 双方共享的是菜单，完整画布仍各存本机

首页轮询餐次和菜单，变化判断包含状态、房间信息和菜 ID。布局、文字、背景、贴纸和笔画保存在本机 `UserDefaults`；后端餐次模型和路由没有对应的画布存储或读写能力。

影响：两人无法看到对方完整的画布操作；菜单同步不能视为同一张画布已经可以协作。画布同步暂不调整。

依据：[餐次同步](../../ios/LoverOrder/Features/Meal/MealNowView.swift)、[同步判断](../../ios/LoverOrder/Models/Meal.swift)、[本机画布存储](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)、[后端餐次模型](../../backend/internal/model/meal.go)、[餐次路由](../../backend/cmd/server/main.go)。

## 2. 来客仍进入独立点菜列表

加入成功后打开 `DiningGuestView`，页面只有参与信息、已点菜和点菜入口。来客 API 也仅提供房间、菜谱和加减菜能力，没有共享画布内容操作。房间参与关系有时效，当前来客仍须登录。

影响：来客只能完善菜单，不能和日常参与者共同完善画布。来客能力暂不调整。是否需要免登录身份尚未确定，不能把“临时身份”直接解释成必须新增匿名账户。

依据：[入房后页面](../../ios/LoverOrder/Features/Meal/DiningJoinView.swift)、[来客页面](../../ios/LoverOrder/Features/Meal/DiningGuestView.swift)、[来客 API 与鉴权范围](../../backend/cmd/server/main.go)。

## 3. 历史画布依赖本机文档

记录卡片和详情已接入画布回看，按保存的尺寸还原背景、菜品、文字、图层和笔迹。画布文档仍按餐次存于当前手机；没有本机文档时省略画布区域。

影响：换手机或由另一位日常参与者打开历史时，不能据此取回这张画布。这个差距需要共享存储，按用户要求暂缓。

依据：[历史详情](../../ios/LoverOrder/Features/History/HistoryDetailView.swift)、[画布存储与回看](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)。

## 4. 已接入拍照抠图，独立图片仍有范围缺口

贴纸面板已增加“拍照做贴图”，使用苹果原生能力抠出主体，预览确认后上传透明 PNG，作为独立元素添加到画布。独立贴图可移动、缩放、旋转和删除，增删菜品时不会被清除；排版仍保存在本机画布文档中。菜谱主图也会自动生成独立保存的透明图，加入一顿时写入菜品快照供画布使用。

剩余差距：相册图片仍只能用作背景；独立图片入口目前只覆盖拍照抠图。画布整体共享和跨设备恢复仍受第 1、3 项所述本机存储限制，不能据此描述成已经支持任意图片或完整共同编辑。

依据：[画布与独立贴图](../../ios/LoverOrder/Features/Meal/MealCanvasView.swift)、[拍照贴图入口](../../ios/LoverOrder/Design/Components/PhotoStickerSheet.swift)、[原生主体分割](../../ios/LoverOrder/Network/Services/ImageCutoutService.swift)、[菜谱主图](../../ios/LoverOrder/Features/Menu/RecipeEditView.swift)。

## 5. 备注和多图分散在餐次与个人评价中

餐次自身有备注，但更新只允许在准备中。餐后文字和图片放在个人评价中，提交评价必须带 1–5 分评分；记录面板优先展示备注和最多九张图片，口味位于后面；上传期间会锁定保存和关闭操作。手动补录的照片也写入默认评分的评价。

影响：补充历史的文字和多图仍通过带评分的个人评价，缺少整顿记录层面的独立补充入口。已有的多图选择和展示能力可以承载部分用餐回忆，评分要求与直接记录备注、多图的产品方向仍有差距。

依据：[备注更新限制](../../backend/internal/service/meal_service.go)、[评价输入与保存要求](../../backend/internal/service/meal_service.go)、[多图入口](../../ios/LoverOrder/Features/Meal/MealReviewView.swift)、[图片展示](../../ios/LoverOrder/Features/History/HistoryDetailView.swift)、[手动补录](../../ios/LoverOrder/Features/History/ManualHistoryEntryView.swift)。

## 6. 首页文件仍包含未挂载的视图片段

记录列表已把场景筛选收进菜单，补录中的场景选择放在表单内，详情以日期和画布为主。首页文件仍定义心情选择、已确定卡片、取消重选、底栏等视图片段，当前首页没有挂载它们；菜谱文件中也有未使用的手账装饰组件。

影响：这些片段不能作为当前入口的依据。它们不影响本轮可见页面，按精准修改约束登记位置，不顺手重构或删除。

依据：[当前首页组成与未挂载片段](../../ios/LoverOrder/Features/Meal/MealNowView.swift)、[菜谱页及装饰组件](../../ios/LoverOrder/Features/Menu/MenuView.swift)。

## 接口和数据约束

接口和持久化场景值为 `household`、`dining`。首页当前进行中的餐次使用 `household`，开过房的餐次完成后归入 `dining`；提前关房保留用于识别的房间时间信息。这些字段按内部数据契约管理，本轮不变更字段或数据。

依据：[场景常量](../../backend/internal/model/meal.go)、[完成归档](../../backend/internal/service/meal_service.go)、[关房保留识别信息](../../backend/internal/service/dining_service.go)。
