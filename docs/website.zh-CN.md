# 项目展示网站

网站源码位于 `site/`，目标地址为 https://noahzhao.github.io/moonbit-Manim/。

网站包含六个直接调用 MoonBit 核心的交互项目，以及八段引擎生成的视频，其中包括一段无声 CNN 卷积演示。项目卡片可直接进入相应实验，也支持通过 `?scene=tangent#playground` 一类链接分享指定项目。支持播放、暂停、进度拖动、参数预设、曲线控制点拖动、SVG 导出和手机布局。`features.html` 提供独立的能力矩阵页，按几何、动画、数学表达、运行时与教学工作流展示已验证、实验中和计划中的能力。系统启用“减少动态效果”时，首页动画默认暂停。

| 项目 | 可探索的内容 | 地址参数 |
| --- | --- | --- |
| 线性变换 | 剪切、缩放、旋转、镜像与行列式 | `scene=matrix` |
| 贝塞尔曲线 | 拖动控制点与等弧长描绘 | `scene=bezier` |
| 勾股定理 | 三角形重排与面积不变量 | `scene=pythagoras` |
| 割线与切线 | 两点间距趋零、差商与导数 | `scene=tangent` |
| 利萨如曲线 | 整数频率比、相位差与周期轨迹 | `scene=lissajous` |
| 几何变形 | 正方形与圆的轮廓插值和旋转 | `scene=morph` |

主页按项目目标、计算流程、交互实验、成果案例和复现文档组织，采用科研项目的图注与编号方式。项目指标（编译目标、核心测试数量等）与根目录 README 对应，核心能力更新后应同步调整。社交分享图的源文件为 `site/assets/social.svg`，运行 `site:media` 时生成对应 PNG。

## 本地预览

已提交浏览器运行时、视频和封面，因此预览只需要 Node.js，无需安装 npm 依赖或 MoonBit：

```sh
npm run site:serve
```

打开 http://127.0.0.1:4173/moonbit-Manim/。`PORT=8080 npm run site:serve` 可以修改端口。

## GitHub Pages 首次部署

1. 将网站和 `.github/workflows/pages.yml` 提交、推送到 `main`。
2. 在仓库 **Settings → Pages → Build and deployment → Source** 中选择 **GitHub Actions**。
3. 在 **Actions → Deploy project website** 中查看部署。如果首次推送发生在设置 Source 之前，可点击 **Run workflow → Run workflow** 再运行一次。
4. 等待部署成功，访问 https://noahzhao.github.io/moonbit-Manim/。

之后，`main` 上任何 `site/` 或部署工作流的变更都会触发部署。只上传 `site/`，不上传 `manim-main/`、`node_modules/`、`_build/` 或整个仓库。请使用支持 GitHub Pages 的仓库可见性与账户方案；公开仓库可直接使用。

如果此前使用的 fine-grained 访问令牌仅有 `Contents: Read and write` 权限，上传 `.github/workflows/pages.yml` 还需要该仓库的 `Workflows: Read and write` 权限。GitHub 若提示令牌无权创建或更新工作流，请先更新令牌权限，再重试推送。

## 更新网站

修改 `site/index.html`、`site/styles.css` 或 `site/app.js` 后，刷新本地页面即可。所有资源采用相对路径，以兼容 GitHub Pages 的仓库子路径。页面中的仓库链接和社交预览地址使用当前项目地址；迁移或更名时需要同步修改。

### 更新 MoonBit 交互逻辑

普通实验编辑 `src/cmd/web/main.mbt`；割线课程编辑 `src/lessons/tangent/tangent.mbt`。然后运行：

```sh
moon fmt
npm run site:build
npm run site:check
```

`site:build` 使用本机 MoonBit 工具链编译 JavaScript，并更新 `site/assets/engine.js`、六个项目的 SVG 封面及许可证文件。`site:check` 直接调用编译后的引擎，验证矩阵的面积系数、曲线弧长、勾股面积关系、割线极限、振动轨迹、变形端点，以及项目入口、视频数量和资源路径。

**编译后的 `site/assets/engine.js` 需要一并提交。** GitHub Pages 工作流直接发布静态文件，不安装 MoonBit，也不会自动编译 `src/` 中的变更。已验证的工具链版本见根目录 README。

浏览器只提供输入控件和播放时间，几何、路径弧长、三角形构造、矩阵变换和 SVG 投影都复用 MoonBit 核心。割线课程的视频和网页复用同一个场景、参数描述与章节时间线；其余五个实验仍保留各自的入口。

切线课程定义于 `src/lessons/tangent/tangent.mbt`，通过 `src/lesson` 提供的绝对时间采样驱动 ValueTracker 和 Updater。网页缓存几何与 TeX 资产，随机跳转时重新设置完整的参数状态，无需模拟前面的帧。“跟随讲解”按 33.9 秒章节时间线播放；“自由探索”保留切换瞬间的参数并开放编辑。返回讲解会恢复原来的课程时刻。视频卡片的接管按钮将视频 `currentTime` 映射到同一条课程时间线。控件范围与章节按钮直接读取 MoonBit 元数据，JavaScript 不复制课程轨迹。详见 [课程指南](lessons.zh-CN.md)。利萨如项目在 `src/cmd/web/main.mbt` 中以每周期 720 条线段采样参数曲线，进度对应振动相位比例，不代表等弧长运动；频率限制为 1–6 的整数。

### 更新视频和封面

确保已安装项目依赖、MoonBit 和 FFmpeg，先生成视频：

```sh
npm ci
npm run lessons
npm run demos
npm run dynamics
npm run site:media
npm run site:check
```

`site:media` 将选中的八段视频（包含割线到切线教学案例和 `cnn/01-cnn.mp4` 卷积演示）复制到 `site/assets/demos/`，提取 WebP 封面并生成社交分享图。CNN 视频通过 `npm run cnn` 生成，使用 5×5 输入网格、3×3 卷积核和 3×3 特征图展示感受野滑动；它不包含音频。构建脚本支持通过 `MOONMANIM_FFMPEG` 指定 FFmpeg。网页只在用户播放时加载视频，且同一时间只播放一个视频。

源视频仍保存在被 Git 忽略的 `output/` 中；网站使用的精选副本需要提交。站点随附 MIT 许可证，以及 MathJax 公式资产的 Apache-2.0 许可证和来源说明。
