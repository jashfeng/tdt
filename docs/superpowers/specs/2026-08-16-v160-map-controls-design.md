# v1.6.0 基础控件组设计文档

日期：2026-08-16
状态：已确认（等待用户审查）
插件：beige-tdt-map（uni-app x 蒸汽模式 UTS 原生插件，天地图四端）

## 1. 背景与目标

对标插件市场同类插件（xwp-tianditu），补齐缺失的 A 级基础控件：**缩放按钮、比例尺、版权条**。
本次为 10 项功能规划的第一期（基础控件组），其余功能（标记聚合、热力图、折线测距、
图片覆盖物、鹰眼、地图类型控件、动态样式）留待后续版本。

**硬性约束**（context7 已验证，2026-08-16）：

- MapLibre Android 11.8.1 / iOS 原生 SDK **没有**内置缩放按钮与比例尺
  （Android 的 scalebar/zoom_buttons 是 XML 布局组件，native-view 代码建 View 场景不可用；
  UiSettings 仅有手势与 compass/logo/attribution 开关）
- 天地图服务条款要求在地图显著位置（官方参考左下角）标注"天地图"标识与审图号，
  未标注将被暂停调用（来源：tianditu.gov.cn/about/copyright、yunnan.tianditu.gov.cn 公告）
- MapLibre 原生 attribution 显示的是 MapLibre/OSM 版权，**不能满足**天地图合规要求

**方案**：原生优先 + uvue 兜底（用户已选定）。
鸿蒙/Web 使用各自 SDK 原生控件；Android/iOS 用 uvue 层补齐缺失的缩放按钮与比例尺；
版权条四端统一 uvue 层渲染（合规必需，无原生替代）。

## 2. 范围

### 2.1 本期做

- 缩放按钮：Android/iOS（uvue 层）、鸿蒙（原生 zoomControlsEnabled）、Web（原生 NavigationControl）
- 比例尺：Android/iOS（uvue 层公式计算）、鸿蒙（原生 scaleControlsEnabled）、Web（原生 ScaleControl）
- 版权条：四端统一 uvue 层渲染，文本可自定义
- 4 个新 props、2 个 TDMapOptions 可选字段
- 版本 1.6.0、README 更新、四副本同步

### 2.2 本期不做（YAGNI）

- 标记聚合、热力图、折线测距、图片覆盖物、鹰眼、地图类型控件、动态样式（后续版本）
- 指南针控件、缩放级别数字显示
- 地图初始化后动态切换 showZoomControl/showScaleControl 在鸿蒙/Web 原生端的即时生效
  （原生控件为 initMap 一次性配置；Android/iOS 的 uvue 控件天然响应式支持）

## 3. API 设计

### 3.1 tdt-map.uvue 新增 props（4 个）

| Prop | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `showZoomControl` | Boolean | `true` | 缩放按钮显隐（鸿蒙/Web 原生端仅初始化生效） |
| `showScaleControl` | Boolean | `true` | 比例尺显隐（鸿蒙/Web 原生端仅初始化生效） |
| `showCopyrightControl` | Boolean | `true` | 版权条显隐（天地图合规要求，默认开启；四端响应式） |
| `copyrightText` | String | `'© 天地图'` | 版权条文本。**合规提示：建议填入你的天地图审图号**，如"© 天地图 GS(2025)xxx号"（审图号随 Key 申请获得，插件无法预知，需用户填写） |

### 3.2 interface.uts TDMapOptions 新增可选字段（2 个）

```ts
export type TDMapOptions = {
    // ... 现有字段不变
    // v1.6.0: 控件显隐（仅鸿蒙/Web 原生层初始化时读取；Android/iOS 忽略，由 uvue 层响应式控制）
    showZoomControl?: boolean
    showScaleControl?: boolean
}
```

## 4. 各端实现分工

| 控件 | Android | iOS | 鸿蒙 | Web |
|---|---|---|---|---|
| 缩放按钮 | uvue 层（调 zoomIn/zoomOut） | uvue 层 | 原生 `zoomControlsEnabled` | 原生 `NavigationControl({showCompass:false})` |
| 比例尺 | uvue 层（公式计算） | uvue 层 | 原生 `scaleControlsEnabled` | 原生 `ScaleControl` |
| 版权条 | uvue 统一 | uvue 统一 | uvue 统一 | uvue 统一 |

### 4.1 鸿蒙 initMap（app-harmony/index.uts）

- MapOptions 中按 `options.showZoomControl`（默认 true）设 `zoomControlsEnabled`、
  按 `options.showScaleControl`（默认 true）设 `scaleControlsEnabled`
  （注意：华为 MapKit 的 `scaleControlsEnabled` 默认 false，与插件 props 默认 true 不一致，
  需显式按 `options.showScaleControl !== false` 设置）
- 审图号：不使用原生审图号能力（华为审图号为华为地图内容，与天地图无关，避免混淆）；
  若默认开启需显式 `setApproveNumberEnabled(false)`（实施时验证默认值与 API 可用性）
- **华为 logo 避让**：MapKit 默认显示华为 logo（左下角，无禁用 API），
  用 `setLogoAlignment` 将其移到右上角（TOP_END），避免与左下角 uvue 版权条重叠

### 4.2 Web initMap（web/index.uts）

- 现有代码已设 `attributionControl: false`（L218），继续保留（文档在此处显式声明该现状）
- `options.showZoomControl !== false` 时 `map.addControl(new NavigationControl({ showCompass: false }), 'bottom-right')`
- `options.showScaleControl !== false` 时 `map.addControl(new ScaleControl({ maxWidth: 100 }), 'bottom-right')`
- 同位置（bottom-right）多控件由 MapLibre GL JS 自动堆叠排列，不重叠
- **隐藏 MapLibre 原生 logo**：GL JS 无官方 logoEnabled 选项（仅有 logoPosition 移位），
  需在 initMap 后注入 CSS 隐藏：`.maplibregl-ctrl-logo { display: none }`
  （logo 默认左下角，会与 uvue 版权条重叠；MapLibre BSD-3 许可不强制显示）
- **幂等防御**：initMap 可能被多次调用（组件重建），新增的控件实例记录挂在
  **现有模块级单例 mapInstance 上**（与现有架构一致，不另立全局变量），
  重复初始化时先 removeControl 或跳过 addControl

### 4.3 Android initMap

- 两个新字段（showZoomControl/showScaleControl）忽略（uvue 层响应式控制）
- **新增：隐藏 MapLibre 原生 logo 与 attribution**：
  - `uiSettings.setLogoEnabled(false)`、`uiSettings.setAttributionEnabled(false)`
  - 原因：MapLibre 默认显示 logo（左下）与 attribution ℹ 按钮（显示"© MapLibre"版权），
    会与 uvue 版权条（左下）重叠，且 MapLibre 版权对天地图场景是错误信息；
    版权统一由 uvue 版权条承担
  - 合规性：MapLibre 为 BSD-3 许可，不强制显示 logo；天地图瓦片不含 OSM 数据，无 attribution 义务

### 4.4 iOS initMap

- 两个新字段忽略
- **新增：隐藏 MapLibre 原生 logo 与 attribution button**（MLNMapView 的 logoView/attributionButton），
  原因与合规性同 4.3（具体 API 名实施时 context7 验证后使用）

### 4.5 基座影响说明

- Android/iOS 因隐藏原生 logo/attribution 需修改 index.uts → **必须重新打自定义基座**才能真机验证
- 鸿蒙/Web 端的 index.uts 改动（控件开关）同样属 UTS 原生层 → 也需重新打包（鸿蒙本地打包 / Web 标准运行即可）

## 5. uvue 层实现细节

### 5.1 缩放按钮组（条件编译 APP-ANDROID || APP-IOS）

- 模板：`<!-- #ifdef APP-ANDROID || APP-IOS -->` 包裹，右侧垂直双按钮（+ 上 / − 下）
- 位置：右侧中部（bottom 约 45%），白色底、圆角、阴影，尺寸 36×36 css px，
  风格与现有定位按钮（tdt-locate-btn）一致
- 行为：点击调 `zoomIn()` / `zoomOut()`（现有 API，SDK 自动钳制到 min/max zoom）
- 不做按钮置灰状态（min/max zoom 由用户在业务层通过 setMinZoom/setMaxZoom 设定，
  组件不感知，SDK 钳制已保证行为正确）

### 5.2 比例尺（条件编译 APP-ANDROID || APP-IOS）

- 模板：`<!-- #ifdef APP-ANDROID || APP-IOS -->` 包裹，左下角（版权条上方）
- 精度说明：tilt=0 时公式精确；tilt≠0 时按屏幕中心纬度近似（与高德/百度等主流地图行为一致，文档注明）
- 算法（OSM Wiki "Zoom levels" 标准 ground resolution，天地图为标准 256px 瓦片 Web Mercator）：

```
米/像素 = 156543.03 × cos(lat) / 2^zoom
```

- 取整规则：从 `[1, 2, 5] × 10ⁿ` 米系列中取"像素宽 ≤ 100px"的最大值，
  显示文本如 "2km" / "500m" / "200m"
- 重算时机：`cameraChange` 事件 + `mapReady`（初始化）；数据源 `getCenter()`（取纬度）+ `getZoom()`
- 样式：两端刻度线 + 横线 + 右侧距离文字，白底半透明小圆角条

### 5.3 版权条（四端统一，无条件编译）

- 模板：直接渲染（v-if="showCopyrightControl"），左下角最底部
- 内容：`copyrightText`；小字号（11 css px 左右）、半透明白底深字
- 天地图合规位置参考：在线地图左下角样式（tianditu.gov.cn）

## 6. 布局避让

| 端 | 避让处理 |
|---|---|
| Android/iOS | uvue 比例尺 bottom≈26px（版权条高约 18px 之上）；版权条 bottom≈4px；缩放按钮右侧中部不与定位按钮（右下）重叠 |
| Web | 版权条左下独占；原生缩放+比例尺右下自动堆叠；uvue 定位按钮（现有 bottom:180rpx≈90px）Web 端 bottom 偏移按实测校准（原生控件堆高约 80~95px，初值 200rpx） |
| 鸿蒙 | 原生缩放按钮默认右下 → uvue 定位按钮 bottom 偏移按实测校准（初值 200rpx）；原生比例尺为华为默认位置 |

**z-index 规范**（现有气泡/搜索框/定位按钮为 95~100）：

- 版权条 z-index: 90（最低，不得遮挡气泡）
- 比例尺 z-index: 91
- 缩放按钮 z-index: 93（低于现有控件但高于版权/比例尺，防止意外被盖）

## 7. 版本与文档

- 版本 1.5.8 → 1.6.0：四份 package.json 顶层 version + tmp-publish/tdt-app 的 5 处 extVersion
- README 更新：
  - 功能概览表补"内置控件（缩放按钮/比例尺/版权条）"
  - 属性表补 4 个新 props
  - 版本历史新增 v1.6.0 章节（含"动态切换限制"说明：showZoomControl/showScaleControl
    在鸿蒙/Web 原生端为初始化一次性配置；Android/iOS uvue 控件与 copyrightText/showCopyrightControl 天然响应式）
- tmp-publish/changelog.md 补 v1.6.0 条目
- 同步四副本：uni_modules（主）/ example-project / tmp-publish / C 盘 tdt-app
  （注意：同步时跳过 C 盘 config.uts——含用户真实 Key，禁止覆盖）

## 8. 测试计划

| 端 | 验证点 |
|---|---|
| Android | uvue 缩放按钮显示与 ± 功能；比例尺随缩放档位变化（北京 zoom 10 应显示约 **10km** 档，zoom 13 约 1km 档）；版权条显示"© 天地图"；三控件与搜索框/定位按钮/气泡无重叠 |
| iOS | 同上（真机或模拟器） |
| 鸿蒙 | 原生缩放按钮/比例尺显示；华为 logo 已移位右上；审图号关闭；版权条显示；定位按钮已上移避让原生缩放按钮 |
| Web | NavigationControl+ScaleControl 右下堆叠；MapLibre 原生 logo 已隐藏；版权条左下；定位按钮避让；无搜索框重叠 |
| 全端 | `showZoomControl=false` / `showScaleControl=false` / `showCopyrightControl=false` 各开关场景；`copyrightText` 自定义 |

验证方式：Web 端 HBuilderX 运行即验证（改 web/index.uts 后需重新编译运行）；
鸿蒙本地打包验证；Android/iOS 因修改 index.uts（隐藏原生 logo/attribution + 忽略新字段）
**必须重新制作自定义基座**后真机验证（config.json 依赖不变，云端打包一次即可）。

## 9. 假设

- 天地图瓦片为标准 256px 瓦片 Web Mercator 投影（与现有气泡换算一致）
- 鸿蒙 MapKit `scaleControlsEnabled` / `zoomControlsEnabled` 属性在当前鸿蒙 SDK 版本可用
  （华为官方文档已确认存在；实现时按实际编译反馈调整）
- MapLibre GL JS 同位置 addControl 自动堆叠行为（官方文档确认）
