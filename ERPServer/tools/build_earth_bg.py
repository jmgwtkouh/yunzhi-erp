#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""复用 earth-globe.html 里的 three.js 与贴图，生成登录页地球背景资源。

产物（均为自包含单文件，无外部依赖、可离线使用）：
  app/web/earth-bg.js                       管理台登录页直接引用
  ../ERPiOS/ERPiOS/Resources/earth-login-bg.html   iOS WKWebView 背景
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "ERPServer" / "app" / "web"
TOOLS = ROOT / "ERPServer" / "tools"
IOS_RES = ROOT / "ERPiOS" / "ERPiOS" / "Resources"

blocks = re.findall(r"<script[^>]*>(.*?)</script>",
                    (ROOT / "earth-globe.html").read_text(encoding="utf-8"), re.S)
assert len(blocks) >= 2, "earth-globe.html 结构异常"
three = blocks[0].replace("</script", "<\\/script")
tex_block = re.search(r"var TEX = \{(.*?)\n  \};", blocks[1], re.S)
assert tex_block, "未找到贴图数据"
textures = dict(re.findall(r"(\w+):\s*'(data:[^']+)'", tex_block.group(1)))
assert set(textures) == {"day", "night", "spec", "normal", "cloud"}

renderer = (TOOLS / "earth_renderer.js").read_text(encoding="utf-8")
renderer = renderer.replace("__TEXTURES__", json.dumps(textures, separators=(",", ":")))
assert "__TEXTURES__" not in renderer

# 1) 管理台：three.js + 贴图 + 渲染器全部内联
web_js = ("/* 云智 ERP 登录页 3D 地球背景 · three.js r128 + NASA 贴图，全部内联离线可用 */\n"
          + three + "\n;\n" + renderer)
(WEB / "earth-bg.js").write_text(web_js, encoding="utf-8")
print("earth-bg.js:", (WEB / "earth-bg.js").stat().st_size, "bytes")

# 2) iOS：同样的渲染器装进透明 WebView 页面
ios_html = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>earth</title>
<style>
  html,body{margin:0;padding:0;height:100%;overflow:hidden;background:#eef4ff}
  body{background:
    radial-gradient(860px 600px at 76% 10%,rgba(255,255,255,.98),transparent 64%),
    radial-gradient(700px 620px at 8% 92%,rgba(180,205,242,.56),transparent 62%),
    linear-gradient(160deg,#f6faff 0%,#e8f0fd 52%,#dbe8fa 100%);}
  #g{position:fixed;inset:0;width:100%;height:100%;display:block;
    filter:saturate(1.05) contrast(1.02) opacity(.94)}
  .veil{position:fixed;inset:0;pointer-events:none;
    background:linear-gradient(180deg,rgba(248,251,255,.20) 0%,rgba(248,251,255,.01) 42%,rgba(226,238,252,.24) 100%);}
  .grain{position:fixed;inset:0;pointer-events:none;opacity:.12;
    background-image:radial-gradient(rgba(58,92,142,.55) .6px,transparent .6px);
    background-size:46px 46px;}
</style>
</head>
<body>
<canvas id="g"></canvas>
<div class="veil"></div><div class="grain"></div>
<script>__THREE__</script>
<script>__RENDERER__
EarthBackground.mount(document.getElementById('g'), { centered:true, speed:0.85, light:true, xOffset:0.72, yOffset:-1.15, distScale:0.95, sunStatic:true });
</script>
</body>
</html>
""".replace("__THREE__", three).replace("__RENDERER__", renderer)
IOS_RES.mkdir(parents=True, exist_ok=True)
target = IOS_RES / "earth-login-bg.html"
target.write_text(ios_html, encoding="utf-8")
print("earth-login-bg.html:", target.stat().st_size, "bytes")
