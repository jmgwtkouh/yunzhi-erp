/* =========================================================================
 * 云智 ERP · 登录页 3D 地球背景渲染器
 * 依赖：全局 THREE（由同文件内联的 three.min.js 提供）
 * 用法：EarthBackground.mount(canvas, { onReady: fn, onFail: fn })
 * ========================================================================= */
(function (global) {
  'use strict';
  var THREE = global.THREE;
  if (!THREE) { return; }

  /* 内联贴图（生成脚本注入，全部为 data URI，离线可用） */
  var TEX = __TEXTURES__;

  var VERT = [
    'varying vec2 vUv;',
    'varying vec3 vWNormal;',
    'varying vec3 vWPos;',
    'void main(){',
    '  vUv = uv;',
    '  vWNormal = normalize(mat3(modelMatrix) * normal);',
    '  vec4 wp = modelMatrix * vec4(position, 1.0);',
    '  vWPos = wp.xyz;',
    '  gl_Position = projectionMatrix * viewMatrix * wp;',
    '}'
  ].join('\n');

  var SURFACE_FRAG = [
    'uniform sampler2D uDay;',
    'uniform sampler2D uNight;',
    'uniform sampler2D uSpec;',
    'uniform sampler2D uNormal;',
    'uniform vec3 uSun;',
    'uniform vec3 uCam;',
    'uniform float uNightOn;',
    'uniform float uBump;',
    'uniform vec3 uDark;',
    'uniform float uDarkAmt;',
    'uniform vec3 uFres;',
    'uniform float uAmbient;',
    'uniform float uHaze;',
    'uniform vec3 uHazeCol;',
    'varying vec2 vUv;',
    'varying vec3 vWNormal;',
    'varying vec3 vWPos;',
    'vec3 bumpNormal(vec3 n){',
    '  vec3 t = vec3(n.z, 0.0, -n.x);',
    '  float tl = length(t);',
    '  t = tl > 0.0001 ? t / tl : vec3(1.0, 0.0, 0.0);',
    '  vec3 b = normalize(cross(n, t));',
    '  vec3 m = texture2D(uNormal, vUv).xyz * 2.0 - 1.0;',
    '  m.xy *= uBump;',
    '  return normalize(t * m.x + b * m.y + n * m.z);',
    '}',
    'void main(){',
    '  vec3 n0 = normalize(vWNormal);',
    '  vec3 n = bumpNormal(n0);',
    '  vec3 l = normalize(uSun);',
    '  vec3 v = normalize(uCam - vWPos);',
    '  float ndl = dot(n, l);',
    '  float day = smoothstep(-0.20, 0.26, ndl);',
    '  vec3 dayTex = texture2D(uDay, vUv).rgb;',
    '  vec3 nightTex = texture2D(uNight, vUv).rgb;',
    '  vec3 lit = dayTex * (uAmbient + 0.74 * max(ndl, 0.0));',
    '  lit = mix(lit, uHazeCol, uHaze);',
    '  vec3 dark = dayTex * uDarkAmt + uDark;',
    '  vec3 night = dark + nightTex * 1.65 * uNightOn;',
    '  vec3 col = mix(night, lit, day);',
    '  float ocean = texture2D(uSpec, vUv).r;',
    '  vec3 h = normalize(l + v);',
    '  float spec = pow(max(dot(n, h), 0.0), 46.0) * ocean * day * 0.85;',
    '  col += vec3(0.62, 0.78, 1.0) * spec;',
    '  float fres = pow(1.0 - max(dot(n0, v), 0.0), 3.0);',
    '  float sunSide = smoothstep(-0.40, 0.65, dot(n0, l));',
    '  col += uFres * fres * (0.22 + 0.80 * sunSide);',
    '  gl_FragColor = vec4(col, 1.0);',
    '}'
  ].join('\n');

  var CLOUD_FRAG = [
    'uniform sampler2D uCloud;',
    'uniform float uCloudAlpha;',
    'uniform vec3 uSun;',
    'uniform vec3 uCloudDark;',
    'uniform float uCloudGain;',
    'varying vec2 vUv;',
    'varying vec3 vWNormal;',
    'varying vec3 vWPos;',
    'void main(){',
    '  vec4 ct = texture2D(uCloud, vUv);',
    '  float c = mix(ct.r, ct.a, uCloudAlpha);',
    '  float a = pow(c, 1.25) * uCloudGain;',
    '  vec3 n = normalize(vWNormal);',
    '  float d = smoothstep(-0.28, 0.42, dot(n, normalize(uSun)));',
    '  vec3 lit = vec3(1.0) * (0.52 + 0.62 * max(dot(n, normalize(uSun)), 0.0));',
    '  vec3 col = mix(uCloudDark, lit, d);',
    '  gl_FragColor = vec4(col, a * (0.22 + 0.78 * d));',
    '}'
  ].join('\n');

  var ATMOS_VERT = [
    'varying vec3 vViewN;',
    'varying vec3 vWNormal;',
    'void main(){',
    '  vViewN = normalize(normalMatrix * normal);',
    '  vWNormal = normalize(mat3(modelMatrix) * normal);',
    '  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);',
    '}'
  ].join('\n');

  var ATMOS_FRAG = [
    'uniform vec3 uSun;',
    'uniform float uStrength;',
    'uniform vec3 uColA;',
    'uniform vec3 uColB;',
    'varying vec3 vViewN;',
    'varying vec3 vWNormal;',
    'void main(){',
    '  float rim = pow(1.0 - abs(dot(normalize(vViewN), vec3(0.0,0.0,1.0))), 4.0);',
    '  float s = smoothstep(-0.45, 0.70, dot(normalize(vWNormal), normalize(uSun)));',
    '  vec3 c = mix(uColA, uColB, s);',
    '  float a = rim * (0.22 + 0.66 * s) * uStrength;',
    '  gl_FragColor = vec4(c * a * 1.35, a);',
    '}'
  ].join('\n');

  function softenClouds(texture) {
    // WKWebView 的 file:// 源下 getImageData 可能被拒绝，此时直接返回原贴图
    try { return softenCloudsImpl(texture); }
    catch (e) { console.warn('cloud smoothing skipped', e); return texture; }
  }

  function softenCloudsImpl(texture) {
    var img = texture.image, w = 512, h = 256;
    var c = document.createElement('canvas'); c.width = w; c.height = h;
    var x = c.getContext('2d');
    x.imageSmoothingEnabled = true; x.imageSmoothingQuality = 'high';
    x.drawImage(img, 0, 0, w, h);
    var id = x.getImageData(0, 0, w, h), d = id.data;
    for (var i = 0; i < d.length; i += 4) {
      var s = Math.max(0, Math.min(1, (d[i] - 58) / 165));
      s = s * s * (3 - 2 * s);
      var o = Math.round(s * 255);
      d[i] = d[i + 1] = d[i + 2] = o; d[i + 3] = 255;
    }
    x.putImageData(id, 0, 0);
    var t = new THREE.CanvasTexture(c);
    t.wrapS = THREE.RepeatWrapping;
    return t;
  }

  function loadTex(src, renderer) {
    return new Promise(function (resolve, reject) {
      new THREE.TextureLoader().load(src, function (t) {
        t.wrapS = THREE.RepeatWrapping;
        t.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
        resolve(t);
      }, undefined, reject);
    });
  }

  function starTexture() {
    var c = document.createElement('canvas'); c.width = c.height = 32;
    var x = c.getContext('2d');
    var g = x.createRadialGradient(16, 16, 0, 16, 16, 16);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(0.25, 'rgba(220,235,255,.85)');
    g.addColorStop(1, 'rgba(160,200,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, 32, 32);
    return new THREE.CanvasTexture(c);
  }

  function orbitRing(rx, rz, color, opacity) {
    var pts = [], i, a;
    for (i = 0; i <= 200; i++) {
      a = i / 200 * Math.PI * 2;
      pts.push(new THREE.Vector3(Math.cos(a) * rx, 0, Math.sin(a) * rz));
    }
    var g = new THREE.BufferGeometry().setFromPoints(pts);
    return new THREE.Line(g, new THREE.LineBasicMaterial({
      color: color, transparent: true, opacity: opacity, depthWrite: false
    }));
  }

  /**
   * 挂载地球背景
   * @param {HTMLCanvasElement} canvas 全屏 canvas
   * @param {Object} opts onReady / onFail / speed / mobile
   */
  function mount(canvas, opts) {
    opts = opts || {};
    var renderer;
    try {
      renderer = new THREE.WebGLRenderer({
        canvas: canvas, antialias: true, alpha: true,
        powerPreference: 'high-performance'
      });
    } catch (e) {
      canvas.style.display = 'none';
      document.documentElement.classList.add('no-webgl');
      if (opts.onFail) opts.onFail(e);
      return null;
    }

    renderer.setPixelRatio(Math.min(global.devicePixelRatio || 1, 2));
    renderer.setClearColor(0x000000, 0);

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera(40, 1, 0.1, 300);
    var globe = new THREE.Group();
    scene.add(globe);

    var sunDir = new THREE.Vector3(1, 0.3, 0.6).normalize();
    var surfaceMat = null, cloudMesh = null, atmosMat = null, stars = null;
    var rings = [];
    var clock = new THREE.Clock();
    var raf = 0, disposed = false;
    var reduced = global.matchMedia && global.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var motion = reduced ? 0.18 : (opts.speed || 1);
    var sunAngle = 38;
    var pointer = { x: 0, y: 0, tx: 0, ty: 0 };
    var layout = { x: 0.92, y: -0.04, dist: 3.72, narrow: false };

    /* 主题：深空（默认） / 浅色（bright = true） */
    var P = opts.light ? {
      dark: [0.70, 0.77, 0.90], darkAmt: 0.12, fres: [0.28, 0.54, 0.90],
      ambient: 1.34, nightOn: 0.0, bump: 0.36,
      haze: 0.30, hazeCol: [0.60, 0.71, 0.87],
      cloudDark: [0.84, 0.90, 0.98], cloudGain: 0.30,
      atmosA: [0.34, 0.60, 0.95], atmosB: [0.72, 0.89, 1.0], atmos: 0.52,
      ring1: 0x74a0d8, ring1o: 0.30, ring2: 0xa694dd, ring2o: 0.18
    } : {
      dark: [0.006, 0.012, 0.028], darkAmt: 0.055, fres: [0.16, 0.40, 0.88],
      ambient: 0.46, nightOn: 1.0, bump: 0.55,
      haze: 0.0, hazeCol: [0.0, 0.0, 0.0],
      cloudDark: [0.06, 0.10, 0.20], cloudGain: 0.42,
      atmosA: [0.10, 0.28, 0.68], atmosB: [0.42, 0.72, 1.0], atmos: 1.0,
      ring1: 0x5b9dff, ring1o: 0.30, ring2: 0x8f7bff, ring2o: 0.16
    };

    /* 星空（浅色主题下省略，避免白底上出现脏点） */
    if (!opts.light) (function buildStars() {
      var pos = [], col = [], n = 1100, i, u, t, s, r, w;
      for (i = 0; i < n; i++) {
        u = Math.random() * 2 - 1;
        t = Math.random() * Math.PI * 2;
        s = Math.sqrt(1 - u * u);
        r = 38 + Math.random() * 45;
        pos.push(r * s * Math.cos(t), r * u, r * s * Math.sin(t));
        w = 0.45 + Math.random() * 0.55;
        col.push(w * 0.86, w * 0.93, w);
      }
      var g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
      stars = new THREE.Points(g, new THREE.PointsMaterial({
        size: 1.5, sizeAttenuation: false, map: starTexture(), vertexColors: true,
        transparent: true, opacity: 0.78, depthWrite: false,
        blending: THREE.AdditiveBlending
      }));
      scene.add(stars);
    }());

    function build(tex) {
      globe.add(new THREE.Mesh(
        new THREE.SphereGeometry(1, 96, 64),
        (surfaceMat = new THREE.ShaderMaterial({
          uniforms: {
            uDay: { value: tex.day }, uNight: { value: tex.night },
            uSpec: { value: tex.spec }, uNormal: { value: tex.normal },
            uSun: { value: sunDir }, uCam: { value: camera.position },
            uNightOn: { value: P.nightOn }, uBump: { value: P.bump },
            uDark: { value: new THREE.Vector3().fromArray(P.dark) },
            uDarkAmt: { value: P.darkAmt },
            uFres: { value: new THREE.Vector3().fromArray(P.fres) },
            uAmbient: { value: P.ambient },
            uHaze: { value: P.haze },
            uHazeCol: { value: new THREE.Vector3().fromArray(P.hazeCol) }
          },
          vertexShader: VERT, fragmentShader: SURFACE_FRAG
        }))
      ));

      cloudMesh = new THREE.Mesh(
        new THREE.SphereGeometry(1.014, 80, 52),
        new THREE.ShaderMaterial({
          uniforms: {
            uCloud: { value: tex.cloud }, uSun: { value: sunDir },
            uCloudAlpha: { value: opts.cloudAlpha ? 1 : 0 },
            uCloudDark: { value: new THREE.Vector3().fromArray(P.cloudDark) },
            uCloudGain: { value: P.cloudGain }
          },
          vertexShader: VERT, fragmentShader: CLOUD_FRAG,
          transparent: true, depthWrite: false
        })
      );
      globe.add(cloudMesh);

      globe.add(new THREE.Mesh(
        new THREE.SphereGeometry(1.12, 56, 40),
        (atmosMat = new THREE.ShaderMaterial({
          uniforms: {
            uSun: { value: sunDir }, uStrength: { value: P.atmos },
            uColA: { value: new THREE.Vector3().fromArray(P.atmosA) },
            uColB: { value: new THREE.Vector3().fromArray(P.atmosB) }
          },
          vertexShader: ATMOS_VERT, fragmentShader: ATMOS_FRAG,
          side: THREE.BackSide, transparent: true, depthWrite: false,
          blending: THREE.AdditiveBlending
        }))
      ));

      var r1 = orbitRing(1.42, 1.42, P.ring1, P.ring1o);
      r1.rotation.x = 0.42; r1.rotation.z = -0.20;
      var r2 = orbitRing(1.68, 1.68, P.ring2, P.ring2o);
      r2.rotation.x = -0.30; r2.rotation.z = 0.26;
      rings.push(r1, r2);
      globe.add(r1, r2);
    }

    function resize() {
      var w = canvas.clientWidth || global.innerWidth;
      var h = canvas.clientHeight || global.innerHeight;
      if (!w || !h) return;
      renderer.setSize(w, h, false);
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      var narrow = w < 900 || camera.aspect < 1.05;
      layout.narrow = narrow;
      if (opts.centered) {
        // 移动端登录页：同一颗地球作整屏背景，xOffset/yOffset/distScale 控制构图
        layout.x = (opts.xOffset || 0); layout.y = -0.10 + (opts.yOffset || 0);
        var baseDist = narrow ? Math.max(4.6, 1.32 / (Math.tan(20 * Math.PI / 180) * camera.aspect)) : 4.3;
        layout.dist = baseDist * (opts.distScale || 1);
      } else if (narrow) {
        // 竖屏/手机：地球向右下方偏移，形成局部构图，登录卡片保持上半部清晰
        layout.x = 0.62; layout.y = -0.78;
        layout.dist = Math.min(6.4, Math.max(4.6, 1.38 / (Math.tan(20 * Math.PI / 180) * camera.aspect)));
      } else {
        layout.x = 0.92; layout.y = -0.04; layout.dist = 3.72;
      }
      camera.position.set(0, 0, layout.dist);
      camera.lookAt(0, 0, 0);
      globe.position.set(layout.x, layout.y, 0);
    }

    function onPointerMove(e) {
      if (layout.narrow) return;
      pointer.tx = (e.clientX / global.innerWidth - 0.5) * 0.10;
      pointer.ty = -(e.clientY / global.innerHeight - 0.5) * 0.07;
    }

    function frame() {
      if (disposed) return;
      raf = global.requestAnimationFrame(frame);
      if (document.hidden) { clock.getDelta(); return; }
      var dt = Math.min(clock.getDelta(), 0.06);
      if (!opts.sunStatic) {
        sunAngle = (sunAngle + dt * 3.2 * motion) % 360;
        var a = sunAngle * Math.PI / 180;
        sunDir.set(Math.cos(a), 0.30, Math.sin(a)).normalize();
      }

      globe.rotation.y += dt * 0.055 * motion;
      globe.rotation.x = -0.13;
      if (cloudMesh) cloudMesh.rotation.y += dt * 0.012 * motion;
      if (stars) stars.rotation.y += dt * 0.0016 * motion;
      if (rings.length) {
        rings[0].rotation.y += dt * 0.030 * motion;
        rings[1].rotation.y -= dt * 0.021 * motion;
      }
      pointer.x += (pointer.tx - pointer.x) * Math.min(1, dt * 2.4);
      pointer.y += (pointer.ty - pointer.y) * Math.min(1, dt * 2.4);
      globe.position.x = layout.x + pointer.x;
      globe.position.y = layout.y + pointer.y;
      if (surfaceMat) surfaceMat.uniforms.uCam.value.copy(camera.position);
      renderer.render(scene, camera);
    }

    global.addEventListener('resize', resize, { passive: true });
    global.addEventListener('pointermove', onPointerMove, { passive: true });
    resize();

    Promise.all([
      loadTex(TEX.day, renderer), loadTex(TEX.night, renderer),
      loadTex(TEX.spec, renderer), loadTex(TEX.normal, renderer),
      loadTex(TEX.cloud, renderer)
    ]).then(function (arr) {
      if (disposed) return;
      build({
        day: arr[0], night: arr[1], spec: arr[2],
        normal: arr[3],
        // 原始 PNG 的云量存在 alpha 通道，直接交给 shader 读取；
        // 内联灰度图则在 CPU 侧做一次平滑后读红通道。
        cloud: opts.cloudAlpha ? arr[4] : softenClouds(arr[4])
      });
      frame();
      if (opts.onReady) opts.onReady();
    }).catch(function (err) {
      if (opts.onFail) opts.onFail(err);
    });

    return {
      resize: resize,
      destroy: function () {
        disposed = true;
        global.cancelAnimationFrame(raf);
        global.removeEventListener('resize', resize);
        global.removeEventListener('pointermove', onPointerMove);
        renderer.dispose();
      }
    };
  }

  global.EarthBackground = { mount: mount };
})(window);
