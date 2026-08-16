import { map, mapCommon, MapComponent } from '@kit.MapKit'
import { AsyncCallback } from '@kit.BasicServicesKit'

// buildMapComponent 的参数类型
export interface TDTMapBuilderOptions {
    mapOptions: mapCommon.MapOptions
    mapCallback: AsyncCallback<map.MapComponentController>
}

// 声明式构建函数：将 MapComponent 放进 native-view
// MapComponent 是 ArkUI 声明式组件，控制器只能通过构造回调 mapCallback 获取
@Builder
export function buildMapComponent(options: TDTMapBuilderOptions) {
    MapComponent({ mapOptions: options.mapOptions, mapCallback: options.mapCallback })
        .width('100%')
        .height('100%')
}
