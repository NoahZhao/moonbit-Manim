# 当前引擎的视频示例

本文记录最初的三个基础示例。新增公式推导、矩阵变换和定理证明视频见 [数学教学说明](teaching.zh-CN.md)，输出位于 output/lessons。

所有示例均为 1280×720、60 fps、H.264/yuv420p 的无声 MP4。视频中的几何、时间推进、描绘、变形与组变换来自现有 MoonBit 核心。

| 文件（位于 output/videos） | 时长 | 观察点 |
| --- | --- | --- |
| 01-geometry.mp4 | 10.75 秒 | Create 描边；方形 → 圆 → 三角形；刚体旋转；颜色/填充插值；淡出 |
| 02-path-creation.mp4 | 8.8 秒 | 参数速度不均的直线；贝塞尔曲线；断开子路径；Linear 与 Smooth 的速度差别 |
| 03-group-transforms.mp4 | 11 秒 | 多个叶子对象同时描绘；嵌套变换；父节点旋转、平移和透明度 |
| 00-all-demos.mp4 | 30.55 秒 | 上述三段视频的连续合集 |

## 当前进度的含义

已经能够运行完整二维场景，逐帧生成后端无关状态与 SVG，并以稳定时钟完成基础动画。已有动画可以组合成这里展示的短片，且组与对象身份参与实际计算。

当前轮廓变形仍按顺序匹配，复杂形状之间的中间状态可能不自然。示例中的圆变三角形就可以用于观察这项限制，后续需要改进起点、方向及轮廓对应策略。

这些示例尚未覆盖公式、正文排版、Updater、坐标系绘图 API、三维或 GPU。背景网格由示例程序显式构造；标题、阶段文字和计时由视频导出器叠加，不能视为这些高级模块已经完成。

公式与坐标系的实际示例见 [教学开发说明](teaching.zh-CN.md)；ValueTracker / Updater 的割线到切线示例见 [动态几何开发说明](dynamics.zh-CN.md)。

## 导出流程

~~~text
MoonBit Scene.play / wait
  → MoonBit Frame 与 SVG 后端
  → JSONL 帧流
  → sharp 光栅化与示例标签
  → FFmpeg H.264 编码
  → MP4
~~~

场景入口：[main.mbt](../src/cmd/videos/main.mbt)。
场景定义：[scenes.mbt](../src/cmd/videos/scenes.mbt)。
导出器：[render-videos.cjs](../scripts/render-videos.cjs)。

导出器检查帧序号、流结束记录、帧尺寸、帧数与编码进程退出状态，并限制为逐帧读取与写入。它不会在 Node 中重新计算动画，也不会把整段视频的像素存入内存。生成的 manifest.json 记录每段的帧数、时长、大小和处理链。

## 重新生成

需要 MoonBit、Node.js、sharp 和含 libx264 的 FFmpeg。只使用核心库或 SVG 示例时不需要后两项。

在可找到这些工具与依赖的环境中执行：

~~~sh
make demo-videos
~~~

如果 sharp 或 FFmpeg 不在默认搜索路径中，可以显式指定：

~~~sh
NODE_PATH=/path/to/node_modules \
MOONMANIM_FFMPEG=/path/to/ffmpeg \
node scripts/render-videos.cjs
~~~

本次使用应用提供的 Node/sharp，以及安装在临时目录的 imageio-ffmpeg 0.6.0 所附 FFmpeg 7.1，未修改全局 Python 环境。临时工具清理后，重新导出需要再次提供编码器。

本次导出后还对三个单独文件和合集做了完整解码检查：帧数分别为 645、528、660 和 1833；尺寸及帧率全部符合预期。抽样画面同时保存在输出目录，validation.json 记录本次解码验证结果。
