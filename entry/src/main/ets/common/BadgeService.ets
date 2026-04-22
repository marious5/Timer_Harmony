import { notificationManager } from '@kit.NotificationKit';

/**
 * BadgeService — 通过 notificationManager.setBadgeNumber 驱动桌面应用图标角标。
 *
 * 简历描述的"未完成数量阈值动态替换桌面图标"以角标方式实现最轻量：
 *   - pending=0        → 角标清零（视觉上无红点）
 *   - pending in 1..99 → 显示具体数字
 *   - pending >= 100   → HarmonyOS 系统自动显示 "99+"
 *
 * 若后续需要完整"图标替换"语义，可叠加 FormProvider 服务卡片
 * 或 shortcutInfo 动态 shortcuts，本服务负责最核心的桌面视觉反馈。
 *
 * 内部做了幂等去重：相同计数连续调用只会实际调用一次系统 API。
 */
class BadgeService {
  private lastCount: number = -1;

  async setBadge(count: number): Promise<void> {
    const normalized: number = count < 0 ? 0 : count;
    if (normalized === this.lastCount) return;
    try {
      await notificationManager.setBadgeNumber(normalized);
      this.lastCount = normalized;
      console.info('BADGE_DEBUG: setBadge=' + normalized);
    } catch (err) {
      console.error('BADGE_DEBUG: setBadgeNumber failed: ' + JSON.stringify(err));
    }
  }

  async clear(): Promise<void> {
    await this.setBadge(0);
  }
}

const badgeService = new BadgeService();
export default badgeService;
