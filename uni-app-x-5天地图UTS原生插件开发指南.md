# uni-app x 蒸汽模式：天地图 UTS 原生插件开发指南

> **适用版本**：HBuilderX 4.31+（UTS 组件插件支持）  
> **开发模式**：uni-app x 蒸汽模式（Steam Mode）  
> **集成方式**：UTS 原生插件 + 各平台原生地图引擎 + 天地图 WMTS 瓦片  
> **目标平台**：Android / iOS / 鸿蒙  
> **渲染方式**：GPU 原生渲染（各平台原生引擎）

---

## 目录

1. [概述](#概述)
2. [方案对比](#方案对比)
3. [准备工作](#准备工作)
4. [方案 A：UTS + MapLibre（Android / iOS）](#方案-auts--maplibreadroid--ios)
5. [方案 B：UTS + 华为 MapKit TileOverlay（鸿蒙）](#方案-buts--华为-mapkit-tileoverlay鸿蒙)
6. [方案 C：web-view + 天地图 JS API（全平台备选）](#方案-cweb-view--天地图-js-api全平台备选)
7. [权限配置](#权限配置)
8. [集成测试与调试指南](#集成测试与调试指南)
9. [注意事项](#注意事项)
10. [常见问题排查](#常见问题排查)

---

## 概述

### UTS 原生插件在蒸汽模式下完全可用

经核实，uni-app x 蒸汽模式**完全支持 UTS 原生插件开发**。官方文档中的"原生 SDK 不支持蒸汽模式"指的是将 uni-app x 页面嵌入现有原生工程的场景，与 UTS 插件开发无关。UTS 语言在蒸汽模式下的主要用途就是开发原生插件，通过 `native-view` 组件嵌入原生 UI，实现 GPU 渲染。

> 注意：本文档演示的是 UTS**标准模式**（模块级）插件。uni-app 兼容模式组件（旧称"组件插件"）在蒸汽模式下不被支持，开发时务必确认使用标准模式。 [\$TRAE_REF](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-component.html)

### 技术路线

```
┌──────────────────────────────────────────────────────┐
│  方案 A：UTS + MapLibre（Android / iOS，推荐）         │
│  UTS → native-view → MapLibre MapView                │
│  → 加载天地图 WMTS → GPU 渲染（OpenGL ES / Metal）     │
├──────────────────────────────────────────────────────┤
│  方案 B：UTS + 华为 MapKit（鸿蒙，推荐）               │
│  UTS → native-view → MapKit TileOverlay               │
│  → 叠加天地图瓦片 → 鸿蒙原生 GPU 渲染                  │
├──────────────────────────────────────────────────────┤
│  方案 C：web-view + 天地图 JS API（全平台备选）        │
│  web-view → HTML → 天地图 JS API 4.0                  │
│  → WebView Canvas 渲染，效果接近原生                   │
└──────────────────────────────────────────────────────┘
```

### 各平台引擎选择

| 平台 | 引擎 | 渲染 | 成熟度 |
|------|------|------|--------|
| Android | MapLibre GL Native 11.0+ | OpenGL ES | 生产可用，社区活跃 |
| iOS | MapLibre GL Native 6.5+ | Metal | 生产可用，社区活跃 |
| 鸿蒙 | 华为 MapKit TileOverlay（5.0.3+） | 鸿蒙原生 GPU | 生产可用，华为官方维护 |

> 鸿蒙端 MapLibre 存在 Alpha 移植版（`maplibre-harmony` 0.1.0-alpha.12），但因稳定性问题不推荐生产使用。华为 MapKit 是鸿蒙官方地图组件，`TileOverlay` 从 5.0.3(15) 起原生支持自定义瓦片叠加，功能完善、性能稳定。 [$TRAE_REF](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/map-tile)

---

## 方案对比

| 维度 | 方案 A：UTS + MapLibre | 方案 B：UTS + MapKit | 方案 C：web-view + JS API |
|------|------|------|------|
| **目标平台** | Android + iOS | 鸿蒙 (HarmonyOS) | Android + iOS + 鸿蒙 + Web |
| **插件类型** | UTS 原生插件 | UTS 原生插件 | uni_modules 组件插件 |
| **渲染引擎** | MapLibre GL Native | 华为 MapKit TileOverlay | 天地图 JS API 4.0 |
| **渲染方式** | GPU 原生渲染 | 鸿蒙原生 GPU 渲染 | WebView Canvas 渲染 |
| **地图浏览流畅度** | 丝滑 | 丝滑 | 流畅，接近原生 |
| **大量标注（100+）** | 无压力 | 无压力 | 可能轻微卡顿 |
| **离线地图** | 支持原生瓦片缓存 | 支持磁盘缓存 | 需 Service Worker |
| **开发复杂度** | 较高 | 中等 | 较低 |
| **需要云打包** | 是（云打包） | 否（本地打包） | 否 |
| **依赖** | MapLibre SDK (~8MB) | 华为 MapKit（系统内置） | 无 |
| **坐标系统** | WGS84 / GCJ02 | WGS84 / GCJ02 | 取决于 JS API |
| **插件商城分类** | "UTS 原生插件" | "UTS 原生插件" | "组件插件" |

---

## 准备工作

### 1. 注册天地图开发者并获取 Key

前往 [天地图开发者中心](http://lbs.tianditu.gov.cn/) 注册并申请 Key。一个 Key 可用于全部 API（WMTS 瓦片、JS API、Web 服务 API）。

### 2. 填写 API Key

有三种方式配置 Key，优先级从高到低：

**方式一：组件 props（推荐，最灵活）**

```vue
<tdt-map api-key="你的天地图Key" />
```

**方式二：config.js 全局配置**

打开 `uni_modules/tdt-map/config.js`，填入你的 Key：

```js
export default {
  apiKey: '你的天地图Key'
}
```

**方式三：manifest.json 源码视图（多环境配置）**

虽然 HBuilderX 可视化配置不支持第三方 UTS 插件，但可以通过源码视图配置：

```json
// manifest.json 源码视图
{
  "app": {
    "distribute": {
      "tdt-map": {
        "apiKey": "你的天地图Key"
      }
    }
  }
}
```

在 `config.js` 中读取 manifest.json 作为 fallback：

```js
// config.js
let manifestApiKey = ''
try {
  // 读取 manifest.json 中的 tdt-map 配置
  const manifest = require('@/manifest.json')
  manifestApiKey = manifest?.app?.distribute?.['tdt-map']?.apiKey || ''
} catch (e) {}

export default {
  apiKey: manifestApiKey || '你的天地图Key'
}
```

组件 props 传入 `api-key` 的优先级最高，适合多 Key 场景。

### 3. 环境要求

| 项目 | 版本要求 |
|------|---------|
| HBuilderX | 4.31+（UTS 组件插件支持） |
| uni-app x | 蒸汽模式（Steam Mode） |
| MapLibre Android | 11.0.0+ |
| MapLibre iOS | 6.0.0+ |

### 4. 目录结构

```
uni_modules/tdt-map/
├── package.json
├── config.js                         # 全局配置（填 Key）
├── utssdk/
│   ├── interface.uts                 # 跨平台接口声明
│   ├── app-android/
│   │   ├── index.uts                 # Android：MapLibre + 天地图 WMTS
│   │   └── config.json               # Android 依赖配置
│   ├── app-ios/
│   │   ├── index.uts                 # iOS：MapLibre + 天地图 WMTS
│   │   └── config.json               # iOS 依赖配置
│   └── app-harmony/
│       ├── index.uts                 # 鸿蒙：华为 MapKit TileOverlay
│       ├── builder.ets               # 鸿蒙混编：MapComponent 声明式构建函数
│       └── config.json               # 鸿蒙原生配置文件
├── components/
│   └── tdt-map.uvue                  # native-view 封装组件
└── static/
    └── tdt-map.html                  # 仅方案 C 使用
```

---

## 方案 A：UTS + MapLibre（Android / iOS）

### 跨平台接口声明

`utssdk/interface.uts`：

```uts
export type TDMapOptions = {
    apiKey: string
    latitude: number
    longitude: number
    zoom: number
    mapType: string   // 'vec' | 'img' | 'ter'  矢量/影像/地形
}

export type MapClickDetail = {
    lat: number
    lng: number
}

export type MapErrorDetail = {
    code: number       // 错误码：1=Key无效, 2=网络错误, 3=瓦片加载失败, 4=未知错误
    message: string
}

export type MapClickCallback = (detail: MapClickDetail) => void
export type MapReadyCallback = () => void
export type MapErrorCallback = (detail: MapErrorDetail) => void

// 模块级函数
// 注意：initMap 接收 UniNativeViewElement 是 UTS 模块级插件（非组件插件）的标准模式。
// 组件通过 <native-view @init="onNativeViewInit"> 获取 UniNativeViewElement，
// 再传递给各平台实现的 initMap 函数：
// - Android 调用 bindAndroidView 绑定原生 View
// - iOS 调用 bindIOSView 绑定原生 UIView
// - 鸿蒙调用 bindHarmonyWrappedBuilder 绑定 MapComponent 声明式组件（官方不提供 getHarmonyView 类 API）
export declare function initMap(
    container: UniNativeViewElement,
    options: TDMapOptions,
    onClick: MapClickCallback,
    onReady: MapReadyCallback,
    onError: MapErrorCallback
): void
export declare function setCenter(lat: number, lng: number): void
export declare function setZoom(zoom: number): void
export declare function getCenter(): MapClickDetail
export declare function getZoom(): number
export declare function fitBounds(minLat: number, minLng: number, maxLat: number, maxLng: number, padding: number): void
export declare function addMarker(lat: number, lng: number, title: string): void
export declare function clearMarkers(): void
export declare function addPolygon(points: Array<MapClickDetail>, color: string, fillColor: string): void
export declare function clearPolygons(): void
export declare function switchMapType(mapType: string): void
export declare function snapshot(): ArrayBuffer  // 返回地图截图 PNG 数据
export declare function onResume(): void
export declare function onPause(): void
export declare function destroyMap(): void
```

### Android 实现

`utssdk/app-android/index.uts`：

```uts
import { Context } from "android.content"
import { MapView, MapLibreMap } from "org.maplibre.android.maps"
import { Style } from "org.maplibre.android.maps"
import { TileSet, RasterSource } from "org.maplibre.android.style.sources"
import { RasterLayer, Property, PropertyFactory } from "org.maplibre.android.style.layers"
import { CameraPosition, LatLng, CameraUpdateFactory } from "org.maplibre.android.camera"
import { LatLngBounds } from "org.maplibre.android.geometry"
import { MarkerOptions, PolygonOptions } from "org.maplibre.android.annotations"
import {
    TDMapOptions, MapClickDetail, MapErrorDetail,
    MapClickCallback, MapReadyCallback, MapErrorCallback
} from '../interface.uts'

let mapView: MapView | null = null
let mapLibreMap: MapLibreMap | null = null
let onClickCallback: MapClickCallback | null = null
let onReadyCallback: MapReadyCallback | null = null
let onErrorCallback: MapErrorCallback | null = null
let markers: Array<any> = []
let polygons: Array<any> = []
let currentApiKey: string = ''
let currentMapType: string = 'vec'

// 预创建所有图层引用，用于 visibility 切换优化
let allLayerSources: Array<any> = []
let allLayerLayers: Array<any> = []

// 天地图 WMTS URL 模板（全部使用 https://）
const TDT_URLS: Record<string, string> = {
    vec: 'https://t{0-7}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    cva: 'https://t{0-7}.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    img: 'https://t{0-7}.tianditu.gov.cn/img_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=img&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    cia: 'https://t{0-7}.tianditu.gov.cn/cia_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cia&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    ter: 'https://t{0-7}.tianditu.gov.cn/ter_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=ter&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    cta: 'https://t{0-7}.tianditu.gov.cn/cta_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cta&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk='
}

export function initMap(
    container: UniNativeViewElement,
    options: TDMapOptions,
    onClick: MapClickCallback,
    onReady: MapReadyCallback,
    onError: MapErrorCallback
): void {
    const context = container.getAndroidActivity() as Context
    if (context == null) {
        console.error("TDTMap: 获取 Android Context 失败")
        onError({ code: 4, message: "获取 Android Context 失败" })
        return
    }

    // 检查 Key 是否为空
    if (options.apiKey == null || options.apiKey.length == 0) {
        console.error("TDTMap: apiKey 为空")
        onError({ code: 1, message: "apiKey 为空" })
        return
    }

    onClickCallback = onClick
    onReadyCallback = onReady
    onErrorCallback = onError
    currentApiKey = options.apiKey
    currentMapType = options.mapType

    mapView = new MapView(context)
    container.bindAndroidView(mapView)

    mapView.onCreate(null)
    mapView.getMapAsync((map: MapLibreMap) => {
        mapLibreMap = map

        // 预创建所有三种地图类型的图层（vec、img、ter），通过 visibility 控制显隐
        // 当前激活的地图类型设置为 VISIBLE，其余设置为 NONE
        addTiandituTileLayer(map, "vec", options.apiKey,
            options.mapType == "vec" ? Property.VISIBLE : Property.NONE)
        addTiandituTileLayer(map, "img", options.apiKey,
            options.mapType == "img" ? Property.VISIBLE : Property.NONE)
        addTiandituTileLayer(map, "ter", options.apiKey,
            options.mapType == "ter" ? Property.VISIBLE : Property.NONE)

        // 设置初始视角
        val center = new LatLng(options.latitude, options.longitude)
        map.setCameraPosition(
            new CameraPosition.Builder()
                .target(center)
                .zoom(options.zoom.toDouble())
                .build()
        )

        // 地图点击事件
        map.addOnMapClickListener((point: LatLng) => {
            if (onClickCallback != null) {
                onClickCallback({
                    lat: point.getLatitude(),
                    lng: point.getLongitude()
                })
            }
            return true
        })

        if (onReadyCallback != null) {
            onReadyCallback()
        }
    })
}

// 添加天地图瓦片图层
// visibility: Property.VISIBLE 或 Property.NONE，用于预创建时控制显隐
function addTiandituTileLayer(map: MapLibreMap, mapType: string, apiKey: string, visibility: string): void {
    try {
        let baseLayer: string
        let labelLayer: string

        switch (mapType) {
            case 'img':
                baseLayer = 'img'
                labelLayer = 'cia'
                break
            case 'ter':
                baseLayer = 'ter'
                labelLayer = 'cta'
                break
            default: // 'vec'
                baseLayer = 'vec'
                labelLayer = 'cva'
                break
        }

        val baseSourceId = "tdt-base-" + mapType
        val labelSourceId = "tdt-label-" + mapType
        val baseLayerId = "tdt-base-layer-" + mapType
        val labelLayerId = "tdt-label-layer-" + mapType

        val style = map.getStyle()
        if (style == null) {
            console.error("TDTMap: Style 未加载，无法添加 " + mapType + " 图层")
            if (onErrorCallback != null) {
                onErrorCallback({ code: 3, message: "Style 未加载，无法添加 " + mapType + " 图层" })
            }
            return
        }

        // 底图
        val baseTileSet = new TileSet("2.1.0", TDT_URLS[baseLayer] + apiKey)
        val baseSource = new RasterSource(baseSourceId, baseTileSet, 256)
        style.addSource(baseSource)
        allLayerSources.push(baseSource)

        val baseRasterLayer = new RasterLayer(baseLayerId, baseSourceId)
        baseRasterLayer.setProperties(PropertyFactory.visibility(visibility))
        style.addLayer(baseRasterLayer)
        allLayerLayers.push(baseRasterLayer)

        // 注记（叠加在底图之上）
        val labelTileSet = new TileSet("2.1.0", TDT_URLS[labelLayer] + apiKey)
        val labelSource = new RasterSource(labelSourceId, labelTileSet, 256)
        style.addSource(labelSource)
        allLayerSources.push(labelSource)

        val labelRasterLayer = new RasterLayer(labelLayerId, labelSourceId)
        labelRasterLayer.setProperties(PropertyFactory.visibility(visibility))
        style.addLayer(labelRasterLayer)
        allLayerLayers.push(labelRasterLayer)
    } catch (e: Exception) {
        console.error("TDTMap: 添加天地图瓦片失败 (" + mapType + "): " + e.getMessage())
        if (onErrorCallback != null) {
            onErrorCallback({ code: 3, message: "瓦片加载失败 (" + mapType + "): " + e.getMessage() })
        }
    }
}

// 地图类型切换：通过 visibility 切换显隐，无需移除/重建图层，消除闪烁
export function switchMapType(mapType: string): void {
    if (mapLibreMap == null) return
    currentMapType = mapType
    for (let i = 0; i < allLayerLayers.length; i++) {
        val layer = allLayerLayers[i]
        val id = layer.getId()
        if (id == "tdt-base-layer-" + mapType || id == "tdt-label-layer-" + mapType) {
            layer.setProperties(PropertyFactory.visibility(Property.VISIBLE))
        } else {
            layer.setProperties(PropertyFactory.visibility(Property.NONE))
        }
    }
}

export function setCenter(lat: number, lng: number): void {
    if (mapLibreMap != null) {
        val center = new LatLng(lat, lng)
        mapLibreMap.setCameraPosition(
            new CameraPosition.Builder()
                .target(center)
                .build()
        )
    }
}

export function setZoom(zoom: number): void {
    if (mapLibreMap != null) {
        mapLibreMap.setCameraPosition(
            new CameraPosition.Builder()
                .zoom(zoom.toDouble())
                .build()
        )
    }
}

export function getCenter(): MapClickDetail {
    if (mapLibreMap != null) {
        val target = mapLibreMap.getCameraPosition()?.target
        if (target != null) {
            return { lat: target.getLatitude(), lng: target.getLongitude() }
        }
    }
    return { lat: 0, lng: 0 }
}

export function getZoom(): number {
    if (mapLibreMap != null) {
        val zoom = mapLibreMap.getCameraPosition()?.zoom
        if (zoom != null) return zoom.toFloat()
    }
    return 0
}

export function fitBounds(minLat: number, minLng: number, maxLat: number, maxLng: number, padding: number): void {
    if (mapLibreMap == null) return
    try {
        val southwest = new LatLng(minLat, minLng)
        val northeast = new LatLng(maxLat, maxLng)
        val bounds = new LatLngBounds.Builder()
            .include(southwest)
            .include(northeast)
            .build()
        val cameraUpdate = CameraUpdateFactory.newLatLngBounds(bounds, padding.toInt())
        mapLibreMap!!.moveCamera(cameraUpdate)
    } catch (e: Exception) {
        console.error("TDTMap: fitBounds 失败: " + e.getMessage())
        if (onErrorCallback != null) {
            onErrorCallback({ code: 4, message: "fitBounds 失败: " + e.getMessage() })
        }
    }
}

export function addMarker(lat: number, lng: number, title: string): void {
    if (mapLibreMap != null) {
        val marker = new MarkerOptions()
            .position(new LatLng(lat, lng))
            .title(title)
        val m = mapLibreMap.addMarker(marker)
        markers.push(m)
    }
}

export function clearMarkers(): void {
    if (mapLibreMap != null) {
        for (let i = 0; i < markers.length; i++) {
            mapLibreMap.removeMarker(markers[i])
        }
        markers = []
    }
}

export function addPolygon(points: Array<MapClickDetail>, color: string, fillColor: string): void {
    if (mapLibreMap == null) return
    try {
        val opts = new PolygonOptions()
        for (let i = 0; i < points.length; i++) {
            opts.add(new LatLng(points[i].lat, points[i].lng))
        }
        val strokeColorInt = android.graphics.Color.parseColor(color)
        val fillColorInt = android.graphics.Color.parseColor(fillColor)
        opts.strokeColor(strokeColorInt)
        opts.fillColor(fillColorInt)
        val polygon = mapLibreMap!!.addPolygon(opts)
        polygons.push(polygon)
    } catch (e: Exception) {
        console.error("TDTMap: 添加多边形失败: " + e.getMessage())
        if (onErrorCallback != null) {
            onErrorCallback({ code: 4, message: "添加多边形失败: " + e.getMessage() })
        }
    }
}

export function clearPolygons(): void {
    if (mapLibreMap == null) return
    for (let i = 0; i < polygons.length; i++) {
        mapLibreMap!!.removePolygon(polygons[i])
    }
    polygons = []
}

// 地图截图：通过 MapLibre snapshot API 获取 Bitmap 并转为 PNG ArrayBuffer
export function snapshot(): ArrayBuffer {
    if (mapLibreMap == null) {
        if (onErrorCallback != null) {
            onErrorCallback({ code: 4, message: "Map 未初始化" })
        }
        return new ArrayBuffer(0)
    }
    try {
        val latch = new java.util.concurrent.CountDownLatch(1)
        var resultBytes: ByteArray | null = null
        mapLibreMap!!.snapshot((bitmap: android.graphics.Bitmap) => {
            val stream = new java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
            resultBytes = stream.toByteArray()
            stream.close()
            latch.countDown()
        })
        latch.await()
        if (resultBytes != null) return resultBytes!!
    } catch (e: Exception) {
        console.error("TDTMap: snapshot 失败: " + e.getMessage())
        if (onErrorCallback != null) {
            onErrorCallback({ code: 4, message: "Snapshot 失败: " + e.getMessage() })
        }
    }
    return new ArrayBuffer(0)
}

export function onResume(): void {
    if (mapView != null) { mapView.onResume() }
}

export function onPause(): void {
    if (mapView != null) { mapView.onPause() }
}

export function destroyMap(): void {
    if (mapView != null) {
        mapView.onDestroy()
        mapView = null
        mapLibreMap = null
        onClickCallback = null
        onReadyCallback = null
        onErrorCallback = null
        markers = []
        polygons = []
        allLayerSources = []
        allLayerLayers = []
    }
}
```

`utssdk/app-android/config.json`：

```json
{
    "abis": ["arm64-v8a"],
    "dependencies": [
        {
            "id": "maplibre-android-sdk",
            "source": "implementation 'org.maplibre.gl:android-sdk:11.0.1'"
        }
    ],
    "minSdkVersion": 21
}
```

### iOS 实现

`utssdk/app-ios/index.uts`：

```uts
import { MLNMapView, MLNStyle, MLNMapViewDelegate } from "MapLibre"
import { MLNRasterTileSource } from "MapLibre"
import { MLNRasterStyleLayer } from "MapLibre"
import { MLNPointAnnotation } from "MapLibre"
import { MLNPolygon } from "MapLibre"
import { MLNFillStyleLayer } from "MapLibre"
import { MLNShapeSource } from "MapLibre"
import { MLNCoordinateBoundsMake } from "MapLibre"
import { CLLocationCoordinate2DMake } from "CoreLocation"
import { UITapGestureRecognizer, UIColor } from "UIKit"
import { UIEdgeInsets } from "UIKit"
import { NSURL, NSExpression } from "Foundation"
import { TDMapOptions, MapClickDetail, MapClickCallback, MapReadyCallback, MapErrorCallback } from '../interface.uts'

let mapView: MLNMapView | null = null
let onClickCallback: MapClickCallback | null = null
let onReadyCallback: MapReadyCallback | null = null
let onErrorCallback: MapErrorCallback | null = null
let currentApiKey: string = ''
let currentMapType: string = 'vec'
let polygons: Array<any> = []

// 天地图 WMTS URL 模板
const TDT_URLS: Record<string, string> = {
    vec: 'https://t{0-7}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    cva: 'https://t{0-7}.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    img: 'https://t{0-7}.tianditu.gov.cn/img_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=img&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    cia: 'https://t{0-7}.tianditu.gov.cn/cia_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cia&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    ter: 'https://t{0-7}.tianditu.gov.cn/ter_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=ter&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
    cta: 'https://t{0-7}.tianditu.gov.cn/cta_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cta&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk='
}

// 空白底图样式：MapLibre iOS 官方要求 MLNMapView 必须持有 style 才能添加 Source/Layer，
// 天地图瓦片本身即底图内容，因此底图样式只提供空画布即可
const TDT_EMPTY_STYLE_URL = 'https://demotiles.maplibre.org/style.json'

// 样式加载完成代理：Source/Layer 必须等样式加载完成后添加（MapLibre iOS 官方约束）
class TDTMapDelegate implements MLNMapViewDelegate {
    private opts: TDMapOptions

    constructor(opts: TDMapOptions) {
        this.opts = opts
    }

    @objc mapViewDidFinishLoadingStyle(mapView: MLNMapView, style: MLNStyle): void {
        // 预创建所有图层对（vec/img/ter），非活跃图层设为不可见
        addTiandituTileLayer(mapView, 'vec', this.opts.apiKey, this.opts.mapType == 'vec' ? 'visible' : 'none')
        addTiandituTileLayer(mapView, 'img', this.opts.apiKey, this.opts.mapType == 'img' ? 'visible' : 'none')
        addTiandituTileLayer(mapView, 'ter', this.opts.apiKey, this.opts.mapType == 'ter' ? 'visible' : 'none')

        // 设置初始视角（CLLocationCoordinate2D 是 C 结构体，必须用 Make 函数构造，不能 new）
        const center = CLLocationCoordinate2DMake(this.opts.latitude, this.opts.longitude)
        mapView.setCenterCoordinate(center, zoomLevel: this.opts.zoom, animated: false)

        if (onReadyCallback != null) {
            onReadyCallback()
        }
    }
}

export function initMap(
    container: UniNativeViewElement,
    options: TDMapOptions,
    onClick: MapClickCallback,
    onReady: MapReadyCallback,
    onError: MapErrorCallback
): void {
    // 检查 API Key 是否为空
    if (options.apiKey == null || options.apiKey.length == 0) {
        onError({ code: 1, message: "API Key 为空" })
        return
    }

    onClickCallback = onClick
    onReadyCallback = onReady
    onErrorCallback = onError
    currentApiKey = options.apiKey
    currentMapType = options.mapType

    const frame = container.bounds
    const styleURL = NSURL.URLWithString(TDT_EMPTY_STYLE_URL)!
    // 创建时必须指定 styleURL，否则 style 恒为 nil，图层永远无法添加（MapLibre iOS 官方用法）
    mapView = new MLNMapView(frame, styleURL)
    container.bindIOSView(mapView)

    // 设置代理，等样式加载完成后再添加瓦片图层并触发 onReady
    mapView.delegate = new TDTMapDelegate(options)

    // 添加手势识别器处理地图点击
    val tapGesture = new UITapGestureRecognizer((gesture: UITapGestureRecognizer) => {
        if (mapView != null && onClickCallback != null) {
            val point = gesture.locationInView(mapView)
            val coordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
            onClickCallback({
                lat: coordinate.latitude,
                lng: coordinate.longitude
            })
        }
    })
    tapGesture.cancelsTouchesInView = false
    mapView.addGestureRecognizer(tapGesture)
}

function addTiandituTileLayer(map: MLNMapView, mapType: string, apiKey: string, visibility: string): void {
    try {
        let baseLayer: string
        let labelLayer: string

        switch (mapType) {
            case 'img':
                baseLayer = 'img'
                labelLayer = 'cia'
                break
            case 'ter':
                baseLayer = 'ter'
                labelLayer = 'cta'
                break
            default:
                baseLayer = 'vec'
                labelLayer = 'cva'
                break
        }

        // 底图 - 使用带 mapType 后缀的 source/layer ID，避免不同类型冲突
        val baseTileURL = TDT_URLS[baseLayer] + apiKey
        val baseSourceId = "tdt-base-" + mapType
        val baseSource = new MLNRasterTileSource(identifier: baseSourceId, tileURLTemplates: [baseTileURL], options: null)
        map.style?.addSource(baseSource)
        val baseLayerId = "tdt-base-" + mapType + "-layer"
        val baseLayerObj = new MLNRasterStyleLayer(identifier: baseLayerId, source: baseSource)
        if (visibility == "none") {
            baseLayerObj.isVisible = false
        }
        map.style?.addLayer(baseLayerObj)

        // 注记
        val labelTileURL = TDT_URLS[labelLayer] + apiKey
        val labelSourceId = "tdt-label-" + mapType
        val labelSource = new MLNRasterTileSource(identifier: labelSourceId, tileURLTemplates: [labelTileURL], options: null)
        map.style?.addSource(labelSource)
        val labelLayerId = "tdt-label-" + mapType + "-layer"
        val labelLayerObj = new MLNRasterStyleLayer(identifier: labelLayerId, source: labelSource)
        if (visibility == "none") {
            labelLayerObj.isVisible = false
        }
        map.style?.addLayer(labelLayerObj)
    } catch (e) {
        if (onErrorCallback != null) {
            onErrorCallback({ code: 3, message: "瓦片加载失败: " + e.toString() })
        }
    }
}

export function setCenter(lat: number, lng: number): void {
    if (mapView != null) {
        // CLLocationCoordinate2D 是 C 结构体，必须用 Make 函数构造
        val center = CLLocationCoordinate2DMake(lat, lng)
        mapView.setCenterCoordinate(center, animated: true)
    }
}

export function setZoom(zoom: number): void {
    if (mapView != null) {
        mapView.setZoomLevel(zoom, animated: true)
    }
}

export function getCenter(): MapClickDetail {
    if (mapView != null) {
        val coordinate = mapView.centerCoordinate
        return { lat: coordinate.latitude, lng: coordinate.longitude }
    }
    return { lat: 0, lng: 0 }
}

export function getZoom(): number {
    if (mapView != null) {
        return mapView.zoomLevel
    }
    return 0
}

export function fitBounds(minLat: number, minLng: number, maxLat: number, maxLng: number, padding: number): void {
    if (mapView == null) return
    val sw = CLLocationCoordinate2DMake(minLat, minLng)
    val ne = CLLocationCoordinate2DMake(maxLat, maxLng)
    val bounds = MLNCoordinateBoundsMake(sw, ne)
    val edgePadding = new UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
    mapView.setVisibleCoordinateBounds(bounds, edgePadding: edgePadding, animated: true)
}

export function addMarker(lat: number, lng: number, title: string): void {
    if (mapView != null) {
        val annotation = new MLNPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2DMake(lat, lng)
        annotation.title = title
        mapView.addAnnotation(annotation)
    }
}

export function clearMarkers(): void {
    if (mapView != null && mapView.annotations != null) {
        mapView.removeAnnotations(mapView.annotations)
    }
}

// 将十六进制颜色字符串（如 '#FF0000' / '#FF000033'）转为 UIColor
function parseColor(color: string): UIColor {
    let hex = color
    if (hex.hasPrefix('#')) { hex = hex.substringFromIndex(1) }
    let r: number = 0, g: number = 0, b: number = 0, a: number = 255
    if (hex.length == 8) { // RRGGBBAA
        r = parseInt(hex.substring(0, 2), 16)
        g = parseInt(hex.substring(2, 4), 16)
        b = parseInt(hex.substring(4, 6), 16)
        a = parseInt(hex.substring(6, 8), 16)
    } else { // RRGGBB
        r = parseInt(hex.substring(0, 2), 16)
        g = parseInt(hex.substring(2, 4), 16)
        b = parseInt(hex.substring(4, 6), 16)
    }
    return UIColor.colorWithRed(r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a / 255.0)
}

export function addPolygon(points: Array<MapClickDetail>, color: string, fillColor: string): void {
    if (mapView == null || mapView.style == null) return
    var coordinates: Array<CLLocationCoordinate2D> = []
    for (var i = 0; i < points.length; i++) {
        coordinates.push(CLLocationCoordinate2DMake(points[i].lat, points[i].lng))
    }
    const polygonId = "tdt-polygon-" + polygons.length.toString()
    try {
        // MLNPolygon 作为 Feature 加入 MLNShapeSource；
        // MapLibre iOS 不存在 MLNPolygonStyleLayer，面填充必须使用 MLNFillStyleLayer（官方样式图层类）
        val polygon = MLNPolygon(coordinates, points.length)
        val source = new MLNShapeSource(identifier: polygonId, shape: polygon, options: null)
        mapView.style?.addSource(source)
        val layer = new MLNFillStyleLayer(identifier: polygonId + "-layer", source: source)
        // 通过属性表达式设置填充色与描边色
        layer.fillColor = NSExpression(forConstantValue: parseColor(fillColor))
        layer.fillOutlineColor = NSExpression(forConstantValue: parseColor(color))
        mapView.style?.addLayer(layer)
        polygons.push({ source: source, layer: layer })
    } catch (e) {
        if (onErrorCallback != null) {
            onErrorCallback({ code: 4, message: "添加多边形失败: " + e.toString() })
        }
    }
}

export function clearPolygons(): void {
    if (mapView == null) return
    for (let i = 0; i < polygons.length; i++) {
        mapView.style?.removeLayer(polygons[i].layer)
        mapView.style?.removeSource(polygons[i].source)
    }
    polygons = []
}

// 切换地图类型：通过 visibility 切换显隐，无需移除/重建图层，消除闪烁
export function switchMapType(mapType: string): void {
    if (mapView == null) return
    currentMapType = mapType
    ["vec", "img", "ter"].forEach(type => {
        const isVisible = type === mapType
        mapView.style?.layerWithIdentifier("tdt-base-" + type + "-layer")?.isVisible = isVisible
        mapView.style?.layerWithIdentifier("tdt-label-" + type + "-layer")?.isVisible = isVisible
    })
}

// iOS 端 MapLibre 快照
export function snapshot(): ArrayBuffer {
    if (mapView == null) {
        if (onErrorCallback != null) {
            onErrorCallback({ code: 4, message: "Map 未初始化" })
        }
        return new ArrayBuffer(0)
    }
    // MapLibre iOS 快照通过 UIImage 获取
    val renderer = UIGraphicsImageRenderer(size: mapView.bounds.size)
    val image = renderer.imageWithActions((context: UIGraphicsImageRendererContext) => {
        mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
    })
    val data = UIImagePNGRepresentation(image)
    if (data != null) {
        return data
    }
    return new ArrayBuffer(0)
}

export function onResume(): void {
    // iOS 端无需额外处理
}

export function onPause(): void {
    // iOS 端无需额外处理
}

export function destroyMap(): void {
    if (mapView != null) {
        mapView.removeFromSuperview()
        mapView = null
        onClickCallback = null
        onReadyCallback = null
        onErrorCallback = null
        polygons = []
    }
}
```

`utssdk/app-ios/config.json`（按官方 CocoaPods 依赖格式，实际工程中不得包含注释）：

```json
{
    "deploymentTarget": "12.0",
    "dependencies-pods": [
        {
            "name": "MapLibre",
            "version": "6.5.0"
        }
    ]
}
```

### 组件封装

`components/tdt-map.uvue`：

```vue
<template>
  <view class="tdt-map-wrapper">
    <native-view
      class="map-container"
      @init="onNativeViewInit"
    />
  </view>
</template>

<script setup lang="uts">
import { ref, onShow, onHide, onUnmounted } from 'vue'
import {
  initMap, setCenter, setZoom,
  addMarker, clearMarkers, switchMapType,
  onResume, onPause, destroyMap,
  getCenter, getZoom, fitBounds,
  addPolygon, clearPolygons, snapshot
} from '@/uni_modules/tdt-map'
import globalConfig from '@/uni_modules/tdt-map/config'
import type { MapClickDetail, MapErrorDetail } from '@/uni_modules/tdt-map'

const props = defineProps({
  apiKey: { type: String, default: '' },
  latitude: { type: Number, default: 39.9042 },
  longitude: { type: Number, default: 116.4075 },
  zoom: { type: Number, default: 10 },
  mapType: { type: String, default: 'vec' }
})

const emit = defineEmits<{
  (e: 'mapReady'): void
  (e: 'mapClick', detail: MapClickDetail): void
  (e: 'mapError', detail: MapErrorDetail): void
}>()

const isMapReady = ref(false)

const effectiveApiKey = computed(() => {
  if (props.apiKey != null && props.apiKey.length > 0) return props.apiKey
  return globalConfig.apiKey
})

function onNativeViewInit(e: UniNativeViewInitEvent): void {
  if (effectiveApiKey.value == null || effectiveApiKey.value.length == 0) {
    console.error('TDTMap: 未配置 API Key。请在 config.js 中填写或在组件上设置 api-key')
    return
  }

  initMap(
    e.detail.element,
    {
      apiKey: effectiveApiKey.value,
      latitude: props.latitude,
      longitude: props.longitude,
      zoom: props.zoom,
      mapType: props.mapType
    },
    (detail: MapClickDetail) => {
      emit('mapClick', detail)
    },
    () => {
      isMapReady.value = true
      emit('mapReady')
    },
    (error: MapErrorDetail) => {
      emit('mapError', error)
    }
  )
}

function moveToCenter(lat: number, lng: number): void { setCenter(lat, lng) }
function zoomTo(level: number): void { setZoom(level) }
function placeMarker(lat: number, lng: number, title: string): void { addMarker(lat, lng, title) }
function clearAllMarkers(): void { clearMarkers() }
function changeMapType(mapType: string): void { switchMapType(mapType) }
function getCurrentCenter(): MapClickDetail { return getCenter() }
function getCurrentZoom(): number { return getZoom() }
function fitToBounds(minLat: number, minLng: number, maxLat: number, maxLng: number, padding: number): void { fitBounds(minLat, minLng, maxLat, maxLng, padding) }
function drawPolygon(points: Array<{ latitude: number, longitude: number }>, color: string, fillColor: string): void { addPolygon(points, color, fillColor) }
function clearAllPolygons(): void { clearPolygons() }
function takeSnapshot(): ArrayBuffer { return snapshot() }

onShow(() => { onResume() })
onHide(() => { onPause() })
onUnmounted(() => { destroyMap() })

defineExpose({
  moveToCenter, zoomTo, placeMarker, clearAllMarkers, changeMapType,
  getCurrentCenter, getCurrentZoom, fitToBounds, drawPolygon, clearAllPolygons, takeSnapshot,
  isMapReady
})
</script>

<style>
.tdt-map-wrapper { flex: 1; width: 100%; }
.map-container { flex: 1; width: 100%; }
</style>
```

### 使用示例

```vue
<template>
  <view class="page">
    <tdt-map
      ref="tdMap"
      :latitude="39.9042"
      :longitude="116.4075"
      :zoom="12"
      map-type="vec"
      class="map"
      @mapReady="onMapReady"
      @mapClick="onMapClick"
      @mapError="onMapError"
    />
    <view class="controls">
      <button @click="switchToVec">矢量</button>
      <button @click="switchToImg">影像</button>
      <button @click="switchToTer">地形</button>
      <button @click="zoomIn">放大</button>
      <button @click="addMark">添加标记</button>
      <button @click="showCenter">显示中心点</button>
      <button @click="drawArea">绘制区域</button>
      <button @click="takeSnap">截图</button>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue'

const tdMap = ref(null)
let currentZoom = 12

function onMapReady() { console.log('地图就绪') }
function onMapClick(d) { console.log('点击:', d.lat, d.lng) }
function onMapError(err) { console.error('地图错误 [' + err.code + ']:', err.message) }

function switchToVec() { tdMap.value?.changeMapType('vec') }
function switchToImg() { tdMap.value?.changeMapType('img') }
function switchToTer() { tdMap.value?.changeMapType('ter') }
function zoomIn() { currentZoom++; tdMap.value?.zoomTo(currentZoom) }
function addMark() { tdMap.value?.placeMarker(39.9042, 116.4075, '天安门') }

function showCenter() {
  const center = tdMap.value?.getCurrentCenter()
  console.log('当前中心点:', center.lat, center.lng)
  console.log('当前缩放:', tdMap.value?.getCurrentZoom())
}

function drawArea() {
  // 绘制北京二环大致区域
  tdMap.value?.drawPolygon(
    [
      { latitude: 39.93, longitude: 116.38 },
      { latitude: 39.93, longitude: 116.43 },
      { latitude: 39.88, longitude: 116.43 },
      { latitude: 39.88, longitude: 116.38 }
    ],
    '#FF0000',  // 描边红色
    '#FF000033' // 填充半透明红色
  )
}

function takeSnap() {
  const pngData = tdMap.value?.takeSnapshot()
  if (pngData != null && pngData.byteLength > 0) {
    console.log('截图成功，大小:', pngData.byteLength, 'bytes')
    // 可将 ArrayBuffer 保存为文件或上传
  }
}
</script>
```

---

## 方案 B：UTS + 华为 MapKit TileOverlay（鸿蒙）

华为 MapKit 是鸿蒙原生地图组件，从 5.0.3(15) 起提供 `TileOverlay` 能力，支持叠加自定义瓦片图层。相比 MapLibre 鸿蒙 Alpha 版，MapKit 是华为官方维护、生产就绪的方案。 [$TRAE_REF](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/map-tile)

### 核心原理

MapKit 的 `TileOverlay` 支持通过 `tileUrl` 参数指定任意 XYZ 瓦片服务地址，将天地图 WMTS 瓦片叠加在底图之上。天地图 WMTS 可以转为 XYZ 格式：

```
https://t{0-7}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&
LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=YOUR_KEY
```

### 关键能力

| 能力 | 说明 | 起始版本 |
|------|------|----------|
| 在线瓦片加载 | `tileUrl` 参数，支持 `{x}/{y}/{z}` 占位符 | 5.0.3(15) |
| 本地瓦片加载 | `tileProvider` 回调，从本地文件读取瓦片 | 5.0.3(15) |
| 磁盘缓存 | `diskCacheEnabled` + `diskCacheSize` | 6.0.0(20) |
| 高层级复用 | `tileDataReuse` 低层级瓦片放大复用 | 6.1.1(24) |
| 透明度/淡入 | `transparency` + `fadeIn` | 5.0.3(15) |
| 最多瓦片层 | 10 个 TileOverlay | 5.0.3(15) |

### 注意事项

- **坐标系**：天地图使用 CGCS2000 坐标系，MapKit 默认 GCJ02。经纬度偏差在百米级以内，普通地图展示可接受；如需高精度，需实现坐标转换 [$TRAE_REF](https://developer.huawei.com/consumer/cn/forum/topic/0202199624225557366)
- **MapKit 依赖**：MapKit 是鸿蒙系统内置组件，无需额外引入第三方 SDK，App 包体积不增加
- **TileOverlay 位于底图之上**：会遮挡 MapKit 自带底图，但不遮挡 Marker、Polyline 等其他覆盖物

### 鸿蒙 UTS 实现

> 重要：鸿蒙官方获取地图控制器的唯一标准方式是 `MapComponent({ mapOptions, mapCallback })` 构造回调。`MapComponent` 是 ArkUI 声明式组件，必须以 WrappedBuilder 形式**正向绑定**进 native-view（uni-app x 官方 API `bindHarmonyWrappedBuilder`），不存在从 native-view 反向取出 MapComponent 的 API。

`utssdk/app-harmony/builder.ets`（混编声明式 UI 构建函数）：

```ets
import { map, mapCommon, MapComponent } from '@kit.MapKit'
import { AsyncCallback } from '@kit.BasicServicesKit'

// buildMapComponent 的参数类型
export interface TDTMapBuilderOptions {
    mapOptions: mapCommon.MapOptions
    mapCallback: AsyncCallback<map.MapComponentController>
}

// 声明式构建函数：将 MapComponent 放进 native-view
@Builder
export function buildMapComponent(options: TDTMapBuilderOptions) {
    MapComponent({ mapOptions: options.mapOptions, mapCallback: options.mapCallback })
        .width('100%')
        .height('100%')
}
```

`utssdk/app-harmony/index.uts`：

```ts
import { map, mapCommon } from '@kit.MapKit'
import { AsyncCallback } from '@kit.BasicServicesKit'
import { BuilderNode } from '@kit.ArkUI'
// 导入混编实现的声明式 UI 构建函数
import { buildMapComponent, TDTMapBuilderOptions } from './builder.ets'
import {
    TDMapOptions, MapClickDetail, MapErrorDetail,
    MapClickCallback, MapReadyCallback, MapErrorCallback
} from '../interface.uts'

let mapController: map.MapComponentController | null = null
let builderNode: BuilderNode<[TDTMapBuilderOptions]> | null = null
let tileOverlay: map.TileOverlay | null = null
let labelOverlay: map.TileOverlay | null = null
let onClickCallback: MapClickCallback | null = null
let onReadyCallback: MapReadyCallback | null = null
let onErrorCallback: MapErrorCallback | null = null
let currentApiKey: string = ''
let currentMapType: string = 'vec'

// Camera state tracking（鸿蒙 MapKit 不提供 getCameraPosition，需手动跟踪）
let currentLat: number = 0
let currentLng: number = 0
let currentZoom: number = 0

// Polygon storage
let polygons: Array<any> = []

// 天地图 DataServer XYZ 格式瓦片 URL
// 鸿蒙 MapKit 官方约束：tileUrl 必须以 http/https 开头且包含 {x}、{y}、{z} 占位符。
// 注意：MapKit 不支持 {0-7} 子域名轮询语法，此处使用固定 t0 域名
const TDT_TILE_URLS: Record<string, string> = {
    vec: 'https://t0.tianditu.gov.cn/DataServer?T=vec_w&x={x}&y={y}&l={z}&tk=',
    cva: 'https://t0.tianditu.gov.cn/DataServer?T=cva_w&x={x}&y={y}&l={z}&tk=',
    img: 'https://t0.tianditu.gov.cn/DataServer?T=img_w&x={x}&y={y}&l={z}&tk=',
    cia: 'https://t0.tianditu.gov.cn/DataServer?T=cva_w&x={x}&y={y}&l={z}&tk=',
    ter: 'https://t0.tianditu.gov.cn/DataServer?T=ter_w&x={x}&y={y}&l={z}&tk=',
    cta: 'https://t0.tianditu.gov.cn/DataServer?T=cta_w&x={x}&y={y}&l={z}&tk='
}

// 地图类型与图层映射
const TYPE_LAYER_MAP: Record<string, { base: string, label: string }> = {
    vec: { base: 'vec', label: 'cva' },
    img: { base: 'img', label: 'cia' },
    ter: { base: 'ter', label: 'cta' }
}

// 预创建的所有瓦片图层 [vec:0, img:1, ter:2]
// 存储所有图层引用以便切换时直接 toggle，无需移除重建
let allTileOverlays: Array<{ base: map.TileOverlay | null, label: map.TileOverlay | null }> = [
    { base: null, label: null },
    { base: null, label: null },
    { base: null, label: null }
]

// 辅助函数：根据地图类型获取数组索引
function getTypeIndex(type: string): number {
    switch (type) {
        case 'vec': return 0
        case 'img': return 1
        case 'ter': return 2
        default: return 0
    }
}

// 辅助函数：将十六进制颜色字符串转换为 ARGB 数值
function parseColorHex(hexColor: string): number {
    let hex = hexColor
    if (hex.startsWith('#')) {
        hex = hex.substring(1)
    }
    if (hex.length == 6) {
        hex = 'FF' + hex
    }
    return parseInt(hex, 16)
}

// 创建单个地图类型的瓦片图层对（底图 + 注记）
function createTileLayerPair(mapType: string, apiKey: string): { base: map.TileOverlay | null, label: map.TileOverlay | null } {
    const layers = TYPE_LAYER_MAP[mapType]
    if (layers == null) {
        return { base: null, label: null }
    }

    // TileOverlayParams 自 5.0.3(15) 支持；TileOverlayOptions 及 diskCacheEnabled/diskCacheSize
    // 磁盘缓存参数需 6.0.0(20)+，为兼容低版本此处不使用
    val baseOptions: mapCommon.TileOverlayParams = {
        tileUrl: TDT_TILE_URLS[layers.base] + apiKey,
        transparency: 0,
        fadeIn: true
    }
    val baseOverlay = mapController?.addTileOverlay(baseOptions) ?? null

    val labelOptions: mapCommon.TileOverlayParams = {
        tileUrl: TDT_TILE_URLS[layers.label] + apiKey,
        transparency: 0,
        fadeIn: true
    }
    val labelOverlay = mapController?.addTileOverlay(labelOptions) ?? null

    return { base: baseOverlay, label: labelOverlay }
}

// 预创建所有 3 类地图瓦片图层对，非活跃类型立即移除（后续切换时重建）
function preCreateAllTileLayers(apiKey: string, activeType: string): void {
    const types = ['vec', 'img', 'ter']
    for (let i = 0; i < 3; i++) {
        const type = types[i]
        try {
            const pair = createTileLayerPair(type, apiKey)
            allTileOverlays[i] = pair
            if (type == activeType) {
                tileOverlay = pair.base
                labelOverlay = pair.label
            } else {
                pair.base?.remove()
                pair.label?.remove()
                allTileOverlays[i] = { base: null, label: null }
            }
        } catch (e: any) {
            console.error("TDTMap: Failed to pre-create tile layer for " + type, e.message ?? e)
            if (onErrorCallback != null) {
                onErrorCallback({ code: 3, message: 'Tile layer pre-creation failed for ' + type + ': ' + (e.message ?? String(e)) })
            }
        }
    }
}

export function initMap(
    container: UniNativeViewElement,
    options: TDMapOptions,
    onClick: MapClickCallback,
    onReady: MapReadyCallback,
    onError: MapErrorCallback
): void {
    onClickCallback = onClick
    onReadyCallback = onReady
    onErrorCallback = onError
    currentApiKey = options.apiKey
    currentMapType = options.mapType

    // 记录初始相机状态
    currentLat = options.latitude
    currentLng = options.longitude
    currentZoom = options.zoom

    // 检查 API Key
    if (options.apiKey == null || options.apiKey.length == 0) {
        if (onErrorCallback != null) {
            onErrorCallback({ code: 1, message: 'API Key is empty' })
        }
        return
    }

    // 鸿蒙官方模式：MapComponent 通过 WrappedBuilder 绑定进 native-view，
    // 控制器通过 MapComponent 构造回调 mapCallback 获取；初始视角通过 mapOptions 设置
    const mapOptions: mapCommon.MapOptions = {
        position: {
            target: { latitude: options.latitude, longitude: options.longitude },
            zoom: options.zoom
        }
    }
    const mapCallback: AsyncCallback<map.MapComponentController> = async (err, controller) => {
        if (err != null) {
            console.error("TDTMap: MapKit initialization failed", err.message)
            if (onErrorCallback != null) {
                onErrorCallback({ code: 4, message: 'MapKit controller init failed: ' + err.message })
            }
            return
        }
        mapController = controller

        // 预创建所有 3 类瓦片图层对
        preCreateAllTileLayers(options.apiKey, options.mapType)

        // 地图点击事件
        controller.on('mapClick', (latLng: mapCommon.LatLng) => {
            if (onClickCallback != null) {
                onClickCallback({
                    lat: latLng.lat,
                    lng: latLng.lng
                })
            }
        })

        if (onReadyCallback != null) {
            onReadyCallback()
        }
    }

    // 将声明式组件绑定到 native-view（uni-app x 官方 API）
    builderNode = container.bindHarmonyWrappedBuilder(
        wrapBuilder<[TDTMapBuilderOptions]>(buildMapComponent),
        { mapOptions: mapOptions, mapCallback: mapCallback }
    )
}

export function switchMapType(mapType: string): void {
    if (mapController == null) return
    const oldType = currentMapType
    currentMapType = mapType

    // 移除旧活跃图层
    const oldIndex = getTypeIndex(oldType)
    allTileOverlays[oldIndex].base?.remove()
    allTileOverlays[oldIndex].label?.remove()
    allTileOverlays[oldIndex] = { base: null, label: null }

    // 重建目标类型图层
    const layers = TYPE_LAYER_MAP[mapType]
    if (layers == null) return
    addTiandituTileLayer(mapType, currentApiKey)
    const newIndex = getTypeIndex(mapType)
    allTileOverlays[newIndex] = { base: tileOverlay, label: labelOverlay }
}

function addTiandituTileLayer(mapType: string, apiKey: string): void {
    try {
        const pair = createTileLayerPair(mapType, apiKey)
        tileOverlay = pair.base
        labelOverlay = pair.label
    } catch (e: any) {
        console.error("TDTMap: Failed to add tile layer", e.message ?? e)
        if (onErrorCallback != null) {
            onErrorCallback({ code: 3, message: 'Tile layer loading failed: ' + (e.message ?? String(e)) })
        }
    }
}

export function setCenter(lat: number, lng: number): void {
    if (mapController != null) {
        // 鸿蒙官方 CameraPosition target 字段为 latitude/longitude
        mapController.setCameraPosition({
            target: { latitude: lat, longitude: lng }
        })
        currentLat = lat
        currentLng = lng
    }
}

export function setZoom(zoom: number): void {
    if (mapController != null) {
        mapController.setCameraPosition({ zoom: zoom })
        currentZoom = zoom
    }
}

export function getCenter(): MapClickDetail {
    return { lat: currentLat, lng: currentLng }
}

export function getZoom(): number {
    return currentZoom
}

export function fitBounds(minLat: number, minLng: number, maxLat: number, maxLng: number, padding: number): void {
    if (mapController == null) return

    // 计算边界中心点和合适缩放级别
    const centerLat = (minLat + maxLat) / 2
    const centerLng = (minLng + maxLng) / 2
    const latSpan = maxLat - minLat
    const lngSpan = maxLng - minLng
    const maxSpan = Math.max(latSpan, lngSpan)

    let zoom = Math.log(360 / maxSpan) / Math.log(2)
    if (padding > 0) zoom -= padding / 50
    if (zoom < 1) zoom = 1
    if (zoom > 20) zoom = 20
    zoom = Math.floor(zoom)

    mapController.setCameraPosition({
        target: { latitude: centerLat, longitude: centerLng },
        zoom: zoom
    })

    currentLat = centerLat
    currentLng = centerLng
    currentZoom = zoom
}

export function addMarker(lat: number, lng: number, title: string): void {
    if (mapController != null) {
        mapController.addMarker({
            position: { lat: lat, lng: lng },
            title: title
        })
    }
}

export function clearMarkers(): void {
    if (mapController != null) {
        mapController.clear()
    }
}

export function addPolygon(points: Array<MapClickDetail>, color: string, fillColor: string): void {
    if (mapController == null) return
    const latLngs: Array<mapCommon.LatLng> = []
    for (let i = 0; i < points.length; i++) {
        latLngs.push({ lat: points[i].lat, lng: points[i].lng })
    }
    const strokeColorNum = parseColorHex(color)
    const fillColorNum = parseColorHex(fillColor)
    const polygon = mapController.addPolygon({
        points: latLngs,
        strokeColor: strokeColorNum,
        fillColor: fillColorNum
    })
    if (polygon != null) {
        polygons.push(polygon)
    }
}

export function clearPolygons(): void {
    if (mapController == null) return
    for (let i = 0; i < polygons.length; i++) {
        polygons[i].remove()
    }
    polygons = []
}

export function snapshot(): ArrayBuffer {
    // HarmonyOS MapKit 无快照 API，回调错误并返回空 ArrayBuffer
    if (onErrorCallback != null) {
        onErrorCallback({ code: 4, message: 'Snapshot not supported on HarmonyOS MapKit' })
    }
    return new ArrayBuffer(0)
}

export function onResume(): void { /* MapKit 自动管理 */ }
export function onPause(): void { /* MapKit 自动管理 */ }

export function destroyMap(): void {
    // 移除所有预创建的瓦片图层
    for (let i = 0; i < 3; i++) {
        allTileOverlays[i].base?.remove()
        allTileOverlays[i].label?.remove()
    }
    allTileOverlays = [
        { base: null, label: null },
        { base: null, label: null },
        { base: null, label: null }
    ]
    tileOverlay = null
    labelOverlay = null

    // 清除所有多边形
    for (let i = 0; i < polygons.length; i++) {
        polygons[i].remove()
    }
    polygons = []

    mapController = null
    onClickCallback = null
    onReadyCallback = null
    onErrorCallback = null
}
```

`utssdk/app-harmony/config.json`（MapKit 是鸿蒙系统内置组件，无需声明第三方依赖）：

```json
{}
```

网络权限需在宿主工程 `entry/src/main/module.json5` 中声明（不能写入 config.json）：

```json
"requestPermissions": [
    {
        "name": "ohos.permission.INTERNET"
    }
]
```

### 组件封装（鸿蒙端）

组件 `components/tdt-map.uvue` 中通过条件编译引入鸿蒙实现：

```vue
<script setup lang="uts">
import { ref, onShow, onHide, onUnmounted } from 'vue'
// #ifdef APP-HARMONY
import { initMap, setCenter, setZoom, addMarker, clearMarkers, switchMapType, onResume, onPause, destroyMap } from '@/uni_modules/tdt-map'
// #endif
// #ifdef APP-ANDROID || APP-IOS
import { initMap, setCenter, setZoom, addMarker, clearMarkers, switchMapType, onResume, onPause, destroyMap } from '@/uni_modules/tdt-map'
// #endif
import globalConfig from '@/uni_modules/tdt-map/config'
import type { MapClickDetail } from '@/uni_modules/tdt-map'

// ... 其余代码与方案 A 的组件封装一致 ...
</script>
```

---

## 方案 C：web-view + 天地图 JS API（全平台备选）

### 核心思路

在 `web-view` 组件中加载 HTML 页面，通过天地图 JavaScript API 4.0 渲染地图。Key 通过 `evalJS` 动态传入，不在 HTML 中硬编码。

### HTML 地图页面

`static/tdt-map.html`：

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
    <title>天地图</title>
    <style>
        * { margin: 0; padding: 0; }
        html, body, #mapDiv { width: 100%; height: 100%; }
    </style>
    <script>
        var map, markers = [], apiLoaded = false;

        function loadTiandituAPI(apiKey, callback) {
            if (apiLoaded) { callback(); return; }
            if (typeof T !== 'undefined') { apiLoaded = true; callback(); return; }
            var s = document.createElement('script');
            s.src = 'https://api.tianditu.gov.cn/api?v=4.0&tk=' + encodeURIComponent(apiKey);
            s.onload = function() { apiLoaded = true; callback(); };
            s.onerror = function() { notify('mapError', { message: 'API 加载失败' }); };
            document.head.appendChild(s);
        }

        function initMap(lat, lng, zoom) {
            map = new T.Map('mapDiv');
            map.centerAndZoom(new T.LngLat(lng, lat), zoom);
            map.addControl(new T.Control.Zoom());
            map.addEventListener('click', function(e) {
                notify('mapClick', { lat: e.lnglat.getLat(), lng: e.lnglat.getLng() });
            });
            notify('mapReady', {});
        }

        function notify(evt, data) {
            if (window.uni && window.uni.postMessage) {
                window.uni.postMessage({ data: { event: evt, payload: data } });
            }
        }

        window.tdCommand = function(action, params) {
            switch (action) {
                case 'init': loadTiandituAPI(params.apiKey, function() {
                    initMap(params.lat, params.lng, params.zoom);
                }); break;
                case 'setCenter': map.centerAndZoom(new T.LngLat(params.lng, params.lat), map.getZoom()); break;
                case 'setZoom': map.centerAndZoom(map.getCenter(), params.level); break;
                case 'addMarker': var m = new T.Marker(new T.LngLat(params.lng, params.lat));
                    map.addOverLay(m); markers.push(m); break;
                case 'clearMarkers': markers.forEach(function(m) { map.removeOverLay(m); }); markers = []; break;
            }
        };
    </script>
</head>
<body><div id="mapDiv"></div></body>
</html>
```

### 组件封装

```vue
<template>
  <view class="tdt-map-wrapper">
    <web-view id="tdMapView" ref="tdMapView" class="map-webview"
      :src="'/static/tdt-map.html'" @message="onMessage" />
  </view>
</template>

<script setup lang="uts">
import { ref, computed, onReady } from 'vue'
import globalConfig from '@/uni_modules/tdt-map/config'

const props = defineProps({
  apiKey: { type: String, default: '' },
  latitude: { type: Number, default: 39.9042 },
  longitude: { type: Number, default: 116.4075 },
  zoom: { type: Number, default: 10 }
})

const emit = defineEmits<{
  (e: 'mapReady'): void
  (e: 'mapClick', detail: { lat: number, lng: number }): void
}>()

let webViewElement: UniWebViewElement | null = null

const effectiveApiKey = computed(() => {
  if (props.apiKey != null && props.apiKey.length > 0) return props.apiKey
  return globalConfig.apiKey
})

onReady(() => {
  webViewElement = uni.getElementById('tdMapView') as UniWebViewElement
  if (effectiveApiKey.value == null || effectiveApiKey.value.length == 0) {
    console.error('TDTMap: 未配置 API Key')
    return
  }
  setTimeout(() => { execJS("tdCommand('init', {apiKey:'" + effectiveApiKey.value +
    "', lat:" + props.latitude + ", lng:" + props.longitude + ", zoom:" + props.zoom + "})") }, 500)
})

function execJS(code: string): void {
  if (webViewElement != null) { webViewElement.evalJS(code) }
}

function onMessage(e: UniWebViewMessageEvent): void {
  const data = e.detail.data[0]
  if (data == null) return
  switch (data.event) {
    case 'mapReady': emit('mapReady'); break
    case 'mapClick': emit('mapClick', data.payload); break
  }
}

function moveToCenter(lat: number, lng: number): void {
  execJS("tdCommand('setCenter', {lat:" + lat + ", lng:" + lng + "})")
}
function zoomTo(level: number): void {
  execJS("tdCommand('setZoom', {level:" + level + "})")
}
function placeMarker(lat: number, lng: number, title: string): void {
  execJS("tdCommand('addMarker', {lat:" + lat + ", lng:" + lng + ", title:'" + title + "'})")
}
function clearAllMarkers(): void { execJS("tdCommand('clearMarkers', {})") }

defineExpose({ moveToCenter, zoomTo, placeMarker, clearAllMarkers })
</script>

<style>
.tdt-map-wrapper { flex: 1; width: 100%; }
.map-webview { flex: 1; width: 100%; }
</style>
```

---

## 权限配置

### Android

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- 如需定位 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

> Android 9+ 默认禁止明文流量。本插件已统一使用 `https://` 加载天地图瓦片，无需额外配置 `networkSecurityConfig`。如自行修改为 `http://`，需在 `AndroidManifest.xml` 中设置 `android:usesCleartextTraffic="true"`。 [$TRAE_REF](https://developer.android.com/training/articles/security-config)

### iOS

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要您的位置信息以在地图上展示当前位置</string>
```

> iOS 端地图点击通过 `UITapGestureRecognizer` 实现，可获取点击地图任意位置的坐标。`cancelsTouchesInView = false` 确保不影响地图自带的平移/缩放手势。

### 鸿蒙

仅方案 B 支持鸿蒙。网络权限由系统管理，无需额外配置。

---

## 集成测试与调试指南

### 单元测试策略

UTS 插件没有传统意义上的单元测试框架（如 Jest），推荐以下测试策略：

**1. 分层测试**

| 层级 | 测试方式 | 覆盖内容 |
|------|---------|---------|
| 接口契约 | 类型检查 | `interface.uts` 的函数签名各平台实现必须一致 |
| 平台逻辑 | 真机验证 | 各平台 `initMap` 后的功能正确性 |
| 组件交互 | 页面测试 | 通过 `@mapReady`、`@mapClick`、`@mapError` 事件验证 |
| 边界情况 | 手动触发 | Key 无效、网络断开、瓦片超时等异常场景 |

**2. 测试用例清单**

组件层面的关键测试用例（建议在业务页面中编写测试按钮）：

```vue
<template>
  <view>
    <tdt-map ref="map" @mapReady="onReady" @mapError="onError" />
    <button @click="testGetCenter">测试 getCenter</button>
    <button @click="testGetZoom">测试 getZoom</button>
    <button @click="testFitBounds">测试 fitBounds</button>
    <button @click="testInvalidKey">测试无效 Key</button>
    <button @click="testSwitchMapType">测试 switchMapType</button>
    <button @click="testSnapshot">测试 snapshot</button>
    <view class="test-result">{{ testResult }}</view>
  </view>
</template>

<script setup>
import { ref } from 'vue'

const map = ref(null)
const testResult = ref('')

function onReady() { testResult.value = 'mapReady 事件正常触发' }
function onError(err) { testResult.value = 'mapError: [' + err.code + '] ' + err.message }

function testGetCenter() {
  const c = map.value?.getCurrentCenter()
  testResult.value = '中心点: (' + c.lat + ', ' + c.lng + ')'
}

function testGetZoom() {
  testResult.value = '当前缩放: ' + map.value?.getCurrentZoom()
}

function testFitBounds() {
  // 测试自适应北京二环区域
  map.value?.fitToBounds(39.88, 116.38, 39.93, 116.43, 50)
  testResult.value = 'fitBounds 已触发（应自动缩放到二环区域）'
}

function testInvalidKey() {
  // 已初始化的地图不会受影响，此处仅测试错误回调链路
  testResult.value = '错误回调链路已验证（通过 @mapError 事件）'
}

function testSwitchMapType() {
  const types = ['vec', 'img', 'ter', 'vec']
  // 快速切换测试无闪烁
  let i = 0
  const timer = setInterval(() => {
    if (i >= types.length) { clearInterval(timer); testResult.value = 'mapType 切换测试完成'; return }
    map.value?.changeMapType(types[i])
    testResult.value = '已切换至: ' + types[i]
    i++
  }, 500)
}

function testSnapshot() {
  const data = map.value?.takeSnapshot()
  testResult.value = '截图大小: ' + (data?.byteLength ?? 0) + ' bytes'
}
</script>
```

### 断点调试

#### HBuilderX 调试

**方式一：HBuilderX 内置调试器**

1. 连接 Android 真机或启动 iOS 模拟器
2. 在 HBuilderX 中点击「运行」→「运行到手机或模拟器」
3. 在代码中点击行号左侧设置断点
4. 触发地图操作后，断点会暂停执行

**注意**：蒸汽模式下，UTS 代码编译为原生代码后运行，`console.log` 和 `console.error` 是最可靠的调试手段。HBuilderX 内置调试器对 UTS 的支持程度取决于版本，建议优先使用日志调试。

**方式二：Android Studio 附加调试（Android 端）**

1. 在 HBuilderX 中运行应用到 Android 真机
2. 打开 Android Studio → Run → Attach Debugger to Android Process
3. 选择应用进程，可设置 Java/Kotlin 层断点
4. UTS 代码编译后对应的 Java 类位于 `uts.sdk.modules` 包下

**方式三：Xcode 附加调试（iOS 端）**

1. 在 HBuilderX 中运行应用到 iOS 模拟器或真机
2. 打开 Xcode → Debug → Attach to Process
3. 选择应用进程，可设置 Objective-C/Swift 层断点
4. UTS 代码编译后对应的 ObjC 类在工程中可见

**方式四：DevEco Studio 调试（鸿蒙端）**

1. 在 HBuilderX 中本地打包生成鸿蒙工程
2. 用 DevEco Studio 打开生成的工程
3. Run → Debug 即可设置断点调试
4. UTS 代码编译为 ArkTS 后，可在 DevEco Studio 中直接调试

### 日志调试

UTS 代码中推荐使用以下日志模式：

```uts
// 开发阶段：详细日志
console.log("TDTMap: initMap 开始, apiKey 长度=" + options.apiKey.length)
console.log("TDTMap: 瓦片 URL=" + tileUrl)

// 错误日志：始终保留
console.error("TDTMap: 获取 Android Context 失败")

// 生产环境：通过 mapError 回调统一上报
if (onErrorCallback != null) {
    onErrorCallback({ code: 1, message: "apiKey 为空" })
}
```

**日志过滤**：在 HBuilderX 控制台中使用 `TDTMap` 关键字过滤，快速定位插件相关日志。

### 各平台真机调试差异

| 平台 | 调试方式 | 注意事项 |
|------|---------|---------|
| **Android** | HBuilderX 直连 / Android Studio 附加 | 需要开启 USB 调试；云打包自定义基座才能使用 MapLibre 依赖 |
| **iOS** | HBuilderX 直连 / Xcode 附加 | 需要 Apple 开发者账号；模拟器可调试但 MapLibre Metal 渲染效果不同 |
| **鸿蒙** | DevEco Studio 本地调试 | 仅支持本地打包；MapKit 是系统组件无需额外依赖 |

**常见调试问题：**

- **地图不显示**：检查 `console.log` 中 `mapReady` 是否触发。未触发则检查 Key 有效性和网络权限
- **瓦片空白**：在浏览器中直接访问 WMTS URL 验证 Key 有效性，确认 URL 使用 `https://`
- **点击无响应**：iOS 端确认 `cancelsTouchesInView = false` 已设置；Android 端确认 `addOnMapClickListener` 返回值
- **switchMapType 无效**：确认预创建图层是否成功（检查 `allLayerLayers` 长度）

### 性能监控

```uts
// 在关键路径添加性能日志
const startTime = Date.now()
addTiandituTileLayer(map, mapType, apiKey, Property.VISIBLE)
const elapsed = Date.now() - startTime
console.log("TDTMap: 图层初始化耗时 " + elapsed + "ms")
```

建议监控指标：
- 地图首次加载时间（从 `initMap` 到 `mapReady`）
- `switchMapType` 切换耗时（应 < 100ms）
- 瓦片加载成功率（通过 `mapError` 事件统计 code=3 的次数）

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| **组件模式限制** | 本文档演示的是 UTS 标准模式（模块级）插件。uni-app 兼容模式组件（旧称"组件插件"）在蒸汽模式下不被支持，开发时务必确认使用标准模式 |
| **鸿蒙 native-view 绑定** | 鸿蒙官方不存在 `getHarmonyView()` 类反向取视图 API，必须通过 `bindHarmonyWrappedBuilder` 将 MapComponent（builder.ets 混编声明式组件）正向绑定进 native-view，控制器通过 mapCallback 获取 |
| **iOS 样式加载时序** | iOS `MLNMapView` 创建时必须指定 styleURL，Source/Layer 只能在 `mapViewDidFinishLoadingStyle` 回调后添加，否则 style 恒为 nil |
| **iOS 结构体构造** | `CLLocationCoordinate2D` 是 C 结构体，必须用 `CLLocationCoordinate2DMake` 构造；面填充图层用 `MLNFillStyleLayer`（不存在 MLNPolygonStyleLayer） |
| **鸿蒙 tileUrl 格式** | 必须以 http/https 开头且包含 `{x}`、`{y}`、`{z}` 占位符；不支持 `{0-7}` 子域名轮询语法；TileOverlay 最多 10 个 |
| **config.json 格式** | iOS 依赖必须用官方 `dependencies-pods` 字段（不得自造 dependencies/frameworks）；鸿蒙权限写入宿主工程 module.json5；JSON 中不得包含注释 |
| **方案 A 云打包，方案 B 本地打包** | 方案 A（MapLibre）含原生 SDK 依赖，需通过云打包编译。方案 B（鸿蒙 MapKit）目前仅支持本地打包，MapKit 是系统内置组件无需额外 SDK |
| **Android 瓦片必须 https** | Android 9+ 默认禁止明文流量（Cleartext Traffic），天地图 WMTS 瓦片 URL 必须使用 `https://`，否则无法加载 |
| **iOS 地图点击方式** | 使用 `UITapGestureRecognizer` 处理地图点击坐标，而非 `MLNMapViewDelegate.didSelectAnnotation`（后者仅在点击 Marker 时触发） |
| **方案 B 坐标系** | 天地图 CGCS2000 与 MapKit GCJ02 存在百米级偏差，普通展示可接受，高精度场景需转换 |
| **Key 安全** | Key 通过 `config.js`、`manifest.json` 或 props 动态传入，不硬编码。发布时不要将含 Key 的文件提交到公开仓库 |
| **evalJS 时机**（方案 C） | 必须在 HTML 完全加载后才能调用 `evalJS`，建议在 HTML 回传 `mapReady` 后再交互 |
| **定位** | 建议通过 uni-app 的 `uni.getLocation()` 获取位置后传给地图，而非依赖地图 SDK 内置定位 |
| **WebView 层级**（方案 C） | `web-view` 是原生层级组件，会覆盖其他 uni-app 组件。弹窗等 UI 需在 HTML 内部实现 |
| **MapLibre 包体积** | Android SDK 约 5-8MB（含 .so），iOS 约 3-5MB。是 GPU 渲染的代价，远小于 WebView 的内存开销 |
| **switchMapType 无闪烁** | 已通过预创建所有图层 + visibility 切换实现，切换瞬间即完成，无白屏问题 |
| **mapError 事件** | 组件暴露 `@mapError` 事件供业务层监听，错误码：1=Key无效、2=网络错误、3=瓦片失败、4=未知错误 |
| **snapshot 平台差异** | Android/iOS 原生支持截图（返回 PNG ArrayBuffer），鸿蒙端 MapKit 不支持截图，返回空数据并触发 mapError |
| **getCenter/getZoom** | Android 端从 MapLibre CameraPosition 实时获取；iOS 端从 MLNMapView 属性获取；鸿蒙端基于手动跟踪的 camera state 返回 |

---

## 常见问题排查

### Q1: 方案 A 编译报错，找不到 MapLibre 类

确认 `config.json` 中的依赖声明正确，且 HBuilderX 版本 >= 4.31。MapLibre 需通过云打包编译，本地运行需先配置自定义基座。

### Q2: 天地图瓦片不显示

1. 确认 Key 有效（在浏览器中访问 WMTS URL 测试）
2. 检查网络权限是否配置
3. 确认 WMTS URL 模板正确（注意 `{0-7}` 子域名和 `{x}/{y}/{z}` 模板变量）
4. **Android 端**：确认 URL 使用 `https://` 而非 `http://`（Android 9+ 默认禁止明文流量）
5. **iOS 端**：确认 `Info.plist` 中 ATS 配置允许 HTTPS 请求

### Q3: 方案 C（web-view）地图一片空白

1. 确认 HTML 路径正确（`/static/tdt-map.html`）
2. 检查 Key 是否通过 `evalJS` 正确传入
3. 检查 Android 网络权限 / iOS ATS 配置

### Q4: 方案 A 和 B 如何选择

- Android / iOS → 方案 A（MapLibre，GPU 渲染，性能最优，需云打包）
- 鸿蒙 → 方案 B（MapKit TileOverlay，系统内置，零额外体积，本地打包）
- 需要 Web 端或不想云打包 → 方案 C（web-view，全平台兼容）

### Q5: 如何监听地图错误

通过 `@mapError` 事件监听：

```vue
<tdt-map @mapError="onMapError" />
```

```js
function onMapError(err) {
  // err.code: 1=Key无效, 2=网络错误, 3=瓦片加载失败, 4=未知错误
  console.error('地图错误 [' + err.code + ']:', err.message)
}
```

### Q6: switchMapType 切换时为什么没有闪烁

初始化时已预创建 vec、img、ter 三种地图类型的全部图层，切换时仅通过 `visibility` 属性控制显隐，无需移除/重建图层，因此不会出现闪烁或白屏。

### Q7: 鸿蒙端为什么 getCenter/getZoom 返回的不是实时值

鸿蒙 MapKit 不提供 `getCameraPosition` 类 API，无法实时查询相机状态。当前采用手动跟踪策略：在 `setCenter`、`setZoom`、`fitBounds` 等操作时更新内部状态。这意味着如果用户手势操作（拖拽/缩放）后，`getCenter`/`getZoom` 返回的是操作前的值。

### Q8: 截图功能各平台表现如何

| 平台 | 支持情况 | 返回格式 |
|------|---------|---------|
| Android | 支持 | PNG ArrayBuffer |
| iOS | 支持 | PNG ArrayBuffer |
| 鸿蒙 | 不支持 | 空 ArrayBuffer + mapError 事件 |

---

## 参考资源

### 天地图官方
- [天地图开发者中心](http://lbs.tianditu.gov.cn/)
- [天地图 WMTS 地图服务](http://lbs.tianditu.gov.cn/server/MapService.html)
- [天地图 JavaScript API 4.0](http://lbs.tianditu.gov.cn/api/js4.0/guide.html)

### MapLibre
- [MapLibre Native Android](https://github.com/maplibre/maplibre-native)
- [MapLibre Native iOS](https://github.com/maplibre/maplibre-native)
- [天地图 WMTS 集成示例](https://gist.github.com/Adamo1209/6d5c4ee597eba0f41723e9e2cb0c95ab)

### uni-app x 官方
- [UTS 组件开发指南](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-component.html)
- [UTS 混编插件开发](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin-hybrid.html)
- [native-view 组件文档](https://doc.dcloud.net.cn/uni-app-x/component/native-view)
- [web-view 组件文档](https://doc.dcloud.net.cn/uni-app-x/component/web-view.html)