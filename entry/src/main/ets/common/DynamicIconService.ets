import { appInfoManager } from '@kit.AppGalleryKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * DynamicIconService — 鸿蒙应用动态图标（Dynamic App Icon）调度层
 *
 * 按"未完成日程数量阈值"映射到 4 档图标，通过双轨驱动落地：
 *   ① AGC 真桌面图标替换：appInfoManager.selectDynamicIcon(iconId)
 *         — 来自 @kit.AppGalleryKit，真实替换桌面 launcher 图标。
 *   ② 应用内图标预览：AppStorage('app_icon_level') 广播 + Image 组件渲染
 *         — 本地 PNG 资源，在任何设备都能直接看到图标变化。
 *
 * 阈值映射（对应 media/app_icon_*.png）：
 *   count == 0       → app_icon_default   → disableDynamicIcon()
 *   count in 1..3    → app_icon_level_1   → selectDynamicIcon(iconIdMap['level_1'])
 *   count in 4..7    → app_icon_level_2   → selectDynamicIcon(iconIdMap['level_2'])
 *   count >= 8       → app_icon_level_3   → selectDynamicIcon(iconIdMap['level_3'])
 *
 * ===============================================================
 * 部署前置条件——仅针对 ① AGC 真桌面图标：
 *
 *   1. 在 AppGallery Connect 控制台 > 应用信息 > 动态图标
 *      中分别上传 app_icon_level_1/level_2/level_3.png，获取三个 iconId。
 *   2. 把获得的 iconId 填入下方 ICON_ID_MAP（缺省未填时自动降级
 *      为只走 ② 应用内预览通道）。
 *   3. queryAvailableIcons() 在启动时打印实际注册的 iconId 列表，
 *      方便核对配置是否正确。
 *
 * 系统级约束（来自官方文档）：
 *   - 仅真机支持，模拟器不生效
 *   - 最低系统版本 HarmonyOS 5.0.3(15)
 *   - 支持设备：Phone / Tablet / PC-2in1；5.1.1(18)+ 支持 Wearable；5.1.1(19)+ 支持 TV
 * ===============================================================
 */

export const ICON_LEVEL_KEY: string = 'app_icon_level';

export type IconLevel = 'default' | 'level_1' | 'level_2' | 'level_3';

/**
 * 档位 → AGC iconId 映射（需 AGC 控制台上传图标后回填真实 ID）。
 * 空字符串代表未配置，会降级为只写 AppStorage（供 UI 应用内预览）。
 */
const ICON_ID_MAP: Record<IconLevel, string> = {
  'default': '',
  'level_1': '',
  'level_2': '',
  'level_3': ''
};

class DynamicIconService {
  private currentLevel: IconLevel = 'default';

  constructor() {
    AppStorage.setOrCreate<string>(ICON_LEVEL_KEY, 'default');
  }

  /** 根据未完成数量计算档位 */
  computeLevel(count: number): IconLevel {
    if (count <= 0) return 'default';
    if (count <= 3) return 'level_1';
    if (count <= 7) return 'level_2';
    return 'level_3';
  }

  /**
   * 主入口：根据未完成日程数更新动态图标。
   * SyncManager.refreshAppStatus 在每次同步/数据变更后 fire-and-forget 调用。
   *
   * 行为：
   *   ① 同档幂等跳过
   *   ② 写 AppStorage（触发 UI 内预览重绘）
   *   ③ 调 AGC 接口切换桌面图标：
   *        - level === 'default'  → disableDynamicIcon()恢复默认
   *        - 其它档 + iconId 已配置 → selectDynamicIcon(iconId)
   *        - iconId 未配置 → 仅降级为应用内预览
   */
  async updateForPendingCount(count: number): Promise<void> {
    const level: IconLevel = this.computeLevel(count);
    if (level === this.currentLevel) {
      return;
    }
    this.currentLevel = level;
    AppStorage.set<string>(ICON_LEVEL_KEY, level);
    console.info('ICON_DEBUG: icon level -> ' + level + ' (pendingCount=' + count + ')');

    try {
      if (level === 'default') {
        await appInfoManager.disableDynamicIcon();
        console.info('ICON_DEBUG: disableDynamicIcon() ok—launcher restored to default');
        return;
      }
      const iconId: string = ICON_ID_MAP[level];
      if (!iconId) {
        console.warn('ICON_DEBUG: iconId for level ' + level +
          ' not configured in ICON_ID_MAP; skip launcher swap (in-app preview still updates)');
        return;
      }
      await appInfoManager.selectDynamicIcon(iconId);
      console.info('ICON_DEBUG: selectDynamicIcon(' + iconId + ') ok for level ' + level);
    } catch (err) {
      const e = err as BusinessError;
      console.error('ICON_DEBUG: AGC dynamic icon switch failed, code=' +
        e.code + ', message=' + e.message);
      // 模拟器 / 未上架 / 不支持设备都会走到这里，应用内预览仍然生效。
    }
  }

  /** 启动诊断：查询 AGC 上实际注册的动态图标列表，打印供核对配置 */
  async queryAvailableIcons(): Promise<void> {
    try {
      const list: appInfoManager.DynamicIconInfo[] = await appInfoManager.queryDynamicIcons();
      console.info('ICON_DEBUG: AGC registered dynamic icons count=' + list.length);
      for (let i = 0; i < list.length; i++) {
        const info: appInfoManager.DynamicIconInfo = list[i];
        console.info('ICON_DEBUG:   #' + i + ' iconId=' + info.iconId +
          ', enabled=' + info.enabled + ', iconUrl=' + info.iconUrl);
      }
    } catch (err) {
      const e = err as BusinessError;
      console.warn('ICON_DEBUG: queryDynamicIcons failed (simulator/unsupported device?), code=' +
        e.code + ', message=' + e.message);
    }
  }

  /** 获取当前档位（供 UI 做预览） */
  getCurrentLevel(): IconLevel {
    return this.currentLevel;
  }

  /** 按档位返回对应的 Resource（供 UI Image 组件直接渲染预览） */
  getResourceForLevel(level: string): Resource {
    if (level === 'level_1') return $r('app.media.app_icon_level_1');
    if (level === 'level_2') return $r('app.media.app_icon_level_2');
    if (level === 'level_3') return $r('app.media.app_icon_level_3');
    return $r('app.media.app_icon_default');
  }
}

const dynamicIconService = new DynamicIconService();
export default dynamicIconService;
