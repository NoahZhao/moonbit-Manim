# 一份课程，视频与交互

本次完成的创新是把“看动画”与“操作模型”连接起来。首个案例是 12 秒的割线与切线课程，六个章节可播放、暂停、拖动或直接跳转。选择“自由探索”时接管当前的 x 和 h，返回讲解则恢复原来暂停的课程时刻。视频卡片的接管按钮支持从视频当前时刻进入探索。

## 定义与数据流

- `src/lesson/lesson.mbt`：可复用的参数描述、章节目标、缓动、参数校验与绝对时间采样。
- `src/lessons/tangent/tangent.mbt`：唯一的割线课程定义，包括 x/h 范围、章节、几何、TeX 公式和 1280×720 相机。
- `src/cmd/dynamics/main.mbt`：以 60 fps 采样课程并输出 JSONL SVG 帧。
- `src/cmd/web/dynamics.mbt`：缓存同一课程模型，提供讲解采样和自由探索接口。
- `site/app.js`：从课程元数据生成参数滑块和章节按钮，负责输入与播放时钟。

```moonbit
let lesson = @lesson.Lesson::new([
  { key: "h", label: "两点间距 h", initial: 2.0,
    min: 0.0, max: 2.0, step: 0.01, unit: "" },
], [
  @lesson.cue("观察割线", "两点确定一条割线。", 1.0),
  @lesson.cue("让 h 趋近零", "割线趋近切线。", 3.0,
    targets=[@lesson.to("h", 0.0)]),
])
let sample = lesson.sample(2.5)
let h = sample.get("h")
// 用 h 设置场景 tracker，然后 scene.update()。
```

`Lesson.sample(time)` 由绝对时间独立计算全部参数。有限的越界时间夹到首尾；非有限时间报错；章节边界归入下一章，最终端点归入最后一章。没有目标的参数保持上一章的终值。构造时冻结输入，拒绝未知、重复或越界目标及无效时长。`explore` 使用相同参数范围，允许滑块步长之外的连续值，以精确保留接管瞬间的状态。

交互课程中的 Updater 必须根据绝对参数重建状态，避免依赖上一帧或累加 `dt`。该接口目前支持有界标量参数与顺序章节，不会把任意闭包序列化，也不为已有的命令式 `Scene.play` 脚本提供通用倒放。其他五个实验尚未迁移为课程。

## 浏览器接口

```js
const schema = JSON.parse(MoonManim.describeLesson());
const frame = JSON.parse(MoonManim.renderLesson(0.2)); // 归一化进度
// frame: time, progress, chapter, title, phase, svg, values
```

`describeLesson` / `renderLesson` 当前对应首个割线课程。原有 `MoonManim.render("tangent", progress, x, initialGap, 0)` 接口保留兼容；自由探索以 progress=0 传入实际 h。

## 复现与验证

```sh
make check
make test
npm run site:build
npm run lesson:check
npm run site:check
npm run dynamics
npm run site:media
npm run site:serve
```

`lesson:check` 实际运行 native 离线适配器，与已编译的网页 JavaScript 在 10 个时刻比较章节、全部参数和所有 SVG 数值坐标，容差为 1e-7 像素。核心测试覆盖章节边界、输入冻结、无效目标、随机采样、探索隔离及逆向跳转。视频导出器添加的标题和字幕属于展示层，不参与几何一致性比较。

部署时须同时提交 `site/assets/engine.js`、视频及封面；GitHub Pages 不会自动编译 MoonBit。
