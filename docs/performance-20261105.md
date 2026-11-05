# MapEditor 二维渲染性能回退排查

2026 年 11 月 5 日，使用 `/Users/rainy/Documents/haxelib-self/mapeditorproject` 的真实 Electron 界面进行对照。修复仅涉及 hxmaker-openfl，未修改 OpenFL 库和 MapEditor 源码。

## 原因

用户提供的 `Trace-20261105T102205.json.gz` 中，渲染进程 CPU 采样窗口约 5058 毫秒，`getVertexAttrib` 的自身耗时合计约 3587 毫秒，占窗口的 70.9%。调用栈指向 `RenderStateGuard3D` 构造函数。

上一轮为正确恢复自定义材质的常量顶点属性，在每个材质批次前查询全部属性。测试设备支持 16 个顶点属性，因此空界面每帧产生 256 次查询，gowns 地图每帧产生 592 次查询。这些查询反复同步 GPU，成为主要耗时。

## 修复

- 在已有 WebGL 状态缓存中跟踪 `vertexAttrib1f` 至 `vertexAttrib4f` 以及对应的向量写入。
- 未知属性首次查询真实值，之后读取缓存；数值按 Float32 精度保存。
- 更新时替换缓存数组，保证正在使用的恢复快照不会被后续写入覆盖。
- 常量属性独立于 VAO 保存，设备丢失或恢复后清空缓存。
- 原生目标及 `hxmaker_3d_full_state_queries` 保留完整查询路径。

## 测量方法

基准为后端提交 `8edcdcd`，修复版使用本次工作区代码。两版均使用同一份 MapEditor 当前源码和已有开发构建参数编译到临时目录，不改动编辑器内尚未提交的功能修改。

环境：Haxe 4.3.7、项目已安装的 Electron、Chromium WebGL 2、16 个顶点属性、1440 × 868 内容区域、设备像素比 2。每个场景预热后测量约 4 秒。独立测试用户目录与 GUID 缓存均位于 `/private/tmp/hxmaker-mapeditor-perf-20261105`。

打开 `unity-test/Art/Build6/PrefabReview/gowns.prefab`。三个场景分别为空界面、地图静止、通过编辑器已有 `applyView()` 方法持续平移。为避免静止界面的按需重绘导致样本不足，两版均在动画回调中请求重绘；平移只修改镜头，不修改或保存地图文档。

下表耗时是 `OpenGLRenderer.__render()` 的 CPU 墙钟时间，包含提交时的同步等待，不是完整帧耗时，也不是 GPU 执行时间。

| 场景 | 基准平均耗时 | 修复平均耗时 | 基准 P95 | 修复 P95 | 平均耗时降低 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 空界面 | 15.88 毫秒 | 0.50 毫秒 | 19.30 毫秒 | 0.60 毫秒 | 96.9% |
| gowns 静止 | 34.68 毫秒 | 1.24 毫秒 | 40.60 毫秒 | 1.50 毫秒 | 96.4% |
| gowns 平移 | 33.15 毫秒 | 1.23 毫秒 | 36.90 毫秒 | 1.40 毫秒 | 96.3% |

基准各场景样本数为 231 / 107 / 111，修复版为 463 / 455 / 452。预热后的 `getVertexAttrib` 查询从每帧 256 / 592 / 592 次降至 0。两版每帧实际 `drawElements` 调用均为 17 / 55 / 55，未通过减少绘制量获得收益。

## 正确性验证

- 真实 WebGL 上的 8 项标量与向量属性读写对照通过。
- 快照不被覆盖、属性独立于 VAO、属性恢复 3 项对照通过。
- 三个场景测量结束时均未发现 WebGL 错误。
- 空界面与 gowns 静止视口各比较 1621536 个像素；允许每通道 1 个色阶的截图误差，超差像素为 0。
- MapEditor 开发构建通过；已有 hxnodejs 弃用警告不属于此次改动。

本次实测覆盖 macOS Electron WebGL 2，不将上述数值推广到其他设备、原生目标或其他地图规模。

原始数据：[基准](../artifacts/performance-20261105/baseline-results.json)、[修复版](../artifacts/performance-20261105/fixed-results.json)、[汇总](../artifacts/performance-20261105/comparison.json)。视口截图：[基准](../artifacts/performance-20261105/baseline-gowns-idle.png)、[修复版](../artifacts/performance-20261105/fixed-gowns-idle.png)。
