# HxCpp 二维渲染状态保存评估（待实测）

记录日期：2026 年 11 月 5 日。

状态：仅完成源码静态评估，未执行 C++ 编译、运行或性能测试，未为此修改实现。后续由用户测试 C++ 目标时确认。

## 评估结论

当前 HxCpp 路径仍存在逐批次读取 OpenGL 状态的开销。此前 Electron 性能修复只在 JS / HTML5 下启用，不能据此认为 C++ 目标的性能问题已经消除，也不能将 Electron 的耗时和优化比例直接用于 C++。

静态检查还发现原生接口的返回类型与 WebGL 不一致，需要在实测时优先确认属性读取及恢复是否正确。以下风险尚未通过 C++ 运行复现，不视为已经确认的运行故障。

## 源码依据与待确认风险

| 项目 | 静态确认的代码行为 | C++ 测试时需要确认 |
| --- | --- | --- |
| 状态缓存 | `GLStateCache3D` 仅在 `js && html5 && !hxmaker_3d_full_state_queries` 下启用，其他目标的 `obtain()` 返回 `null` | 状态读取是否成为主要 CPU 热点 |
| VAO 隔离 | `VertexArrayBridge3D` 的启用逻辑限定为 JS / HTML5，原生目标走逐属性保存与恢复 | 查询、属性重新绑定的耗时及原生 VAO 的适配必要性 |
| 常量顶点属性 | 状态保护代码将 `getVertexAttrib(..., CURRENT_VERTEX_ATTRIB)` 的返回值按四分量数组读取；本地 Lime 原生 `getVertexAttrib()` 则转调返回整数的 `getVertexAttribi()` | 是否出现读取或恢复异常；原生应核对 `getVertexAttribfv()` 与类型明确的四分量缓冲 |
| 属性缓冲绑定 | 状态保护代码将属性缓冲查询结果直接传给 `bindBuffer()`；本地 Lime 原生查询返回整数 ID，而绑定接口接收缓冲对象 | 句柄转换是否正确，是否产生无效绑定或运行异常 |

后端相关源码：

- [GLStateCache3D](../src/hx/render3d/openfl/GLStateCache3D.hx)
- [VertexArrayBridge3D](../src/hx/render3d/openfl/VertexArrayBridge3D.hx)
- [RenderStateGuard3D](../src/hx/render3d/openfl/RenderStateGuard3D.hx)
- [DirectBatchRenderer](../src/hx/render2d/openfl/DirectBatchRenderer.hx)

Lime 静态对照文件：本机 `/Users/rainy/Documents/haxelib-self/lime/src/lime/_internal/backend/native/NativeOpenGLRenderContext.hx`，重点核对 `getVertexAttrib()`、`getVertexAttribfv()`、`bindBuffer()` 及 `__getObjectID()`。更换 Lime 版本后应重新核对，不能假定所有版本行为一致。

## 状态读取数量估算

以下按当前二维直接提交路径计算，是状态读取接口的调用数量，不等于实际 GPU 同步次数，也不代表路径已经在原生正常运行。

| 批次类型 | 每批状态读取接口调用 |
| --- | ---: |
| 普通快速批次，保护 3 个属性 | 35 次 |
| 颜色变换或自定义 Shader，保护 A 个属性 | 14 + 8 × A 次 |
| 上一行假设设备支持 16 个属性 | 142 次 |

以上不包含纹理槽读取、初始化查询及恢复时的 OpenGL 调用。原生没有 Chromium GPU 进程通信这一层，实际成本仍取决于驱动、平台、批次数和场景，须单独测量。

## 后续 C++ 测试记录

测试工程和平台待用户确定；不默认依赖 Electron 的 MapEditor 可以直接构建为 C++ 应用。

- [ ] 记录操作系统、GPU / 驱动、Haxe / hxcpp / Lime / OpenFL 版本，以及 Debug / Release 配置。
- [ ] 确认可以完成首帧绘制，检查常量属性读取及缓冲绑定是否正常。
- [ ] 分别测试普通图片、多纹理合批、颜色变换和自定义 Shader。
- [ ] 检查与原生 OpenFL 对象交替绘制、遮罩、滤镜及离屏绘制后的状态恢复。
- [ ] 记录批次数、实际绘制调用数、状态读取次数，以及 CPU 平均耗时和 P95；区分完整帧耗时与渲染提交耗时。
- [ ] 如后续实施修复，以相同场景、窗口尺寸、绘制量和构建配置进行前后对照，并检查画面一致性。

测试结果：待补充。

后续若确认需要修复，继续将适配放在 hxmaker-openfl 后端，保持不修改 OpenFL 库的约束；优先保证原生接口和状态恢复正确，再评估 VAO 与状态缓存优化。

相关记录：[Electron 性能回退排查与实测](performance-20261105.md)。
