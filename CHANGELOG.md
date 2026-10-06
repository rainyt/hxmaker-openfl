# 更新日志

## 1.0.0 (2026-10-06)

hxmaker-openfl 首个正式版本。hxmaker-openfl 是 hxmaker 游戏引擎的 OpenFL 渲染后端，将 hxmaker 的显示列表渲染到 OpenFL 各个目标平台上，与 hxmaker 1.0.0 配套发布。

### 渲染核心

- 完整实现 hxmaker 显示列表的 OpenFL 渲染：Image、Quad、Graphics、Label、MovieClip、Spine、Particle 等全部显示对象
- 多纹理渲染，大幅减少 drawcall，支持多纹理开关
- `FastShader` / `MultiTextureFastShader` 快速着色器，渲染性能直接提升约 19.2%
- `NativeShader` 原生着色器、自定义着色器支持（openfl-glsl），着色器支持 `precision highp float`
- 引擎架构重构：Render 纯渲染器、`MakerDisplay` 渲染器、useDrawElements 渲染路径
- 性能验证样例：兔子测试用例可达 40000 只

### 混合模式与滤镜

- 完整支持 hxmaker 的 15 种 `BlendMode` 混合模式（Normal、Add、Multiply、Screen、Difference、Subtract、Invert、Darken、Lighten、Layer、Alpha、Erase、Hardlight、Overlay 等）
- 滤镜支持：
  - `BlurFilter` 模糊滤镜（精细化控制）
  - `KawaseBloomShader` Bloom 泛光滤镜
  - `StrokeFilter` 描边滤镜（位图描边，兼容无描边效果的机型）
  - `InvertShader` 反色滤镜
  - 灰度滤镜
- `cacheAsBitmap` 缓存位图渲染（含遮罩处理、内存泄漏修复）、renderToBitmapData

### 文本

- 文本离屏渲染与重绘机制，支持多个缓存文本
- 纹理字渲染：支持大量纹理字渲染处理，文本纹理独立 prepare 时机与清理
- 描边、字体加粗、平滑处理、自定义平滑属性
- wordWrap 换行、charBounds 字符测量、fontSize 真实大小兼容

### 资源与纹理

- ASTC 纹理加载与平台检测
- OpenFLBitmapData 位图读取、原生 Bitmap 自定义访问
- 资源引用数调试与统计、缓存机制

### 事件

- 右键事件支持、删除键支持
- 焦点对象触发键盘事件、焦点事件
- `TouchEvent`、`UncaughtErrorEvent` 全局异常处理
- stage 事件统一分发

### 平台支持

- HTML5、微信小游戏（本地加载、微信音频播放）
- C++ 原生目标（Windows、macOS、Android、iOS）编译兼容
- 4399 游戏平台编译支持
- 鸿蒙 hap-html5 目标（HTML5 包装版本）
- window 与 mac 开发环境兼容

### 统计与调试

- `ContextStats` 渲染统计：drawCall、顶点数量、内存值、CPU 统计
- blendFilter / renderToBitmapData 渲染次数统计
- FPS 统计修复、加载调试器
- lockLandscape 横屏锁定、devicePixelRatio、highDpi、frameRate 帧率设置

### 样例与测试用例

- 提供完整 samples 示例与测试用例：全部类型对象渲染、多纹理特性、ListView/Tree/虚拟列表/流布局虚拟测试、粒子（下雨、精灵球）、Spine 渲染、线段绘制等

### 安装

```bash
haxelib install hxmaker-openfl
```

需搭配引擎核心 [hxmaker](https://github.com/rainyt/hxmaker) 使用。
