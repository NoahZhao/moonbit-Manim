# 数学教学与公式动画

本阶段把数学教学建立在引擎 API 上：公式是可寻址的矢量对象，坐标平面是实际路径，定理案例的几何拼图来自可测试的构造。核心仍由 MoonBit 实现，教学场景不依赖浏览器或 Python。

## 四个案例

| 场景 | 数学内容 | 引擎能力 | 视频 |
| --- | --- | --- | --- |
| formula | x² + 6x = 7 → 两边加 9 → (x+3)² = 16 → x+3 = ±4 → x=1 或 x=-7；抛物线交点核验 | 语义公式项匹配、Write、函数绘图 | output/lessons/01-quadratic.mp4，19.3 秒 |
| matrix | 剪切保持面积，竖直拉伸使面积增至 3/2；对应 det A=1、det B=3/2 | NumberPlane、基向量、整组 ApplyAffine | output/lessons/02-linear-algebra.mp4，18 秒 |
| pythagoras | 四个全等直角三角形在同一大正方形内重排；c² 的空隙变为 a²、b² 两个空隙 | Polygon、精确平移、公式消项 | output/lessons/03-pythagoras.mp4，21.3 秒 |
| riemann | 用 4、16、32 个左端点矩形近似 y=x² 在 [0,2] 下的面积，并收敛到定积分 8/3 | NumberPlane、矩形连续细分、语义公式项转场 | output/lessons/04-riemann-sum.mp4，15.95 秒 |

四段合集：output/lessons/00-all-lessons.mp4，74.55 秒。视频为 1280×720、60 fps，无音轨。教学场景源码位于 src/cmd/lessons。

勾股定理的图中取 a=2、b=3 以便观看；构造 Pythagoras::new(a,b) 接受一般正边长。验证包含不同长宽比的面积计算，以及重排前后在同一方形中的覆盖与不重叠检查。画面中的相同颜色不意味着所有公式项语义相同，重复项用独立 key 区分。

## 运行与导出

~~~sh
# 已提交公式路径资产，仅运行 MoonBit 不需要 npm 或 TeX。
moon check --target all --deny-warn
mkdir -p output
moon run src/cmd/lessons --target native --release formula > output/formula.jsonl

# 导出工具依赖：Node.js 20+、sharp，以及带 libx264 的 FFmpeg。
npm ci
make lesson-stills   # 只输出关键帧和接触表，无需 FFmpeg
make lesson-videos   # 输出四个视频及合集
~~~

如果 FFmpeg 不在 PATH，设置 MOONMANIM_FFMPEG=/absolute/path/to/ffmpeg。Node 只执行构建时公式排版、帧光栅化、字幕叠加和编码；逐帧对象状态和公式项运动由 MoonBit 求值。标题、中文阶段说明和计时仍为导出器叠加，公式和图形则是引擎对象。

## 编译新的公式片段

编辑 assets/tex/fragments.json，添加需要的 TeX 片段，然后执行：

~~~sh
make tex-assets
~~~

生成器使用固定版本 MathJax 的 TeX 数学字体和 SVG 排版，将路径、变换、矩形和二次曲线展开为三次贝塞尔。输出 assets/tex/teaching.json，以及嵌入同一 JSON 的 src/teaching/assets.generated.mbt，保证四种 MoonBit 目标都不需要运行时文件系统。只修改场景时无需重编译资产。

也可单独生成任意资产文件：

~~~sh
node scripts/compile-tex.cjs fragments.json my-formulas.json
~~~

TexAsset::parse 接受版本 1 的 JSON：glyphs 中每个片段有唯一 tex、以 em 为单位的 advance、contours；每条 contour 有 closed 和 segments。每个三次曲线是八个数字 [x0,y0,x1,y1,x2,y2,x3,y3]。Y 轴向上，基线为 y=0；闭合、连续性和有限数值由 MoonBit 校验。该格式是受控的路径资产格式，不是通用 SVG 导入器。

MathJax 的许可与资产来源见 assets/tex/NOTICE.md。

## 编写可推导的公式

~~~moonbit
let asset = @text.TexAsset::parse(@teaching.tex_assets())
let blue = @mobject.Color::blue()
let first = @text.MathTex::new([
  { key: "x", glyph: asset.glyph("x"), color: blue },
  { key: "eq", glyph: asset.glyph("="), color: blue },
  { key: "rhs", glyph: asset.glyph("1"), color: blue },
])
let formula = @text.Formula::new(scene, first)
formula.write(duration=1.5)
let x_id = formula.part("x")
// 为下一步构造 MathTex，保留相同项的 key，然后调用：
formula.transition(next, origin=@math.Vec3::new(-2.0, 1.0), duration=1.2)
// 相同 key 且相同字形的 x 仍使用 x_id。
~~~

MathTex 显式按共同基线排列片段，font_size 为 em 对应的场景单位，gap 为片段之间的场景距离。分式、根号、矩阵等片段内部的数学排版由 MathJax 完成。跨片段的 TeX 数学间距和大型定界符不会自动重排，应把需要共同排版的部分放在一个片段中。

Formula.transition 的规则：

- key 与字形几何相同：保留 ObjectId，插值位置、尺寸和颜色。
- 新增片段淡入，删除片段淡出；相同 key 更换字形时替换对象。
- 不同拓扑的字形不强行做控制点变形，也不自动识别代数等价关系。
- origin 位于 Formula.root 的局部坐标。移动 root 可以整体移动公式。

Write 对叶子矢量路径先描轮廓，再显现填充，完成时恢复精确原状态。路径描绘采用 1e-4 世界单位的总弧长误差预算，避免复合公式耗尽索引上限；默认相机下约为 0.009 像素。它按路径顺序描绘，不模拟真实书写的笔顺。Formula.write 使用 play_staggered，让各片段错开启动。

## 坐标与矩阵动画

NumberPlane 提供 point、coordinates、grid、axes、plot。plot 是均匀采样的折线，不承诺自适应误差；显式 breaks、None、非有限值和视窗外样本会断开子路径。对于间断函数应提供 breaks，当前不会自动推断所有渐近线，也不进行边界交点裁剪。

apply_affine 在父坐标系中插值 I → M，并左乘初始变换，可作用于拥有子节点的组。奇异矩阵是允许的，便于后续讲解降维投影。矩阵插值可改变面积和长度，刚体旋转继续使用 rotate。

play_staggered 的 duration 包含全部延迟，lag_ratio=0 同时开始，1 表示依次播放。每个子动画时长为 duration / (1 + lag_ratio × (n−1))。仍拒绝相同节点或祖先后代之间的动画冲突，全部动画在输出前预备。

## 边界与后续

这是一套可扩展的二维数学教学基础，尚未提供完整 Manim/ManimGL 兼容、运行时 TeX 编译、通用 SVG 导入、自然语言排版、移动相机、三维、GPU 或原生像素/媒体后端。ValueTracker / Updater 已支持参数驱动与动态几何依赖，见 [动态几何开发说明](dynamics.zh-CN.md)。后续将扩展相机控制、公式字形匹配与正式渲染管线。
