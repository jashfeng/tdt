# v1.6.0 基础控件组（缩放按钮/比例尺/版权条）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 beige-tdt-map 插件补齐 A 级基础控件：缩放按钮、比例尺、版权条（四端）。

**Architecture:** 原生优先 + uvue 兜底。鸿蒙/Web 用各自 SDK 原生控件（MapOptions 开关 / addControl）；Android/iOS 原生 SDK 无内置缩放按钮与比例尺（context7 已验证），用 uvue 层补齐；版权条四端统一 uvue 层（天地图合规必需）。Android/iOS 同时隐藏 MapLibre 原生 logo/attribution（与 uvue 版权条重叠且版权信息错误）；鸿蒙华为 logo 移位右上避让（不可移除）；Web logo 用 CSS 隐藏（无官方开关）。

**Tech Stack:** uni-app x 蒸汽模式 UTS 原生插件、MapLibre Android 11.8.1、MapLibre iOS、鸿蒙 MapKit、MapLibre GL JS 4.7.1。

**Spec:** `docs/superpowers/specs/2026-08-16-v160-map-controls-design.md`（已批准）

**关键背景（执行者必读）：**
- 本项目无自动化测试框架，验证 = HBuilderX 编译 + 各端运行验证（计划中的"测试"步骤均为此形式）
- 规则第 8 条（强制）：每次改代码前必须 context7 验证；本计划已内置验证结论与来源，凡标注"实施时验证"的 API 必须先 WebSearch 再写码
- 改动 `utssdk/*/index.uts` 后必须重新打包（Web 重新运行即可；Android/iOS 必须重新制作自定义调试基座；鸿蒙本地打包）
- 四副本同步（Task 12），同步时 C 盘 config.uts 跳过（含真实 Key）
- 条件编译语法：模板内 `<!-- #ifdef APP-ANDROID || APP-IOS -->`（`||` 是官方正确语法），样式内 `/* #ifdef WEB */`

## 文件结构

| 文件 | 职责 | 改动 |
|---|---|---|
| `uni_modules/beige-tdt-map/utssdk/interface.uts` | 公开 API 类型 | TDMapOptions 加 2 可选字段 |
| `uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue` | 组件层 | 4 新 props + 三控件模板/样式 + 比例尺计算 + initMap 传参 |
| `uni_modules/beige-tdt-map/utssdk/web/index.uts` | Web 原生层 | logo CSS 隐藏 + 2 控件 addControl + initMap 防重复 |
| `uni_modules/beige-tdt-map/utssdk/app-harmony/index.uts` | 鸿蒙原生层 | MapOptions 控件开关 + logo 移位 + 审图号关闭 |
| `uni_modules/beige-tdt-map/utssdk/app-android/index.uts` | Android 原生层 | 隐藏原生 logo/attribution |
| `uni_modules/beige-tdt-map/utssdk/app-ios/index.uts` | iOS 原生层 | 隐藏原生 logo/attribution |
| 4 份 `package.json` | 版本号 | 1.5.8 → 1.6.0（+5 处 extVersion） |
| `uni_modules/beige-tdt-map/README.md` | 文档 | props 表 + 版本历史 |
| `tmp-publish/beige-tdt-map/changelog.md` | 变更日志 | v1.6.0 条目 |

已完成的 context7 验证（本计划引用，无需重复搜索）：

| API | 结论 | 来源 |
|---|---|---|
| 鸿蒙 MapOptions.zoomControlsEnabled（默认 true）/ scaleControlsEnabled（默认 false） | 存在 | developer.huawei.com/consumer/cn/doc/harmonyos-guides/map-controls-and-interaction |
| 鸿蒙 controller.setLogoAlignment / setLogoPadding / setApproveNumberEnabled（6.1.0(23) 起） | 存在；华为 logo 不可移除/遮挡，可移位 | 同上 |
| Web NavigationControl({showCompass:false}) / ScaleControl({maxWidth}) / addControl(ctrl, 'bottom-right') | 存在；同位置多控件自动堆叠 | MapLibre GL JS 官方文档 |
| Web logo 无 logoEnabled 选项，需 CSS 隐藏 `.maplibregl-ctrl-logo` | 确认 | MapLibre GL JS 官方 issue |
| Android UiSettings logo/attribution 开关 | 存在：Stadia Maps 官方文档 `map.uiSettings.isLogoEnabled = false`；Jawg 官方文档 XML 属性 `maplibre_uiLogo="false"` | Stadia/Jawg 官方集成文档 |
| MapLibre BSD-3 许可不强制 logo；天地图瓦片不含 OSM 数据，无 attribution 义务 | 合规结论 | Mapbox/MapLibre 许可条款 |

---

### Task 1: interface.uts — TDMapOptions 新增 2 个可选字段

**Files:**
- Modify: `uni_modules/beige-tdt-map/utssdk/interface.uts:1-11`

- [ ] **Step 1: 修改 TDMapOptions 定义**

现有代码（L1-11）：
```ts
export type TDMapOptions = {
    apiKey: string
    latitude: number
    longitude: number
    zoom: number
    mapType: string   // 'vec' | 'img' | 'ter'  矢量/影像/地形
    // v1.5.1: Android 专用可选字段。MapLibre 官方 issue #3070：SurfaceView 在模拟器/特殊层叠场景受限时，
    // 启用 textureMode(true) 改用 TextureView 渲染（走 Android 标准 View 绘制管线，模拟器软件渲染下更流畅）。
    // 真机保持默认 false（GLSurfaceView 硬件加速性能最优）；iOS/鸿蒙/H5 忽略此字段。
    textureMode?: boolean
}
```

改为在 `textureMode?: boolean` 后追加：
```ts
    // v1.6.0: 控件显隐（仅鸿蒙/Web 原生层初始化时读取；Android/iOS 忽略，由 uvue 层响应式控制）
    showZoomControl?: boolean
    showScaleControl?: boolean
}
```

- [ ] **Step 2: 验证编译**

HBuilderX 中打开项目，确认 interface.uts 无语法错误（Android/iOS/鸿蒙三端从 `../interface.uts` 导入 TDMapOptions，可选字段追加向后兼容，现有调用不受影响）。

- [ ] **Step 3: Commit**

```bash
git add uni_modules/beige-tdt-map/utssdk/interface.uts
git commit -m "feat(tdt-map): interface.uts TDMapOptions 新增 showZoomControl/showScaleControl 可选字段"
```

---

### Task 2: tdt-map.uvue — 新增 4 个 props

**Files:**
- Modify: `uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue:85-98`

- [ ] **Step 1: 追加 props 定义**

现有 props（L85-98）末尾 `textureMode` 后追加：
```ts
  // v1.6.0: 缩放按钮显隐（Android/iOS 为 uvue 样式；鸿蒙/Web 为原生样式，仅初始化生效）
  showZoomControl: { type: Boolean, default: true },
  // v1.6.0: 比例尺显隐（同上，鸿蒙/Web 仅初始化生效）
  showScaleControl: { type: Boolean, default: true },
  // v1.6.0: 版权条显隐（四端统一 uvue 层，天地图合规要求，默认开启；响应式）
  showCopyrightControl: { type: Boolean, default: true },
  // v1.6.0: 版权条文本。合规提示：建议填入你的天地图审图号，如"© 天地图 GS(2025)xxx号"
  // （审图号随 Key 申请获得，插件无法预知，需用户填写）
  copyrightText: { type: String, default: '© 天地图' }
```

- [ ] **Step 2: HBuilderX 检查语法**（无编译错误）

- [ ] **Step 3: Commit**

```bash
git add uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue
git commit -m "feat(tdt-map): 组件层新增 showZoomControl/showScaleControl/showCopyrightControl/copyrightText props"
```

---

### Task 3: tdt-map.uvue — 三控件模板（缩放按钮/比例尺/版权条）

**Files:**
- Modify: `uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue:53-57`（定位按钮后追加）

- [ ] **Step 1: 追加模板**

在定位按钮（L54-56）与根 view 闭合标签之间插入：
```html
    <!-- ═══ v1.6.0 缩放按钮组 ═══
    Android/iOS 原生 SDK 无内置缩放按钮（context7 已验证），uvue 层补齐，点击调 zoomIn/zoomOut；
    鸿蒙/Web 端用原生控件（各自原生层实现），此块经条件编译仅存在于 APP-ANDROID/APP-IOS -->
    <!-- #ifdef APP-ANDROID || APP-IOS -->
    <view v-if="showZoomControl" class="tdt-zoom-control">
      <view class="tdt-zoom-btn" @tap="zoomInOne">
        <text class="tdt-zoom-icon">+</text>
      </view>
      <view class="tdt-zoom-divider" />
      <view class="tdt-zoom-btn" @tap="zoomOutOne">
        <text class="tdt-zoom-icon">−</text>
      </view>
    </view>
    <!-- #endif -->

    <!-- ═══ v1.6.0 比例尺 ═══
    OSM Wiki ground resolution 公式计算（天地图 256px 瓦片 Web Mercator 适用）：
    米/px = 156543.03 × cos(lat) / 2^zoom；取 [1,2,5]×10ⁿ 中 ≤100px 最大档 -->
    <!-- #ifdef APP-ANDROID || APP-IOS -->
    <view v-if="showScaleControl" class="tdt-scale-control">
      <view class="tdt-scale-bar" :style="{ width: scaleBarWidth + 'px' }">
        <view class="tdt-scale-tick tdt-scale-tick-left" />
        <view class="tdt-scale-line" />
        <view class="tdt-scale-tick tdt-scale-tick-right" />
      </view>
      <text class="tdt-scale-text">{{ scaleText }}</text>
    </view>
    <!-- #endif -->

    <!-- ═══ v1.6.0 版权条 ═══
    四端统一 uvue 层渲染。天地图服务条款要求在地图显著位置（官方参考左下角）标注"天地图"标识与审图号，
    未标注将被暂停调用（来源：tianditu.gov.cn/about/copyright） -->
    <view v-if="showCopyrightControl" class="tdt-copyright">
      <text class="tdt-copyright-text">{{ copyrightText }}</text>
    </view>
```

- [ ] **Step 2: HBuilderX 检查模板语法**

- [ ] **Step 3: Commit**

```bash
git add uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue
git commit -m "feat(tdt-map): 新增缩放按钮/比例尺/版权条 uvue 模板（缩放与比例尺条件编译 Android/iOS）"
```

---

### Task 4: tdt-map.uvue — 三控件样式 + 定位按钮避让

**Files:**
- Modify: `uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue:633-680`（style 区）

- [ ] **Step 1: 定位按钮条件编译避让**

现有 `.tdt-locate-btn`（L634-646）中 `bottom: 180rpx;` 改为：
```css
.tdt-locate-btn {
  position: absolute;
  right: 20rpx;
  /* #ifdef WEB || APP-HARMONY */
  /* v1.6.0: Web 原生 NavigationControl+ScaleControl 右下堆叠、鸿蒙原生缩放按钮默认右下，
  避让上移（初值 200rpx，实测校准） */
  bottom: 200rpx;
  /* #endif */
  /* #ifdef APP-ANDROID || APP-IOS */
  bottom: 180rpx;
  /* #endif */
  width: 84rpx;
  height: 84rpx;
  border-radius: 42rpx;
  background-color: #ffffff;
  justify-content: center;
  align-items: center;
  box-shadow: 0 2rpx 10rpx rgba(0, 0, 0, 0.2);
  z-index: 100;
}
```

- [ ] **Step 2: 追加三控件样式（style 区末尾、`</style>` 前）**

```css
/* ═══ v1.6.0 缩放按钮组（z-index 93：低于现有控件 95~100，高于版权条/比例尺） ═══ */
.tdt-zoom-control {
  position: absolute;
  right: 20rpx;
  bottom: 45%;
  width: 84rpx;
  background-color: #ffffff;
  border-radius: 42rpx;
  box-shadow: 0 2rpx 10rpx rgba(0, 0, 0, 0.2);
  z-index: 93;
  flex-direction: column;
  overflow: hidden;
}
.tdt-zoom-btn {
  width: 84rpx;
  height: 84rpx;
  justify-content: center;
  align-items: center;
}
.tdt-zoom-divider {
  height: 1rpx;
  background-color: #e5e5e5;
  margin-left: 16rpx;
  margin-right: 16rpx;
}
.tdt-zoom-icon {
  font-size: 48rpx;
  color: #333333;
  font-weight: bold;
}

/* ═══ v1.6.0 比例尺（z-index 91，左下角版权条之上 bottom≈26px） ═══ */
.tdt-scale-control {
  position: absolute;
  left: 20rpx;
  bottom: 52rpx;
  z-index: 91;
  flex-direction: column;
  align-items: flex-start;
  background-color: rgba(255, 255, 255, 0.7);
  border-radius: 6rpx;
  padding: 6rpx 10rpx;
}
.tdt-scale-bar {
  height: 16rpx;
  position: relative;
}
.tdt-scale-tick {
  position: absolute;
  bottom: 0;
  width: 2rpx;
  height: 16rpx;
  background-color: #333333;
}
.tdt-scale-tick-left { left: 0; }
.tdt-scale-tick-right { right: 0; }
.tdt-scale-line {
  position: absolute;
  bottom: 7rpx;
  left: 0;
  right: 0;
  height: 2rpx;
  background-color: #333333;
}
.tdt-scale-text {
  font-size: 20rpx;
  color: #333333;
  margin-top: 2rpx;
}

/* ═══ v1.6.0 版权条（z-index 90 最低，不得遮挡气泡） ═══ */
.tdt-copyright {
  position: absolute;
  left: 8rpx;
  bottom: 8rpx;
  z-index: 90;
  background-color: rgba(255, 255, 255, 0.7);
  border-radius: 6rpx;
  padding: 4rpx 10rpx;
}
.tdt-copyright-text {
  font-size: 20rpx;
  color: #333333;
}
```

- [ ] **Step 3: HBuilderX 检查样式语法**

- [ ] **Step 4: Commit**

```bash
git add uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue
git commit -m "feat(tdt-map): 三控件样式（z-index 90/91/93）+ 定位按钮 Web/鸿蒙避让条件编译"
```

---

### Task 5: tdt-map.uvue — 比例尺计算逻辑 + 回调挂接 + initMap 传新字段

**Files:**
- Modify: `uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue`（script 区多处）

- [ ] **Step 1: 追加比例尺计算逻辑**

在 `hideBubble` 函数（L213-215）后插入：
```ts
// ═══ v1.6.0: 比例尺计算 ═══
// OSM Wiki "Zoom levels" 标准 ground resolution（天地图为标准 256px 瓦片 Web Mercator）：
// 米/px = 156543.03 × cos(lat) / 2^zoom；tilt=0 时精确，tilt≠0 按屏幕中心纬度近似
// （与高德/百度等主流地图行为一致）
const scaleText = ref('')
const scaleBarWidth = ref(100)
const SCALE_MAX_PX = 100

function formatScaleDistance(meters: number): string {
  if (meters >= 1000) return (meters / 1000) + 'km'
  return meters + 'm'
}

function updateScale(): void {
  const zoom = getCurrentZoom()
  const center = getCurrentCenter()
  const latRad = center.lat * Math.PI / 180
  const metersPerPx = 156543.03 * Math.cos(latRad) / Math.pow(2, zoom)
  // 从 [1, 2, 5] × 10ⁿ 米系列中取"像素宽 ≤ 100px"的最大值
  let bestMeters = 1
  for (let mag = -3; mag <= 6; mag++) {
    const base = Math.pow(10, mag)
    const factors = [1, 2, 5]
    for (let k = 0; k < factors.length; k++) {
      const meters = factors[k] * base
      if (meters / metersPerPx <= SCALE_MAX_PX) {
        bestMeters = meters
      }
    }
  }
  scaleBarWidth.value = Math.max(20, Math.round(bestMeters / metersPerPx))
  scaleText.value = formatScaleDistance(bestMeters)
}
```

- [ ] **Step 2: mapReady 回调挂接 updateScale**

`onNativeViewInit`（L251-254）的 onReady 回调改为：
```ts
    () => {
      isMapReady.value = true
      // v1.6.0: 初始化完成后计算比例尺
      updateScale()
      emit('mapReady')
    },
```

Web 端 onMounted 内（L502-505）同样改为：
```ts
    () => {
      isMapReady.value = true
      // v1.6.0: 初始化完成后计算比例尺
      updateScale()
      emit('mapReady')
    },
```

- [ ] **Step 3: cameraChange 回调挂接 updateScale**

`onNativeViewInit` 内 setCameraChangeCallback（L271-274）改为：
```ts
  setCameraChangeCallback((detail: MapClickDetail) => {
    updateBubblePosition()
    // v1.6.0: 相机变化后重算比例尺
    updateScale()
    emit('cameraChange', detail)
  })
```

Web 端 onMounted 内（L519-522）同样改为：
```ts
  setCameraChangeCallback((detail: MapClickDetail) => {
    updateBubblePosition()
    // v1.6.0: 相机变化后重算比例尺
    updateScale()
    emit('cameraChange', detail)
  })
```

- [ ] **Step 4: initMap 调用传新字段（两处）**

`onNativeViewInit` 的 initMap options 对象（L240-247）追加：
```ts
    {
      apiKey: effectiveApiKey.value,
      latitude: props.latitude,
      longitude: props.longitude,
      zoom: props.zoom,
      mapType: props.mapType,
      textureMode: props.textureMode,
      // v1.6.0: 控件开关透传（鸿蒙/Web 原生层初始化读取；Android/iOS 忽略）
      showZoomControl: props.showZoomControl,
      showScaleControl: props.showScaleControl
    },
```

Web 端 onMounted 的 initMap options 对象（L492-497）追加：
```ts
    {
      apiKey: effectiveApiKey.value,
      latitude: props.latitude,
      longitude: props.longitude,
      zoom: props.zoom,
      mapType: props.mapType,
      // v1.6.0: 控件开关透传（Web 原生层初始化读取）
      showZoomControl: props.showZoomControl,
      showScaleControl: props.showScaleControl
    },
```

- [ ] **Step 5: HBuilderX 检查 script 语法**

- [ ] **Step 6: Commit**

```bash
git add uni_modules/beige-tdt-map/components/tdt-map/tdt-map.uvue
git commit -m "feat(tdt-map): 比例尺计算公式（OSM Wiki ground resolution）+ mapReady/cameraChange 重算 + props 透传"
```

---

### Task 6: Web 端 index.uts — logo CSS 隐藏 + 原生控件 + initMap 防重复

**Files:**
- Modify: `uni_modules/beige-tdt-map/utssdk/web/index.uts`

- [ ] **Step 1: 本地 TDMapOptions 类型同步（L7-13）**

Web 端有独立的本地类型定义（不从 interface.uts 导入），追加：
```ts
type TDMapOptions = {
    apiKey: string
    latitude: number
    longitude: number
    zoom: number
    mapType: string
    // v1.6.0: 控件显隐（与 interface.uts TDMapOptions 保持一致）
    showZoomControl?: boolean
    showScaleControl?: boolean
}
```

- [ ] **Step 2: initMap 防重复初始化**

`loadMapLibreGL().then(() => {`（L193）回调内第一行（`const mlg = getMapLibre()` 之前）插入：
```ts
        // v1.6.0: 防御重复初始化（组件重建场景）——旧 map 先销毁，避免双地图叠加
        // （控件实例挂在 map 对象上，map.remove() 会一并清理，无需单独 removeControl）
        if (mapInstance != null) {
            try { mapInstance.remove() } catch (e: any) { /* ignore */ }
            mapInstance = null
        }
```

- [ ] **Step 3: 隐藏 MapLibre 原生 logo + 添加控件**

在 `mapInstance = map`（L290）之前插入：
```ts
            // v1.6.0: 隐藏 MapLibre 原生 logo —— GL JS 无官方 logoEnabled 选项（仅有 logoPosition 移位），
            // logo 默认左下角会与 uvue 版权条重叠；MapLibre BSD-3 许可不强制显示。
            // CSS 注入隐藏（幂等：按 id 查重）
            if (document.getElementById('tdt-hide-logo-style') == null) {
                const hideLogoStyle = document.createElement('style')
                hideLogoStyle.id = 'tdt-hide-logo-style'
                hideLogoStyle.textContent = '.maplibregl-ctrl-logo { display: none !important; }'
                document.head.appendChild(hideLogoStyle)
            }

            // v1.6.0: 缩放按钮与比例尺 —— context7 验证：同位置 bottom-right 多控件由
            // MapLibre GL JS 自动堆叠排列，不重叠。控件实例挂在 map 对象上
            // （非模块级变量），多地图实例场景无污染。
            if (options.showZoomControl !== false) {
                const navControl = new mlg.NavigationControl({ showCompass: false })
                map.addControl(navControl, 'bottom-right')
                map.tdtNavControl = navControl
            }
            if (options.showScaleControl !== false) {
                const scaleControl = new mlg.ScaleControl({ maxWidth: 100 })
                map.addControl(scaleControl, 'bottom-right')
                map.tdtScaleControl = scaleControl
            }
```

- [ ] **Step 4: destroyMap 补清理**

`destroyMap`（L384-406）中 `mapInstance.remove()` 后追加注释行即可（remove 已清理控件，无需改动代码，仅确认现状）。

- [ ] **Step 5: 运行验证（HBuilderX 运行到浏览器）**

- 预期：地图右下角出现原生缩放按钮（+/-）与比例尺堆叠；左下角无 MapLibre logo，只有 uvue 版权条"© 天地图"；定位按钮在原生控件上方无重叠
- `showZoomControl=false` / `showScaleControl=false` / `showCopyrightControl=false` 各开关验证

- [ ] **Step 6: Commit**

```bash
git add uni_modules/beige-tdt-map/utssdk/web/index.uts
git commit -m "feat(tdt-map): Web 端 NavigationControl+ScaleControl（bottom-right 自动堆叠）+ logo CSS 隐藏 + initMap 防重复"
```

---

### Task 7: 鸿蒙端 index.uts — MapOptions 控件开关 + logo 移位 + 审图号关闭

**Files:**
- Modify: `uni_modules/beige-tdt-map/utssdk/app-harmony/index.uts:221-226,235`

- [ ] **Step 1: MapOptions 加控件开关（L221-226）**

```ts
    // v1.6.0: 控件显隐 —— context7 验证华为官方文档（developer.huawei.com/consumer/cn/doc/
    // harmonyos-guides/map-controls-and-interaction）：zoomControlsEnabled 默认 true、
    // scaleControlsEnabled 默认 false，均需按插件 props（默认 true）显式设置
    const mapOptions: mapCommon.MapOptions = {
        position: {
            target: { latitude: options.latitude, longitude: options.longitude },
            zoom: options.zoom
        },
        zoomControlsEnabled: options.showZoomControl !== false,
        scaleControlsEnabled: options.showScaleControl !== false
    }
```

- [ ] **Step 2: controller 就绪后加 logo 移位 + 审图号关闭（L235 `mapController = controller` 之后）**

```ts
        mapController = controller

        // v1.6.0: 华为 logo 不可移除/遮挡（官方政策），移位右上角避让左下角 uvue 版权条；
        // 审图号为华为地图内容与天地图无关，显式关闭（setApproveNumberEnabled 自 6.1.0(23) 支持），
        // 版权由 uvue 版权条统一承担
        // 来源：developer.huawei.com/consumer/cn/doc/harmonyos-guides/map-controls-and-interaction
        controller.setLogoAlignment(mapCommon.LogoAlignment.TOP_END)
        controller.setApproveNumberEnabled(false)
```

- [ ] **Step 3: 实施时验证（若编译报错按此排查）**

- `mapCommon.LogoAlignment.TOP_END`：若枚举名不存在，WebSearch "HarmonyOS MapKit LogoAlignment TOP_END" 确认枚举值名（BOTTOM_END 已确认存在，TOP_END 为对称枚举）
- `setApproveNumberEnabled`：若编译报"方法不存在"（鸿蒙 SDK 版本 < 6.1.0(23)），注释该行并在日志注明"审图号默认开启需升级 SDK 后处理"

- [ ] **Step 4: 本地打包验证（鸿蒙仅支持本地打包）**

- 预期：原生缩放按钮/比例尺按 props 显示；华为 logo 在右上角；左下角 uvue 版权条无重叠

- [ ] **Step 5: Commit**

```bash
git add uni_modules/beige-tdt-map/utssdk/app-harmony/index.uts
git commit -m "feat(tdt-map): 鸿蒙端 zoomControlsEnabled/scaleControlsEnabled 开关 + 华为 logo 移位右上 + 审图号关闭"
```

---

### Task 8: Android 端 index.uts — 隐藏原生 logo/attribution

**Files:**
- Modify: `uni_modules/beige-tdt-map/utssdk/app-android/index.uts:211-213`

- [ ] **Step 1: uiSettings 处追加（L211-213 之后）**

现有代码：
```ts
        const uiSettings = map.getUiSettings()
        uiSettings?.setAllGesturesEnabled(true)
        console.log("TDTMap: 手势状态 zoom=" + (uiSettings?.isZoomGesturesEnabled() ?? false) + " scroll=" + (uiSettings?.isScrollGesturesEnabled() ?? false))
```

在 `setAllGesturesEnabled(true)` 之后追加：
```ts
        // v1.6.0: 隐藏 MapLibre 原生 logo 与 attribution —— context7 验证：
        // Stadia Maps 官方文档 map.uiSettings.isLogoEnabled = false（Kotlin 属性对应
        // setLogoEnabled/isLogoEnabled 方法对）、Jawg Maps 官方文档 XML 属性 maplibre_uiLogo="false"。
        // MapLibre 默认 logo（左下）与 attribution ℹ 按钮（显示"© MapLibre"）会与 uvue 版权条
        // 重叠且版权信息对天地图场景是错误的；MapLibre BSD-3 许可不强制显示 logo，
        // 天地图瓦片不含 OSM 数据无 attribution 义务，版权统一由 uvue 版权条承担
        uiSettings?.setLogoEnabled(false)
        uiSettings?.setAttributionEnabled(false)
```

- [ ] **Step 2: 实施时验证（若编译报错按此排查）**

- 若 `setLogoEnabled` 编译报"方法不存在"：UTS 可能暴露为 Kotlin 属性写法 `uiSettings?.isLogoEnabled = false`，改用属性赋值
- `setAttributionEnabled` 同理，属性写法候选 `uiSettings?.isAttributionEnabled = false`

- [ ] **Step 3: 重新制作自定义调试基座（含第三方依赖，标准基座不可用）后真机验证**

- 预期：左下角无 MapLibre logo/attribution ℹ；uvue 缩放按钮右侧中部、比例尺左下、版权条最底部；定位按钮右下无重叠

- [ ] **Step 4: Commit**

```bash
git add uni_modules/beige-tdt-map/utssdk/app-android/index.uts
git commit -m "feat(tdt-map): Android 端隐藏 MapLibre 原生 logo/attribution（版权统一由 uvue 版权条承担）"
```

---

### Task 9: iOS 端 index.uts — 隐藏原生 logo/attribution

**Files:**
- Modify: `uni_modules/beige-tdt-map/utssdk/app-ios/index.uts:181-182`

- [ ] **Step 1: context7 验证（写码前必须）**

WebSearch 确认 MapLibre iOS（MLN，fork 自 Mapbox iOS 6）MLNMapView 的 logo/attribution 属性名：
```
查询："MLNMapView" MapLibre iOS logoView attributionButton hidden
```
Mapbox iOS 6 系公开属性为 `logoView`（UIView, readonly）与 `attributionButton`（UIButton, readonly）；确认 MLN fork 保留同名属性后再写码。

- [ ] **Step 2: MLNMapView 创建后隐藏（L181-182 之后）**

```ts
    mapView = new MLNMapView(frame, styleURL)
    container.bindIOSView(mapView)

    // v1.6.0: 隐藏 MapLibre 原生 logo 与 attribution button —— MapLibre 默认 logo（左下）
    // 与 attribution ℹ（右下）会与 uvue 版权条重叠且版权信息对天地图场景是错误的；
    // MapLibre BSD-3 许可不强制显示 logo，天地图瓦片不含 OSM 数据无 attribution 义务，
    // 版权统一由 uvue 版权条承担（API 名经 Task 9 Step 1 验证）
    mapView.logoView?.hidden = true
    mapView.attributionButton?.hidden = true
```

- [ ] **Step 3: 实施时验证（若编译报错按此排查）**

- 若 `hidden` 报错：UTS iOS 中 UIView 的 hidden 属性可能暴露为 `isHidden`，改为 `mapView.logoView?.isHidden = true`
- 若 `logoView` 报"不存在"：按 Step 1 验证结果修正属性名

- [ ] **Step 4: 重新制作自定义调试基座后真机/模拟器验证**

- 预期：无 MapLibre logo 与 attribution ℹ；uvue 三控件显示正常

- [ ] **Step 5: Commit**

```bash
git add uni_modules/beige-tdt-map/utssdk/app-ios/index.uts
git commit -m "feat(tdt-map): iOS 端隐藏 MapLibre 原生 logo/attribution（版权统一由 uvue 版权条承担）"
```

---

### Task 10: 版本号 1.5.8 → 1.6.0 + changelog

**Files:**
- Modify: 4 份 `package.json`（uni_modules / example-project/uni_modules / tmp-publish / C 盘 tdt-app/uni_modules，路径均含 `beige-tdt-map/package.json`）
- Modify: `tmp-publish/beige-tdt-map/changelog.md`

- [ ] **Step 1: 修改版本号**

4 份 package.json 中所有 `1.5.8` 替换为 `1.6.0`（每份含顶层 `version` 字段 + 依赖 `extVersion` 字段共 5 处，用 grep 确认无遗漏）：
```
grep -n "1.5.8" <package.json 路径>
```
替换后必须为 0 处 `1.5.8` 残留、每份 5 处 `1.6.0`。

- [ ] **Step 2: changelog.md 顶部追加条目**

```markdown
## v1.6.0（2026-08-16）

- 新增缩放按钮控件：Android/iOS 为 uvue 层样式（调 zoomIn/zoomOut），鸿蒙为原生 zoomControlsEnabled，Web 为原生 NavigationControl
- 新增比例尺控件：Android/iOS 为 uvue 层公式计算（OSM Wiki ground resolution），鸿蒙为原生 scaleControlsEnabled，Web 为原生 ScaleControl
- 新增版权条控件：四端统一 uvue 层（天地图服务条款合规要求），默认"© 天地图"，可通过 copyrightText 填入审图号
- 新增 props：showZoomControl / showScaleControl / showCopyrightControl / copyrightText
- 注意：showZoomControl/showScaleControl 在鸿蒙/Web 原生端为初始化一次性配置（同 textureMode 限制）；Android/iOS 的 uvue 控件与版权条 props 天然响应式
- 修复：Android/iOS/Web 隐藏 MapLibre 原生 logo 与 attribution（避免与版权条重叠及错误版权信息）；鸿蒙华为 logo 移位右上角避让
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore(tdt-map): 版本号 1.5.8 → 1.6.0 + changelog v1.6.0 条目"
```

---

### Task 11: README 更新

**Files:**
- Modify: `uni_modules/beige-tdt-map/README.md`

- [ ] **Step 1: 功能概览表补"内置控件"**

在功能概览部分补充一行：
```
| 内置控件 | 缩放按钮、比例尺、版权条（v1.6.0） |
```

- [ ] **Step 2: props 表追加 4 行**

```markdown
| showZoomControl | Boolean | true | 缩放按钮显隐（Android/iOS 为 uvue 样式；鸿蒙/Web 为原生样式，仅初始化生效） |
| showScaleControl | Boolean | true | 比例尺显隐（同上，鸿蒙/Web 仅初始化生效） |
| showCopyrightControl | Boolean | true | 版权条显隐（四端统一 uvue 层，天地图合规要求，默认开启） |
| copyrightText | String | '© 天地图' | 版权条文本。合规提示：建议填入你的天地图审图号，如"© 天地图 GS(2025)xxx号" |
```

- [ ] **Step 3: 版本历史追加 v1.6.0 章节**

```markdown
## v1.6.0（2026-08-16）

- 新增缩放按钮/比例尺/版权条三大基础控件（对标插件市场同类插件能力）
- 缩放按钮与比例尺：Android/iOS 用 uvue 层实现（原生 SDK 无内置控件），鸿蒙/Web 用原生控件
- 版权条：四端统一 uvue 层，满足天地图服务条款（显著位置标注"天地图"标识与审图号）
- 新增 4 个 props：showZoomControl / showScaleControl / showCopyrightControl / copyrightText
- 动态切换限制：showZoomControl/showScaleControl 在鸿蒙/Web 原生端为初始化一次性配置（同 textureMode 限制）；Android/iOS 的 uvue 控件与 copyrightText/showCopyrightControl 天然响应式
- 修复：Android/iOS/Web 隐藏 MapLibre 原生 logo 与 attribution（避免与版权条重叠及错误版权信息）；鸿蒙华为 logo 移位右上角避让
```

- [ ] **Step 4: Commit**

```bash
git add uni_modules/beige-tdt-map/README.md
git commit -m "docs(tdt-map): README 补 v1.6.0 控件 props 表与版本历史"
```

---

### Task 12: 四副本同步

**Files:** 同步目录（PowerShell，注意不支持 `&&`，逐条执行）

- [ ] **Step 1: 同步 uni_modules → example-project**

```powershell
robocopy "f:\uniapp x UTS原生插件\uni_modules\beige-tdt-map" "f:\uniapp x UTS原生插件\example-project\uni_modules\beige-tdt-map" /MIR /XF config.uts /NFL /NDL /NJH
```

- [ ] **Step 2: 同步 uni_modules → tmp-publish**

```powershell
robocopy "f:\uniapp x UTS原生插件\uni_modules\beige-tdt-map" "f:\uniapp x UTS原生插件\tmp-publish\beige-tdt-map" /MIR /NFL /NDL /NJH
```

- [ ] **Step 3: 同步 uni_modules → C 盘 tdt-app（跳过 config.uts——C 盘含用户真实 Key，禁止覆盖）**

```powershell
robocopy "f:\uniapp x UTS原生插件\uni_modules\beige-tdt-map" "C:\Users\Administrator\Documents\HBuilderProjects\tdt-app\uni_modules\beige-tdt-map" /MIR /XF config.uts /NFL /NDL /NJH
```

- [ ] **Step 4: 校验**

对三副本 grep `1.6.0`（package.json 各 5 处）、`showZoomControl`（tdt-map.uvue + interface.uts + web/index.uts）、确认 C 盘 config.uts 仍为真实 Key 文件（未被覆盖）。

- [ ] **Step 5: Commit（仅 F 盘范围）**

```bash
git add -A
git commit -m "chore(tdt-map): v1.6.0 四副本同步（C 盘 config.uts 按惯例跳过）"
```

---

### Task 13: 打包与全端验证

**Files:** 无代码改动，验证任务

- [ ] **Step 1: Web 端验证（HBuilderX 运行到浏览器）**

- 原生 NavigationControl（+/-）+ ScaleControl 右下自动堆叠，无重叠
- MapLibre logo 已隐藏（CSS 注入生效），uvue 版权条左下显示"© 天地图"
- 定位按钮避让（bottom 200rpx）与原生控件无重叠；缩放/比例尺/版权条三开关各场景

- [ ] **Step 2: Android 真机验证（必须重新制作自定义基座）**

- HBuilderX → 运行 → 制作自定义调试基座（config.json 依赖不变，云端打包一次）
- 验证点：uvue 缩放按钮显示与 ± 功能；比例尺随缩放变化（北京 zoom 10 显示约 10km 档、zoom 13 约 1km 档）；无 MapLibre logo/attribution；版权条显示；三控件与搜索框/定位按钮/气泡无重叠

- [ ] **Step 3: iOS 真机/模拟器验证（同需重新制作自定义基座）**

- 验证点同 Android

- [ ] **Step 4: 鸿蒙本地打包验证**

- 原生缩放按钮/比例尺显示；华为 logo 移位右上；审图号关闭；uvue 版权条左下；定位按钮已上移避让

- [ ] **Step 5: 全端开关场景**

- `showZoomControl=false` / `showScaleControl=false` / `showCopyrightControl=false` 单独与组合关闭
- `copyrightText` 自定义（如"© 天地图 GS(2025)xxx号"）
- Android/iOS 端动态切换 showZoomControl（响应式即时生效）；鸿蒙/Web 端确认"仅初始化生效"限制与 README 描述一致

---

## Self-Review

**Spec coverage 对照（设计文档 8 节 → 任务映射）：**

| 设计文档节 | 任务 | 状态 |
|---|---|---|
| 3.1 四个 props | Task 2 | ✅ |
| 3.2 interface.uts 两字段 | Task 1 | ✅ |
| 4.1 鸿蒙（开关/logo/审图号） | Task 7 | ✅ |
| 4.2 Web（attribution 保留/logo CSS/控件/幂等） | Task 6 | ✅ |
| 4.3 Android（隐藏 logo/attribution） | Task 8 | ✅ |
| 4.4 iOS（隐藏 logo/attribution） | Task 9 | ✅ |
| 4.5 基座影响 | Task 13 Step 2/3 | ✅ |
| 5.1 缩放按钮模板 | Task 3 | ✅ |
| 5.2 比例尺（公式/取整/重算时机） | Task 3 + 5 | ✅ |
| 5.3 版权条 | Task 3 | ✅ |
| 6 布局避让/z-index | Task 4 | ✅ |
| 7 版本/README/changelog/四副本 | Task 10/11/12 | ✅ |
| 8 测试计划 | Task 13 | ✅ |
| 9 假设（鸿蒙 API 可用性） | Task 7 Step 3 | ✅ |

**Placeholder scan:** 无 TBD/TODO；所有代码步骤含完整代码；"实施时验证"项均给出具体排查步骤与候选写法（Task 7 Step 3、Task 8 Step 2、Task 9 Step 3）。

**Type consistency:** `showZoomControl`/`showScaleControl` 命名在 interface.uts（Task 1）、web 本地类型（Task 6）、uvue props（Task 2）、initMap 传参（Task 5）、鸿蒙 mapOptions（Task 7）全程一致；`scaleText`/`scaleBarWidth`/`updateScale` 在 Task 3 模板与 Task 5 逻辑中命名一致；`tdt-zoom-control`/`tdt-scale-control`/`tdt-copyright` 类名模板（Task 3）与样式（Task 4）一致。
