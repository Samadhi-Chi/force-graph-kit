# ForceGraphKit

ForceGraphKit 是一个原生 Swift 6 力导向图工具包，不依赖 JavaScript、WebView、Three.js
或其他运行时库。它面向需要确定性布局、稳定节点身份和原生 Apple 渲染边界的应用，同时保持
算法核心可在 Linux 上构建和测试。

## 模块

- **ForceGraphCore**：1D/2D/3D 仿真、D3 风格冷却和固定坐标、直接计算与 Barnes–Hut
  多体力、碰撞与链接力、空间查询、增量更新、异步帧流、边界和体积适配。
- **ForceGraphScene**：与 UI 框架无关的节点/边视觉信息、标签、显示状态、选择、邻居高亮、
  聚焦/详情/适配意图，以及拖拽固定和释放策略。
- **ForceGraphRealityKit**：条件编译的 RealityKit 实体同步源代码。当前 Linux 环境没有
  Apple SDK，因此尚未通过 Xcode、visionOS 模拟器或 Vision Pro 真机验证。

## 快速开始

```swift
import ForceGraphCore

var simulation = ForceSimulation(
    nodes: (0..<100).map { ForceNode(id: $0) },
    dimensions: .three,
    seed: 1
)
simulation.force("charge", .manyBody(
    strength: -20,
    algorithm: .barnesHut(theta: 0.9, directThreshold: 32)
))
simulation.tick(iterations: 100)
let snapshots = simulation.snapshots()
```

节点 ID 必须在应用生命周期中保持稳定。布局运行时，请让一个 actor 或任务独占可变的
`ForceSimulation`；跨并发域只传递不可变快照。需要拖拽时，通过 `ForceGraphController`
设置 `fx/fy/fz`、提高 `alphaTarget`，持续 tick，让相邻节点响应链接力，然后释放或保留固定点。

## 性能和兼容范围

多体力在小图上使用精确的 O(n²) 直接模式，在较大图上默认使用确定性的维度通用
Barnes–Hut 树。常量半径碰撞仍为 O(n²)；按节点缓存半径的版本使用空间索引做粗筛。
Swift 值提供器只在创建力时计算并缓存；相关元数据变化后需要重新创建该力。半径查询会剪枝
空间树；最近节点查询目前仍线性扫描经过验证的点，不声称具有对数复杂度。

本项目追求经过测试的 D3 语义兼容，不追求 JavaScript 源码兼容，也不实现浏览器事件、
WebGL 材质或网页式摄像机控制。完整差异请阅读 `D3_COMPATIBILITY.md` 和
`FEATURE_MATRIX.md`。

## 验证边界

当前里程碑在 Linux 上验证 `ForceGraphCore`、`ForceGraphScene`、JSON 演示程序和基准程序。
RealityKit 源代码仅经过条件编译边界和代码审查；Apple API 编译、体积窗口、点击与空间拖拽、
辅助功能、模拟器性能和 Vision Pro 真机体验仍是发布前验收项。详见：

- `GETTING_STARTED.md`
- `PERFORMANCE.md`
- `REALITYKIT_INTEGRATION.md`
- `VISIONOS_ACCEPTANCE.md`
