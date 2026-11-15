# 动态几何：ValueTracker 与 Updater

数学动画经常需要一个参数同时控制动点、切线、投影和标签。MoonManim 将参数轨道交给场景管理，在每帧采样动画后，按依赖顺序更新几何，再交给渲染器。核心逻辑支持 `native`、`js`、`wasm` 和 `wasm-gc`，不需要 Python。

## 参数与动画

`scene.add_tracker(value)` 返回所属场景内的 `ValueTracker` 句柄；通过 `scene.get_value`、`scene.set_value` 和 `scene.remove_tracker` 读写与删除。数值必须有限；跨场景和已删除的句柄报 `InvalidHandle`，删除后的槽位不会复用。

`value_to` 保存目标与缓动，起值在实际播放开始时读取。可以提前构造多个描述符，再依次播放：

```moonbit
let x = scene.add_tracker(-2.0)
let there = @scene.value_to(x, 2.0, easing=Linear)
let back = @scene.value_to(x, -2.0)
scene.play([], values=[there], duration=2.0)
scene.play([], values=[back], duration=1.0)
```

`values` 可以与原有对象动画同时使用；同一片段重复操作一个标量会在输出前报 `AnimationConflict`。`play_staggered` 只错开对象动画，标量始终使用整个片段的时长。

修改标量不会隐式运行用户回调。需要立即刷新时调用 `scene.update()`；它不输出帧，也不推进时间。

## 更新器与依赖

每个对象可以绑定一个 Updater。回调接受冻结上下文和对象当前局部状态，返回新的局部状态，可以替换路径、变换与样式；重复调用 `set_updater` 会替换该对象的旧回调。

```moonbit
let x = scene.add_tracker(-2.0)
let point = scene.add(@mobject.ObjectState::shape(@geometry.circle(0.08)))
scene.set_updater(point, (context, state) => {
  let value = context.get_value(x)
  {
    ..state,
    transform: @math.Affine2::translation(value, value * value / 4.0),
  }
}, trackers=[x])

let guide = scene.add(@mobject.ObjectState::shape(
  @geometry.line(@math.Vec3::zero(), @math.Vec3::zero()),
))
scene.set_updater(guide, (context, state) => {
  let p = context.world_transform(point).apply(@math.Vec3::zero())
  {
    ..state,
    path: Some(@geometry.line(@math.Vec3::new(p.x, 0.0), p)),
  }
}, depends_on=[point])
scene.play([], values=[@scene.value_to(x, 2.0)], duration=3.0)
```

声明 `depends_on` 中的对象和 `trackers` 中的标量后，通过以下接口读取：

| 接口 | 返回内容 |
| --- | --- |
| `context.get(id)` | 依赖对象在本轮求值后的局部状态 |
| `context.world_transform(id)` | 包括祖先更新在内的世界变换 |
| `context.get_value(tracker)` | 当前帧的标量值 |
| `context.time` | 由帧号计算的场景时间，秒 |
| `context.dt` | 本次固定帧步长，或显式刷新的 0 |

读取未声明的依赖会报错。数组在注册时复制；保留上下文不会使它随以后帧改变。回调应从上下文获取依赖；闭包直接读取其他场景状态的行为不在依赖调度保证之内。

注册顺序不必与依赖顺序一致。场景对更新器进行拓扑排序，同时考虑依赖对象和目标的祖先更新。因此，父组移动后，跟随子对象的标签会获得当帧世界位置。直接、自引用和通过祖先变换形成的循环都会被拒绝；失败的注册保留旧回调，失败的 `reparent` 保留旧层级。

单轮求值先暂存新状态，后续回调可以读取前面已暂存的依赖；全部回调成功且状态合法后才统一提交。请把外部副作用放在渲染或导出层：引擎无法回滚闭包写入的文件、数组或外部变量。

## 时间、暂停与生命周期

每段正时长播放仍按有理帧率向上量化。首帧更新的 `dt=0`；后续更新使用相邻整数帧时间之差。最后提交动画的精确目标，再以最后一个帧步长计算终点几何，不额外编码结束帧。

例如 4 fps 下 `wait(0.3)` 输出 `t=0`、`t=0.25` 两帧，并在编码时间 `t=0.5` 完成一次终点更新。下一段首帧也在 `t=0.5`，但 `dt=0`，因此积分不会重复推进。标量的终值仍精确等于请求值。`wait(0)`、零时长动画和 `scene.update()` 都只以 `dt=0` 刷新几何；`snapshot()` 始终只读。

纯函数更新器可根据参数和绝对时间计算几何；有状态更新器可用 `state` 和 `dt` 做固定步长积分。这里提供的是顺序求值，不支持对任意闭包自动 seek、重放或恢复随机数状态；不同帧率的积分误差也可能不同。

当一个对象参与对象动画时，与它有祖先或后代关系的 Updater 在整段播放及其终点提交期间暂停。其他依赖它的跟随对象继续运行，可以观察动画采样结果。下一段播放或手动 `update()` 时恢复，暂停期间的时间不会补算。若要解除绑定，调用 `scene.clear_updater(id)`。

删除对象或子树时，自动解绑目标或显式依赖已经失效的 Updater；删除标量时同样解绑读取它的 Updater。其他几何保留最后状态。FadeOut 完成时先求值终点，再移除子树并清理绑定。

对象、依赖、参数及动画预备错误在播放前报出，不推进时钟。用户回调只能返回对象状态，不能修改或重入正在运行的场景；渲染器也受相同保护。回调抛错或返回非法状态后，场景进入 `SceneFailed`，需要新建场景重试；已经交付的帧和外部副作用无法撤销。

## 割线趋近切线的完整示例

[src/cmd/dynamics/main.mbt](../src/cmd/dynamics/main.mbt) 使用两个标量控制抛物线 `f(x)=x²/4` 上的点和步长 `h`。黄色直线的斜率是精确差商 `(2x+h)/4`，在 `h=0` 处使用解析延拓 `x/2`，避免数值相消和除零。粉色点、绿色点、黄色直线和投影线由独立更新器求值，展示同帧几何依赖。

```sh
npm ci
npm run dynamics-stills   # 关键帧；不需要 FFmpeg
npm run dynamics          # 完整视频；需要 FFmpeg
```

产物位于 `output/dynamics/`：`01-tangent.mp4` 为 12 秒、1280×720、60 fps 的无声视频；`demo-contact-sheet.png` 为关键帧接触表。原始场景可直接运行 `moon run src/cmd/dynamics --target native --release --deny-warn` 输出流式 JSONL SVG 帧。Node/sharp 与 FFmpeg 仅负责光栅化和编码，所有几何、参数动画及 TeX 公式对象由 MoonBit 引擎生成。

设计参考本地 Manim CE 的 ValueTracker、Mobject Updater 与 Scene 更新生命周期，并采用适合 MoonBit 的场景所属句柄、静态类型回调及显式依赖声明。这里不承诺与 Python Manim 的任意回调行为兼容。
