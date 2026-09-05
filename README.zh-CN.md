# ForceGraphKit

ForceGraphKit 是原生 Swift 6 的确定性 1D、2D、3D 力导向图工具包。Linux Core 不依赖 UI、
渲染器、第三方运行时或 Apple framework。

## 安装与快速开始

通过 Swift Package Manager 添加本包并链接 `ForceGraphCore`；只有需要上层能力时才添加
`ForceGraphScene` 和 `ForceGraphRealityKit`。

```swift
import ForceGraphCore

var simulation = ForceSimulation(
  nodes: [ForceNode(id: "a"), ForceNode(id: "b")],
  dimensions: .three,
  seed: 42
)
simulation.replaceLinks([ForceLink(source: "a", target: "b", distance: 40)])
simulation.force("charge", .manyBody(strength: -20))
simulation.tick(iterations: 60)
let frame = simulation.snapshots()
```

稳定 ID 是状态所有权边界。由一个 actor 或任务独占可变 simulation/controller，并只在并发域之间
传递不可变、`Sendable` 的快照。

## 产品

- **ForceGraphCore**：确定性仿真、直接/Barnes–Hut 多体力、碰撞与链接力、空间查询、图增量、
  异步帧、边界和体积适配。
- **ForceGraphScene**：UI 中立的视觉、标签、过滤、选择/高亮、交互意图、同步端点、可逆坐标、
  拖拽生命周期和调度。
- **ForceGraphRealityKit**：可选且条件编译的 Apple 实体同步层，提供稳定类型化身份、共享网格、
  有界对象池和宿主控制标签。
- **force-graph-demo / force-graph-benchmark**：Linux 兼容的 JSON smoke 输出和诊断计时，仍可在
  仓库根目录使用 `swift run -c release <product>` 运行。

## 能力与验证状态

Linux release 构建和测试覆盖 Core/Scene 行为、确定性初始化与冷却、稳定端点解析、空间算法、
坐标映射和 scheduler 生命周期。D3 兼容是有明确范围的语义兼容，不代表 JavaScript 源码兼容
或完整数值一致。benchmark 只记录诊断结果，不作为单元测试时钟阈值。

RealityKit 源码与条件测试位于 platform/import guard 后。本仓库当前状态不声称已完成 Xcode、
Apple SDK、visionOS 模拟器、手势、compositor、Instruments 或真机验证；Apple 平台声明前请先
完成验收文档中的门槛。

Scene scheduler 使用 newest-frame 背压和单一 tick 循环。冷却只停止该循环，stream 保持 dormant，
直到 resume、restart 或力学场景更新唤醒。宿主生命周期结束时应 stop scheduler 或取消消费。

## 开发

```sh
swift build -c release
swift test -c release
swift run -c release force-graph-demo
swift run -c release force-graph-benchmark 100 1000 5000
python3 Scripts/validate-markdown-links.py --self-test
```

Markdown 检查仅验证受支持的本地链接目标存在；它忽略外链，也不验证标题锚点。

## 文档

从[文档导航](Documentation/README.md)开始，并参阅[快速入门](Documentation/GettingStarted.md)、
[架构](Documentation/Architecture.md)、[D3 兼容范围](Documentation/D3Compatibility.md)、
[功能矩阵](Documentation/FeatureMatrix.md)、[RealityKit 集成](Documentation/RealityKitIntegration.md)、
[性能](Documentation/Performance.md)和[visionOS 验收](Documentation/VisionOSAcceptance.md)。另见
[示例导航](Examples/README.md)、[仓库结构](Documentation/RepositoryLayout.md)和
[英文 README](README.md)。
