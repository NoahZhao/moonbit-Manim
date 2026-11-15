/* MoonManim website · MIT License. Geometry is provided by the compiled MoonBit engine. */
(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];
  const stage = $('#lab-stage');
  const progress = $('#progress');
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const sourceBase = 'https://github.com/NoahZhao/moonbit-Manim/blob/main/';
  const lesson = window.MoonManim?.describeLesson ? JSON.parse(window.MoonManim.describeLesson()) : null;
  const scenes = {
    matrix: {
      caption: 'LINEAR TRANSFORMATION', title: '线性变换与面积尺度',
      description: '矩阵的两列决定两根基向量的新位置。拖动参数，观察单位正方形和整个网格如何一起改变。',
      defaults: [0.8, 1.2, 0], progress: 1,
      parameters: [
        { label: '水平剪切', min: -1.5, max: 1.5, step: 0.05, unit: '' },
        { label: '纵向缩放', min: -1.5, max: 2, step: 0.05, unit: '×' },
        { label: '整体旋转', min: -90, max: 90, step: 1, unit: '°' },
      ],
      presets: [['剪切', [1, 1, 0]], ['拉伸', [0, 1.5, 0]], ['旋转', [0, 1, 35]], ['降维', [0.8, 0, 0]], ['镜像', [0, -1, 0]]],
      legend: '<span><i class="legend-swatch"></i>基向量 e₁</span><span><i class="legend-swatch coral"></i>基向量 e₂</span><span><i class="legend-swatch blue"></i>单位正方形</span>',
    },
    bezier: {
      caption: 'ARC-LENGTH PARAMETERIZATION', title: '贝塞尔曲线与弧长参数化',
      description: '调节 P₁、P₂ 的高度或直接拖动控制点。亮点按弧长比例定位，以恒定路径速度呈现曲线的描绘过程。',
      defaults: [2.6, -2.6, 0], progress: 0.65,
      parameters: [
        { label: '控制点 P₁ · 高度', min: -3, max: 3, step: 0.05, unit: '' },
        { label: '控制点 P₂ · 高度', min: -3, max: 3, step: 0.05, unit: '' },
      ],
      presets: [['S 形', [2.6, -2.6, 0]], ['拱形', [2.8, 2.8, 0]], ['波谷', [-2.8, -2.8, 0]], ['直线', [0, 0, 0]]],
      legend: '<span><i class="legend-swatch"></i>已描绘路径</span><span><i class="legend-swatch blue"></i>拖动控制点，改变曲线</span>',
    },
    pythagoras: {
      caption: 'GEOMETRIC AREA INVARIANCE', title: '几何重排与面积不变量',
      description: '在同一正方形中平移四个全等直角三角形，对比两个端点的剩余面积。改变直角边，验证一般情形下的面积关系。',
      defaults: [2, 3, 0], progress: 0,
      parameters: [
        { label: '直角边 a', min: 0.5, max: 4, step: 0.1, unit: '' },
        { label: '直角边 b', min: 0.5, max: 4, step: 0.1, unit: '' },
      ],
      presets: [['2 : 3', [2, 3, 0]], ['等腰三角形', [2, 2, 0]], ['3 : 4', [3, 4, 0]]],
      legend: '<span><i class="legend-swatch"></i>面积 a²</span><span><i class="legend-swatch blue"></i>面积 b² / c²</span><span>四个三角形 · 面积不变</span>',
    },
    tangent: {
      caption: 'FROM SECANT TO TANGENT', title: '割线极限与瞬时变化率',
      description: '跟随讲解理解割线极限。随时切换自由探索，在当前画面上调整 x 和 h，再返回讲解继续观看。',
      defaults: [...(lesson?.parameters.map(p => p.initial) || []), 0], progress: 0,
      source: 'src/lessons/tangent/tangent.mbt',
      parameters: lesson?.parameters || [],
      presets: [['下降', [-2, 1.5, 0]], ['最低点', [0, 2, 0]], ['上升', [2, 1.5, 0]], ['直接看切线', [-1.5, 0, 0]]],
      legend: '<span><i class="legend-swatch pink"></i>观察点 P</span><span><i class="legend-swatch"></i>靠近的点 Q</span><span><i class="legend-swatch coral"></i>割线 → 切线</span>',
    },
    lissajous: {
      caption: 'LISSAJOUS / COUPLED OSCILLATIONS', title: '两个振动，一条利萨如曲线',
      description: '将水平与竖直的简谐振动合成一条轨迹。改变整数频率比和相位差，探索圆、八字与多瓣图案之间的联系。',
      defaults: [3, 2, 90], progress: 0.8, loop: true,
      parameters: [
        { label: '水平频率 a', min: 1, max: 6, step: 1, unit: '' },
        { label: '竖直频率 b', min: 1, max: 6, step: 1, unit: '' },
        { label: '相位差 δ', min: -180, max: 180, step: 5, unit: '°' },
      ],
      presets: [['椭圆', [1, 1, 90]], ['八字', [1, 2, 0]], ['3 : 2', [3, 2, 90]], ['5 : 4', [5, 4, 90]]],
      legend: '<span><i class="legend-swatch"></i>合成轨迹</span><span><i class="legend-swatch coral"></i>当前振动位置</span><span><i class="legend-swatch blue"></i>完整周期</span>',
    },
    morph: {
      caption: 'CONTINUOUS VECTOR MORPHING', title: '从正方形到圆的连续变形',
      description: '先对齐两个轮廓的贝塞尔分段，再插值控制点。拖动进度改变形状，调节角度观察两层轮廓的反向旋转。',
      defaults: [0, 0, 0.3], progress: 0.35,
      parameters: [{ label: '旋转角度', min: -180, max: 180, step: 1, unit: '°', index: 2, radians: true }],
      presets: [['对齐', [0, 0, 0]], ['旋转 45°', [0, 0, Math.PI / 4]], ['旋转 90°', [0, 0, Math.PI / 2]]],
      legend: '<span><i class="legend-swatch blue"></i>正方形 → 圆</span><span><i class="legend-swatch"></i>圆 → 正方形</span>',
    },
  };
  const state = { scene: 'matrix', parameters: [...scenes.matrix.defaults], progress: 1, playing: false, lessonMode: 'follow' };
  let lastFrame = null;
  let heroPaused = reduceMotion.matches;
  let heroTime = 0;
  let labVisible = true;
  let heroVisible = true;
  let animationTime = 0;
  let previousTime = 0;
  let previousDraw = 0;
  let engineReady = false;
  let toastTimer;
  let draggedControl = null;

  function toast(message) {
    $('#toast').textContent = message;
    $('#toast').hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 2600);
  }

  const format = (value, digits = 2) => Math.abs(value) < 0.0005 ? (0).toFixed(digits) : value.toFixed(digits);

  function setPlaying(playing) {
    state.playing = playing;
    $('#play-toggle').textContent = playing ? 'Ⅱ' : '▶';
    $('#play-toggle').setAttribute('aria-pressed', String(playing));
    $('#play-toggle').setAttribute('aria-label', playing ? '暂停实验动画' : '播放实验动画');
    if (playing && state.scene === 'tangent') {
      if (state.progress >= 1) state.progress = 0;
      animationTime = state.progress * lesson.duration;
      return;
    }
    if (playing) animationTime = state.scene === 'bezier' || scenes[state.scene].loop
      ? state.progress * 6
      : Math.acos(1 - 2 * state.progress) / Math.PI * 4;
  }

  function syncHeroButton() {
    $('#hero-toggle').textContent = heroPaused ? '▶' : 'Ⅱ';
    $('#hero-toggle').setAttribute('aria-pressed', String(heroPaused));
    $('#hero-toggle').setAttribute('aria-label', heroPaused ? '播放首页动画' : '暂停首页动画');
  }

  function syncParameters() {
    scenes[state.scene].parameters.forEach((parameter, index) => {
      let value = state.parameters[parameter.index ?? index];
      if (parameter.radians) value *= 180 / Math.PI;
      $(`#parameter-${index}`).value = String(value);
      $(`#value-${index}`).textContent = format(value, parameter.unit === '°' ? 0 : 2) + parameter.unit;
    });
    $$('#presets button').forEach((button, index) => {
      const selected = scenes[state.scene].presets[index][1].every((value, i) => Math.abs(value - state.parameters[i]) < 0.001);
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
  }

  function selectScene(name) {
    const scene = scenes[name];
    if (!scene) return;
    setPlaying(false);
    state.scene = name;
    state.parameters = [...scene.defaults];
    state.progress = scene.progress;
    state.lessonMode = 'follow';
    $('.lab-canvas').classList.toggle('is-lesson', name === 'tangent');
    $('#lesson-tools').hidden = name !== 'tangent';
    $('#lesson-narration').hidden = name !== 'tangent';
    $('#lesson-chapters').replaceChildren();
    if (name === 'tangent' && lesson) lesson.chapters.forEach((chapter, index) => {
      const button = document.createElement('button');
      button.textContent = chapter.title;
      button.addEventListener('click', () => {
        setPlaying(false);
        state.progress = chapter.start / lesson.duration;
        setLessonMode('follow');
      });
      button.dataset.chapter = String(index);
      $('#lesson-chapters').append(button);
    });
    progress.disabled = false;
    $('#play-toggle').disabled = false;
    $('#control-title').textContent = scene.title;
    $('#control-description').textContent = scene.description;
    $('#scene-caption').textContent = scene.caption;
    $('#stage-legend').innerHTML = scene.legend;
    $('#lab-panel').setAttribute('aria-labelledby', `tab-${name}`);
    $('#scene-source').href = sourceBase + (scene.source || 'src/cmd/web/main.mbt');
    const url = new URL(window.location.href);
    url.searchParams.set('scene', name);
    window.history.replaceState(null, '', url);
    $$('.lab-tab').forEach((tab) => {
      const selected = tab.dataset.scene === name;
      tab.classList.toggle('active', selected);
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    $('#parameter-controls').replaceChildren();
    scene.parameters.forEach((parameter, index) => {
      const wrapper = document.createElement('div');
      wrapper.className = 'parameter';
      wrapper.innerHTML = `<label for="parameter-${index}">${parameter.label}<output id="value-${index}" for="parameter-${index}"></output></label><input id="parameter-${index}" type="range" min="${parameter.min}" max="${parameter.max}" step="${parameter.step}" value="${state.parameters[index]}"><div class="parameter-scale"><span>${parameter.min}${parameter.unit}</span><span>${parameter.max}${parameter.unit}</span></div>`;
      wrapper.querySelector('input').addEventListener('input', (event) => {
        state.parameters[parameter.index ?? index] = Number(event.target.value) * (parameter.radians ? Math.PI / 180 : 1);
        syncParameters();
        drawLab();
      });
      $('#parameter-controls').append(wrapper);
    });
    $('#presets').replaceChildren();
    scene.presets.forEach(([label, values]) => {
      const button = document.createElement('button');
      button.className = 'preset';
      button.textContent = label;
      button.addEventListener('click', () => {
        if (state.scene === 'tangent') { state.lessonMode = 'explore'; setPlaying(false); }
        state.parameters = [...values];
        if (state.scene === 'matrix') { setPlaying(false); state.progress = 1; }
        syncParameters();
        drawLab();
      });
      $('#presets').append(button);
    });
    syncParameters();
    drawLab();
  }

  function setLessonMode(mode) {
    setPlaying(false);
    state.lessonMode = mode;
    drawLab();
  }

  $('#mode-follow').addEventListener('click', () => setLessonMode('follow'));
  $('#mode-explore').addEventListener('click', () => setLessonMode('explore'));

  function frame(name, t, parameters) {
    const result = JSON.parse(window.MoonManim.render(name, t, ...parameters));
    if (result.error || !result.svg) throw new Error(result.error || 'Missing SVG frame');
    return result;
  }

  function controlPoints() {
    const svg = stage.querySelector('svg');
    if (!svg) return;
    const ns = 'http://www.w3.org/2000/svg';
    [0, 1].forEach((index) => {
      const x = index === 0 ? 292.5 : 667.5;
      const y = 300 - 75 * state.parameters[index];
      const group = document.createElementNS(ns, 'g');
      group.classList.add('curve-drag');
      group.dataset.control = String(index);
      group.innerHTML = `<circle cx="${x}" cy="${y}" r="23" fill="transparent"/><circle class="handle-visible" cx="${x}" cy="${y}" r="6"/><text x="${x + 13}" y="${y - 12}">P${index + 1}</text>`;
      svg.append(group);
    });
  }

  function drawLab() {
    progress.value = String(state.progress * 100);
    $('#progress-value').textContent = `${Math.round(state.progress * 100)}%`;
    if (!engineReady) return;
    try {
      if (state.scene === 'tangent' && state.lessonMode === 'follow') {
        lastFrame = JSON.parse(window.MoonManim.renderLesson(state.progress));
        if (lastFrame.error || !lastFrame.svg) throw new Error(lastFrame.error || 'Missing lesson frame');
        state.parameters = [lastFrame.values.x, lastFrame.values.gap, 0];
      } else {
        lastFrame = frame(state.scene, state.scene === 'tangent' ? 0 : state.progress, state.parameters);
      }
      if (state.scene === 'tangent') {
        const follow = state.lessonMode === 'follow';
        $('#mode-follow').setAttribute('aria-pressed', String(follow));
        $('#mode-explore').setAttribute('aria-pressed', String(!follow));
        $$('#parameter-controls input').forEach(input => { input.disabled = follow; });
        progress.disabled = !follow;
        $('#play-toggle').disabled = !follow;
        $('#lesson-title').textContent = follow ? lastFrame.title : '自由探索 · 已接管当前画面';
        $('#lesson-caption').textContent = follow ? lastFrame.phase : '拖动 x 与 h，验证你的猜想。返回讲解后，从刚才暂停的位置继续。';
        $('#progress-value').textContent = `${format(state.progress * lesson.duration, 1)} / ${lesson.duration}s`;
        $$('#lesson-chapters button').forEach((button, index) => {
          if (follow && index === lastFrame.chapter) button.setAttribute('aria-current', 'step');
          else button.removeAttribute('aria-current');
        });
        $('#presets').hidden = follow;
        syncParameters();
      } else { $('#presets').hidden = false; }
      stage.innerHTML = lastFrame.svg;
      const svg = stage.querySelector('svg');
      svg.setAttribute('role', 'img');
      svg.setAttribute('aria-label', scenes[state.scene].title);
      const values = lastFrame.values;
      if (state.scene === 'matrix') {
        $('#math-readout').innerHTML = `<div class="matrix-wrap"><div class="matrix-display"><span>${format(values.a)}</span><span>${format(values.c)}</span><span>${format(values.b)}</span><span>${format(values.d)}</span></div></div><div class="metric"><small>det(A)</small><strong>${format(values.determinant)}</strong></div>`;
        $('#insight').textContent = Math.abs(values.determinant) < 0.001 ? '面积变成了 0：整个平面被压缩到一条线上，空间失去一个维度。' : values.determinant < 0 ? `面积变为原来的 ${format(Math.abs(values.determinant))} 倍；负号表示图形的朝向发生翻转。` : `面积变为原来的 ${format(values.determinant)} 倍。行列式告诉你空间如何伸缩。`;
      } else if (state.scene === 'bezier') {
        controlPoints();
        $('#math-readout').innerHTML = `<div class="equation">B(t) <span style="color:#a7afbd">∿</span></div><div class="metric"><small>已绘弧长 / 总弧长</small><strong>${format(values.drawn)} <span style="font-size:11px;color:#939dad">/ ${format(values.length)}</span></strong></div>`;
        $('#insight').textContent = '进度表示弧长比例，而非贝塞尔参数 t。匀速描绘的计算，由引擎的 PathMeasure 完成。';
      } else if (state.scene === 'pythagoras') {
        $('#math-readout').innerHTML = `<div class="equation">a<sup>2</sup> + b<sup>2</sup> = c<sup>2</sup></div><div class="metric"><small>${format(values.a2)} + ${format(values.b2)}</small><strong>${format(values.c2)}</strong></div>`;
        $('#insight').textContent = state.progress < 0.05 ? '当前留白是 c²。点击播放，或拖动时间线，观察三角形如何重新排列。' : state.progress > 0.95 ? '现在留白变成了 a² 与 b²。减去同样的四个三角形，剩下的面积始终相等。' : '三角形只做平移，大小始终不变。两个端点的留白面积相等，重排过程便于观察位置变化。';
      } else if (state.scene === 'tangent') {
        $('#math-readout').innerHTML = `<div class="equation">f′(x) = x/2<div class="readout-detail">h = ${format(values.gap, 3)}</div></div><div class="metric"><small>割线斜率 / 导数</small><strong>${format(values.slope)} <span class="readout-secondary">/ ${format(values.derivative)}</span></strong></div>`;
        $('#insight').textContent = values.gap < 0.001 ? `两点重合时取解析极限，切线斜率是 ${format(values.derivative)}。移动 x，比较曲线不同位置的变化率。` : `割线斜率与导数相差 ${format(values.slope - values.derivative, 3)}。当 h 趋于 0，这个差值也趋于 0。`;
      } else if (state.scene === 'lissajous') {
        $('#math-readout').innerHTML = `<div class="equation equation-small">x = 3.6 sin(at + δ)<br>y = 2.6 sin(bt)</div><div class="metric"><small>频率比 a : b</small><strong>${values.frequency_x} : ${values.frequency_y}</strong></div>`;
        $('#insight').textContent = `当前位置 (${format(values.x)}, ${format(values.y)})。整数频率让两个振动在同一周期后回到起点；相位差改变图案的对称性。`;
      } else if (state.scene === 'morph') {
        $('#math-readout').innerHTML = `<div class="equation">P(α) = (1−α)P₀ + αP₁</div><div class="metric"><small>轮廓插值 α</small><strong>${format(values.alpha)}</strong></div>`;
        $('#insight').textContent = state.progress < 0.001 ? 'α = 0：外层精确保留原始正方形，内层保留原始圆。' : state.progress > 0.999 ? 'α = 1：两层轮廓交换形状，保留各自的精确端点。' : '插值发生在三次贝塞尔控制点之间。形状连续变化，但过程不保证面积保持。';
      }
      $('#engine-error').hidden = true;
      $('#engine-status').textContent = 'ENGINE READY / MoonBit → JavaScript → SVG';
    } catch (error) {
      setPlaying(false);
      $('#engine-error').hidden = false;
      $('#engine-status').textContent = '场景渲染失败，请重置后重试';
      console.error('MoonManim rendering failed:', error);
    }
  }

  $$('.lab-tab').forEach((tab, index, tabs) => {
    tab.addEventListener('click', () => selectScene(tab.dataset.scene));
    tab.addEventListener('keydown', (event) => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) { event.preventDefault(); tabs[next].focus(); selectScene(tabs[next].dataset.scene); }
    });
  });
  $$('[data-open-scene]').forEach((link) => link.addEventListener('click', (event) => {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    selectScene(link.dataset.openScene);
    const url = new URL(window.location.href);
    url.hash = 'playground';
    window.history.replaceState(null, '', url);
    $('#playground').scrollIntoView({ behavior: reduceMotion.matches ? 'instant' : 'smooth' });
    $(`#tab-${link.dataset.openScene}`).focus({ preventScroll: true });
  }));
  $('#play-toggle').addEventListener('click', () => setPlaying(!state.playing));
  $('#takeover-video').addEventListener('click', () => {
    const video = $('#tangent-video');
    video.pause();
    selectScene('tangent');
    state.progress = Math.max(0, Math.min(1, video.currentTime / lesson.duration));
    drawLab();
    setLessonMode('explore');
    $('#playground').scrollIntoView({ behavior: reduceMotion.matches ? 'instant' : 'smooth' });
    $('#mode-explore').focus({ preventScroll: true });
  });
  progress.addEventListener('input', () => { setPlaying(false); state.progress = Number(progress.value) / 100; drawLab(); });
  $('#reset').addEventListener('click', () => selectScene(state.scene));
  $('#hero-toggle').addEventListener('click', () => { heroPaused = !heroPaused; syncHeroButton(); });
  reduceMotion.addEventListener('change', (event) => { if (event.matches) { heroPaused = true; setPlaying(false); syncHeroButton(); } });

  stage.addEventListener('pointerdown', (event) => {
    if (state.scene !== 'bezier') return;
    const handle = event.target.closest('[data-control]');
    if (!handle) return;
    event.preventDefault();
    draggedControl = Number(handle.dataset.control);
    setPlaying(false);
    stage.setPointerCapture(event.pointerId);
  });
  stage.addEventListener('pointermove', (event) => {
    if (draggedControl === null) return;
    const svg = stage.querySelector('svg');
    const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(svg.getScreenCTM().inverse());
    state.parameters[draggedControl] = Math.round(Math.max(-3, Math.min(3, (300 - point.y) / 75)) * 20) / 20;
    syncParameters();
    drawLab();
  });
  const endDrag = () => { draggedControl = null; };
  stage.addEventListener('pointerup', endDrag);
  stage.addEventListener('pointercancel', endDrag);
  stage.addEventListener('lostpointercapture', endDrag);

  $('#export-svg').addEventListener('click', () => {
    if (!lastFrame) return;
    const blob = new Blob(['<?xml version="1.0" encoding="UTF-8"?>\n<!-- Created with MoonManim · MIT License -->\n', lastFrame.svg], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `moonmanim-${state.scene}.svg`;
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast('已导出当前 SVG 图像');
  });

  $$('.filter').forEach((filter) => filter.addEventListener('click', () => {
    $$('.filter').forEach((button) => {
      const active = button === filter;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', String(active));
    });
    $$('.work-card').forEach((card) => {
      card.hidden = filter.dataset.filter !== 'all' && card.dataset.category !== filter.dataset.filter;
      if (card.hidden) card.querySelector('video').pause();
    });
  }));
  $$('video').forEach((video) => {
    video.addEventListener('play', () => $$('video').forEach((other) => { if (other !== video) other.pause(); }));
    video.addEventListener('error', () => toast('视频加载失败，请检查网络后重试'));
  });
  $('#copy-code').addEventListener('click', async () => {
    const code = $('#sample-code');
    try {
      await navigator.clipboard.writeText(code.textContent);
      $('#copy-code').textContent = '已复制 ✓';
      toast('示例代码已复制');
      setTimeout(() => { $('#copy-code').textContent = '复制代码'; }, 2200);
    } catch {
      const range = document.createRange();
      range.selectNodeContents(code);
      window.getSelection().removeAllRanges();
      window.getSelection().addRange(range);
      toast('已选中代码，请使用系统复制快捷键');
    }
  });

  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => entries.forEach((entry) => {
      if (entry.target.id === 'hero-stage') heroVisible = entry.isIntersecting;
      else labVisible = entry.isIntersecting;
    }), { rootMargin: '60px' });
    observer.observe($('#hero-stage'));
    observer.observe(stage);
  }
  engineReady = typeof window.MoonManim?.render === 'function';
  const requestedScene = new URLSearchParams(window.location.search).get('scene');
  selectScene(Object.hasOwn(scenes, requestedScene) ? requestedScene : 'matrix');
  syncHeroButton();
  if (!engineReady) {
    $('#engine-status').textContent = '引擎加载失败，请刷新页面';
    $('#engine-error').hidden = false;
    $('#play-toggle').disabled = true;
    $('#export-svg').disabled = true;
    $('#hero-toggle').disabled = true;
    return;
  }
  $('#engine-status').textContent = 'ENGINE READY / MoonBit → JavaScript → SVG';
  function drawHero(alpha, angle) {
    $('#hero-stage').innerHTML = frame('morph', alpha, [0, 0, angle]).svg;
    $('#hero-progress').textContent = alpha.toFixed(3);
  }
  drawHero(0.35, 0.3);
  function animate(time) {
    const delta = previousTime ? Math.min((time - previousTime) / 1000, 0.1) : 0;
    previousTime = time;
    if (!document.hidden) {
      if (!heroPaused && heroVisible) heroTime += delta;
      if (state.playing && labVisible) animationTime += delta;
      if (time - previousDraw >= 1000 / 30) {
        previousDraw = time;
        if (!heroPaused && heroVisible) drawHero((1 - Math.cos(heroTime * 0.65)) / 2, heroTime * 0.15);
        if (state.playing && labVisible) {
          if (state.scene === 'tangent') {
            state.progress = Math.min(1, animationTime / lesson.duration);
            if (state.progress >= 1) setPlaying(false);
          } else state.progress = state.scene === 'bezier' || scenes[state.scene].loop
            ? (animationTime / 6) % 1
            : (1 - Math.cos(animationTime * Math.PI / 4)) / 2;
          drawLab();
        }
      }
    }
    requestAnimationFrame(animate);
  }
  requestAnimationFrame(animate);
})();
