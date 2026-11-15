/* MoonManim website · MIT License. Geometry is provided by the compiled MoonBit engine. */
(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];
  const stage = $('#lab-stage');
  const progress = $('#progress');
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const sourceBase = 'https://github.com/NoahZhao/moonbit-Manim/blob/main/';
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
  };
  const state = { scene: 'matrix', parameters: [...scenes.matrix.defaults], progress: 1, playing: false };
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
    if (playing) animationTime = state.scene === 'bezier'
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
      const value = state.parameters[index];
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
    $('#control-title').textContent = scene.title;
    $('#control-description').textContent = scene.description;
    $('#scene-caption').textContent = scene.caption;
    $('#stage-legend').innerHTML = scene.legend;
    $('#lab-panel').setAttribute('aria-labelledby', `tab-${name}`);
    $('#scene-source').href = sourceBase + 'src/cmd/web/main.mbt';
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
        state.parameters[index] = Number(event.target.value);
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
      lastFrame = frame(state.scene, state.progress, state.parameters);
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
      } else {
        $('#math-readout').innerHTML = `<div class="equation">a<sup>2</sup> + b<sup>2</sup> = c<sup>2</sup></div><div class="metric"><small>${format(values.a2)} + ${format(values.b2)}</small><strong>${format(values.c2)}</strong></div>`;
        $('#insight').textContent = state.progress < 0.05 ? '当前留白是 c²。点击播放，或拖动时间线，观察三角形如何重新排列。' : state.progress > 0.95 ? '现在留白变成了 a² 与 b²。减去同样的四个三角形，剩下的面积始终相等。' : '三角形只做平移，大小始终不变。两个端点的留白面积相等，重排过程便于观察位置变化。';
      }
      $('#engine-error').hidden = true;
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
  $('#play-toggle').addEventListener('click', () => setPlaying(!state.playing));
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
          state.progress = state.scene === 'bezier'
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
