# MoonManim

用 MoonBit 逐步构建面向数学讲解的程序化动画引擎，目标是具备 3b1b Manim 式的几何表达、动画编排和离线制作能力。

当前已具备二维几何与动画核心、坐标平面与函数绘图、语义公式项动画、ValueTracker 与依赖排序 Updater，以及完整数学教学案例。数学、对象、时间、场景和逐帧 SVG 均由 MoonBit 实现，运行核心不需要 Python、浏览器或第三方 Mooncakes 依赖。公式由构建时 MathJax 排版为路径；离线视频由 Node/sharp 与 FFmpeg 导出。

## 项目展示网站

[访问 MoonManim 展示站](https://noahzhao.github.io/moonbit-Manim/)，探索六个交互项目：矩阵变换、贝塞尔曲线、勾股定理、割线与切线、利萨如曲线及几何变形，观看八段数学动画，其中新增 CNN 卷积核滑动与特征图演示。支持项目直达链接、调整参数、拖动进度、导出 SVG，并适配手机屏幕。

本地预览：`npm run site:serve`，打开 http://127.0.0.1:4173/moonbit-Manim/。网站源码位于 `site/`；首次部署需要在仓库 Settings → Pages 中选择 GitHub Actions，详见 [网站维护与部署说明](docs/website.zh-CN.md)。

## 快速运行

本项目使用当前 MoonBit 文本格式的 moon.mod / moon.pkg。已验证工具链：

- moon 0.1.20261104
- moonc v0.10.20+65efd5b93

在仓库根目录运行：

~~~sh
moon check --target all --deny-warn
moon test --target all --deny-warn
mkdir -p output
moon run src/cmd/demo --target native --deny-warn > output/foundation.svg
~~~

基础示例实际求值 225 帧，仅保存其中 6 个检查点，组合成一张 SVG：方形淡入 → 方形变圆 → 平移 → 淡出。可以用本地图像查看器打开 output/foundation.svg。这两个基础示例输出 SVG；完整视频示例见下文。

运行 make demo 会同时生成 output/foundation.svg 和 output/create.svg；后者求值 121 帧，展示曲线按弧长逐步描绘，灰框来自解析计算的曲线边界。make demo-create 可以单独运行描绘示例。

也可以运行 make check、make test。make test 还会验证 native release，覆盖本机调试和发布构建的差异。

## Demo 视频

目前已生成三段 1280×720、60 fps 的无声 MP4，以及一个 30.55 秒的合集：

- output/videos/01-geometry.mp4：方形、圆、三角形之间的变形及旋转，10.75 秒。
- output/videos/02-path-creation.mp4：线性/平滑缓动下的弧长描绘及断开子路径，8.8 秒。
- output/videos/03-group-transforms.mp4：并行动画、嵌套组旋转、平移与透明度，11 秒。
- output/videos/00-all-demos.mp4：全部示例合集。
- output/cnn/01-cnn.mp4：5×5 输入、3×3 卷积核与 3×3 特征图的无声演示，10.45 秒。

场景源码位于 src/cmd/videos。每一帧由 MoonBit 场景运行器和 SVG 后端生成，scripts/render-videos.cjs 使用 sharp 光栅化并通过 FFmpeg 编码，按帧流式处理。标题、阶段说明和计时是导出器添加的展示标签，不代表文本 API 或 LaTeX 已实现。完整说明见 [视频示例说明](docs/demo-videos.md)。

重新导出需要 Node.js、sharp 和 FFmpeg。设置 NODE_PATH 指向包含 sharp 的 node_modules，设置 MOONMANIM_FFMPEG 指向编码器，然后执行 make demo-videos；若依赖已经可以直接找到，也可直接运行该目标。

## 代码结构

~~~text
moon.mod                   模块配置；默认 native，代码位于 src
src/
  errors/                  公共错误类型
  math/                    Vec3、Affine2、数值工具
  geometry/                贝塞尔路径、解析边界、弧长度量、部分路径、变形
  coordinates/             坐标映射、网格、坐标轴和函数采样
  mobject/                 Color、Style、ObjectState、ObjectId、Store
  animation/               描述符、缓动、预备动画与无状态采样
  timeline/                有理帧率与帧时钟
  render/                  Frame、Renderer、Camera2D、SVG 参考后端
  scene/                   顺序场景运行器、标量轨道、动态几何依赖与播放生命周期
  text/                    TeX 矢量资产、基线布局、语义公式项匹配
  teaching/                公式资产与可验证的勾股定理拼图构造
  cmd/demo/                完整基础场景
  cmd/create/              按弧长描绘与解析边界示例
  cmd/videos/              三个完整视频场景与 JSONL 帧流
  cmd/lessons/             配方法、矩阵变换、勾股定理教学场景
  cmd/dynamics/            ValueTracker 驱动的动点、割线极限与切线
  cmd/web/                 浏览器交互实验与 JavaScript 桥接
assets/tex/                TeX 片段、路径资产和上游许可
site/                      GitHub Pages 展示站、浏览器运行时与精选视频
scripts/compile-tex.cjs     构建时 TeX → 三次贝塞尔资产
scripts/render-videos.cjs   示例视频导出适配器
docs/architecture.zh-CN.md  长期架构设计
manim-main/                原有 CE 参考源码；不参与 MoonBit 构建
~~~

依赖方向：math → geometry → mobject → animation；scene 组合这些能力及 timeline、render；text 在场景层之上提供公式布局与转场。渲染接口不依赖场景运行器，核心不持有原生图形指针。

pkg.generated.mbti 是工具链生成的公开 API 清单，可用 moon info --target all 更新与检查各目标接口。

## 编写场景

以下代码可作为一个 executable 包的 main.mbt。该包需要导入示例中使用的 scene、animation、geometry、mobject、render 包，配置方式见 src/cmd/demo/moon.pkg。

~~~moonbit
fn main raise {
  let camera = @render.Camera2D::new()
  let renderer = @render.SvgRenderer::new(camera, (index, svg) => {
    // 示例只输出一个检查点；生产输出器可在这里逐帧写文件。
    if index == 90L { println(svg) }
  })
  let scene = @scene.Scene::new(renderer)
  let square = scene.add(
    @mobject.ObjectState::shape(@geometry.square(2.0)),
  )
  let circle = @mobject.ObjectState::shape(
    @geometry.circle(1.0),
    style={
      ..@mobject.Style::default(),
      stroke: @mobject.Color::pink(),
      fill: @mobject.Color::pink(),
      fill_opacity: 0.3,
    },
  )
  scene.play([@animation.create(square)], duration=1.0)
  scene.play([@animation.transform(square, circle)], duration=1.0)
  scene.play([@animation.fade_out(square)], duration=0.5)
}
~~~

自定义后端实现 render.Renderer trait，接收冻结的 Frame。帧中的路径、样式和对象列表不可变，可以保留用于检查；默认运行器逐帧推送，不缓存整段动画。输出接口同步执行，自然产生背压，并允许传播文件或编码器错误。

## 动态几何与导数示例

一个标量轨道可以同时驱动多个对象。Updater 返回新的对象状态，依赖项在同一帧内先完成更新；函数曲线上的动点、切线和投影线无需手动编写逐帧循环。

~~~moonbit
let x = scene.add_tracker(-2.0)
let dot = scene.add(@mobject.ObjectState::shape(@geometry.circle(0.08)))
scene.set_updater(dot, (context, state) => {
  let value = context.get_value(x)
  {
    ..state,
    transform: @math.Affine2::translation(value, value * value / 4.0),
  }
}, trackers=[x])
scene.play([], values=[@scene.value_to(x, 2.0, easing=Linear)], duration=3.0)
scene.wait(0.5)
~~~

首个创新案例：**同一份课程生成视频与交互网页**。打开 [割线与切线课程](https://noahzhao.github.io/moonbit-Manim/?scene=tangent#playground)，跟随六个讲解章节，随时切换到“自由探索”接管当前参数，再返回暂停的位置继续。视频卡片上的“在视频当前时刻自由探索”可直接接续视频进度。[实现与复现说明](docs/lessons.zh-CN.md)。

运行 `npm run dynamics` 或 `make dynamics-videos`，导出 **33.9 秒、720p60** 的割线到切线动画：两个参数控制动点位置和两点间距，展示差商趋近导数。视频位于 `output/dynamics/01-tangent.mp4`。`npm run dynamics-stills` 只生成关键帧与接触表，无需 FFmpeg。公式是引擎内的 TeX 矢量对象；导出器添加标题、阶段字幕与计时。

完整示例位于 [src/cmd/dynamics](src/cmd/dynamics/main.mbt)，时钟、依赖声明、冲突和生命周期语义见 [动态几何开发说明](docs/dynamics.zh-CN.md)。

## 已实现的行为契约

- Vec3 使用 Double，保留 Z 以便后续扩展；当前场景变换和相机是二维 XY。Shift 不接受非零 Z，三维还未实现。
- Affine2 使用列向量。a.compose(b) 表示先应用 b，再应用 a；旋转参数为弧度。
- 路径使用三次贝塞尔曲线。线段精确升阶；圆由四段三次曲线近似，最大径向误差约为半径的 0.000273 倍。
- Contour 必须连续，闭合轮廓必须显式回到起点；构造时拷贝输入数组，随后只暴露只读数据。
- Cubic.subsegment 按 de Casteljau 精确提取参数区间，保留三次曲线表示。Cubic.bounds / Path.bounds 通过三个坐标导数的根计算边界，不使用控制点包围盒；空路径返回 None。
- Path.measure 在播放前建立自适应弧长索引，使用弦长/控制多边形长度之差分配绝对误差预算。默认容差为 1.0e-6 个度量空间单位，最大细分深度为 30、总叶片上限为 65536；超限明确报错。uncertainty 是细分估计的不确定度，不是包含浮点舍入的区间认证。
- PathMeasure.point_at / partial 按弧长比例定位，支持参数速度不均的直线、回折曲线、多段路径与多个断开的子路径。metric_transform 可指定世界坐标等度量空间，返回的点与路径仍保留源坐标。部分轮廓保持开放，选中完整轮廓时保留闭合状态；[0,1] 精确保留原路径。
- PathMorph 在准备阶段细分曲线，对齐对应轮廓的段数，保留输入与精确端点。第一版按轮廓顺序匹配，要求轮廓数量和闭合状态一致。
- Store 采用带所属存储和 generation 的稳定句柄，拒绝跨场景或已删除的句柄。删除父节点会删除子树；槽位重用不会使旧句柄重新生效。
- 组构成拥有式树，拒绝循环。重新设置父节点保留局部变换。父节点影响子节点的变换和透明度；绘制顺序为全局 z_index，再按加入顺序排序。
- 透明度按祖先乘积传播，当前不实现隔离组的离屏透明合成。描边宽度固定为输出像素；默认线帽、连接为圆形。
- Transform、Shift、Rotate、FadeIn、FadeOut、Create、Write、ApplyAffine 已接入 Scene.play。源快照在实际播放开始时获取，采样不修改起始或目标数据，非有限进度会报错。
- Create 对叶子矢量对象按世界弧长描绘，包含自身及祖先的非均匀缩放。Linear 缓动给出恒定弧长速度；默认 Smooth 会调制速度。部分路径暂不填充，完成时恢复精确原路径、变换和样式；不新建或替换对象身份。
- Transform 保留源 ObjectId，并在完成时提交目标状态；不将目标作为第二个场景对象插入。带子节点的对象暂不支持 Transform，可通过 Shift/Rotate/Fade 操作整组。
- 显式 Rotate 插值角度，保留刚体旋转。一般 Transform 将两端的局部变换烘焙入路径后做几何插值；需要刚体运动时使用 Rotate。
- 同一次 play 的动画共享时钟，play_staggered 支持错开启动，并以指定总时长完成。拒绝相同对象或祖先/后代的并行动画。缓动提供 Linear 和五次 Smooth。
- Scene 拥有 ValueTracker，拒绝跨场景、删除后的句柄以及非有限数值。value_to 在播放开始时获取起值，通过 play 的 values 参数与对象动画共享时钟；同一标量的并行动画报冲突。play_staggered 中的标量使用整段时长，不参与对象错开。
- Updater 通过显式对象和标量依赖构成有向无环图，自动考虑祖先变换并拒绝循环。每个对象最多绑定一个 Updater；上下文只允许读取已声明的依赖，提供冻结的局部状态、世界变换、时间和 dt。回调分阶段求值，整轮成功后才提交几何状态。
- 每帧先采样动画，再计算动态几何，最后渲染；wait 同样执行 Updater。被动画操作的对象及其祖先/后代 Updater 暂停到该片段结束，其他跟随对象继续更新。删除对象、子树或标量后，自动解绑引用失效依赖的 Updater，保留其他对象的当前几何。
- Updater 首帧 dt=0，后续按有理帧率推进；精确端点额外计算一次几何但不输出帧。端点时间使用向上量化后的场景时间；零时长片段和 Scene.update 以 dt=0 刷新。snapshot 只读取，不触发回调。
- ApplyAffine 支持整组的矩阵动画；Write 支持矢量轮廓描写和填充显现。MathTex 可按显式语义 key 匹配相同公式项并保留身份，不同字形使用替换和淡入淡出。
- 所有正时长片段独立向上量化到整帧；采样区间为 [0,duration)，完成时提交精确端点，不重复编码一个结束帧。逻辑时间由已输出帧数与有理帧率决定。
- duration=0 提交结束状态并执行清理，不输出帧。FadeOut 完成后移除对象及其子树。
- 场景输入和动画预备错误在输出前发生，不改变对象或推进时间。Renderer 回调可以读取状态，但不能修改或重入场景。
- 渲染或 Updater 回调发生错误后，Scene 进入失败状态并停止接受播放和修改；已写入的外部数据及用户闭包副作用无法回滚，重试需重新构造场景和输出器。frame_index 只统计成功交付的帧。

## 验证

目前包含 85 项测试，覆盖几何、弧长、不可变快照、对象生命周期、动画时钟与错误隔离，以及错开播放、矩阵动画、公式项匹配、坐标映射、绘图断点、定理拼图、标量驱动、依赖循环、父组变换、更新暂停、删除清理和有理帧率的动态端点。新增课程的章节边界、任意时刻采样、参数校验、探索隔离与逆向拖动恢复检查。弧长使用有解析解的抛物线独立验证；勾股定理重排使用面积与覆盖检查验证。

~~~sh
moon fmt --check
moon test --target all --deny-warn
moon test --target native --release --deny-warn
~~~

## 数学教学案例

新增三段 720p60 教学动画：配方法求根（19.3 秒）、矩阵与行列式（18 秒）、勾股定理面积重排（21.3 秒）。合集位于 output/lessons/00-all-lessons.mp4。

~~~sh
npm ci
make lesson-stills  # 检查关键帧，不需要 FFmpeg
make lesson-videos  # 需要 PATH 中存在 FFmpeg，或设置 MOONMANIM_FFMPEG
~~~

公式资产已提交，仅运行 MoonBit 无需 npm。编辑 assets/tex/fragments.json 后，用 make tex-assets 重编译公式。教学 API、公式项匹配语义和限制见 [教学开发说明](docs/teaching.zh-CN.md)。

## 下一阶段

基础核心之后，按以下顺序扩展：

1. 原生 Cairo 后端、像素帧与流式视频编码，形成离线视频闭环。
2. 在现有 ValueTracker / Updater 基础上扩展移动相机、轨迹与动态数值标签。
3. 通用 SVG 导入、运行时公式编译、完整公式布局与字形匹配。
4. 更丰富的动画组合、布局和缓存，之后再推进三维和 GPU。

当前尚未提供原生 Cairo、引擎内置视频编码、运行时 TeX 编译、移动相机、任意拓扑匹配或完整 Manim 兼容层。Updater 支持顺序求值与固定帧步长，不承诺任意闭包可跳转时间或自动重放。示例视频通过独立适配器编码，后续会将媒体输出接入正式引擎工作流。

## 许可证

本项目原创代码采用 [MIT 许可证](LICENSE)，版权归 MoonManim contributors 所有。

第三方依赖和资产遵循各自的许可证。MathJax 生成的公式矢量资产保留其 Apache-2.0 许可与来源说明，详见 [公式资产来源](assets/tex/NOTICE.md) 和 [MathJax 许可证](assets/tex/MATHJAX-LICENSE.txt)。
