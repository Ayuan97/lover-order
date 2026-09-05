# Lover Order Agent Guide

## 产品边界

当前产品只有两种场景：

- `household`：家庭餐次，家庭可以由两人或多人组成。
- `dining`：家庭餐次的临时聚餐变体，朋友通过点菜房间加入。

首页固定服务 `household` 当前餐次。聚餐通过临时房间进入，不新增第三种场景，也不恢复已经删除的功能入口。

## 代码约束

- 场景名称和持久化值统一使用 `household`、`dining`。
- 不新增旧场景别名、兼容分支或“以后想吃”入口。
- 画布交互优先保证选中、取消选中、拖动和工具面板之间的状态清晰。
- 文案、页面和文档必须以当前真实入口为准。

## 验证命令

```sh
xcodebuild -project ios/LoverOrder.xcodeproj -scheme LoverOrder -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/lover-order-build build CODE_SIGNING_ALLOWED=NO
(cd backend && go test ./...)
```

## 工作区卫生

不要提交模拟器构建产物、截图、`.idea/`、`.xcodebuildmcp/` 或其他本地临时文件。
