import { connection } from '@kit.NetworkKit';
import httpUtil from '../common/HttpUtil';
import badgeService from '../common/BadgeService';
import dynamicIconService from '../common/DynamicIconService';
import scheduleRepository, { LocalSchedule } from './ScheduleRepository';
import appStatusStore from './AppStatusStore';
import distributedSyncManager from './DistributedSyncManager';
import { Schedule, ScheduleListResponse, ScheduleCreateResponse,
  ScheduleSimpleResponse } from '../common/ScheduleModel';

/**
 * SyncManager — Offline-first sync engine with LWW conflict resolution.
 *
 * Lifecycle:
 *   1. startNetworkMonitor()  — begin listening; auto-syncs when net recovers.
 *   2. sync()                 — manual trigger (e.g. pull-to-refresh).
 *   3. stopNetworkMonitor()   — cleanup on app destroy.
 *
 * Sync order: Push (create → update → delete) then Pull (LWW merge).
 * After each cycle, AppStatusStore is refreshed with pending/failed counts.
 */
class SyncManager {
  private isSyncing: boolean = false;
  private netAvailable: boolean = false;
  private pushedThisCycle: boolean = false;

  // ==================== Network Monitor ====================

  startNetworkMonitor(): void {
    this.checkNetwork();
    console.info('SYNC_DEBUG: Network monitor started');
  }

  stopNetworkMonitor(): void {
    console.info('SYNC_DEBUG: Network monitor stopped');
  }

  /** One-shot network check; also updates AppStatusStore.isOffline. */
  async checkNetwork(): Promise<boolean> {
    try {
      const hasNet: boolean = await connection.hasDefaultNet();
      this.netAvailable = hasNet;
      appStatusStore.setOffline(!hasNet);
      return hasNet;
    } catch (_e) {
      this.netAvailable = false;
      appStatusStore.setOffline(true);
      return false;
    }
  }

  // ==================== Full Sync ====================

  /**
   * Execute a full sync cycle: Push local changes, then Pull remote data.
   * Returns true if sync completed, false if skipped or failed.
   */
  async sync(): Promise<boolean> {
    if (this.isSyncing) {
      console.info('SYNC_DEBUG: Already syncing, skipped');
      return false;
    }

    const hasNet: boolean = await this.checkNetwork();
    if (!hasNet) {
      console.info('SYNC_DEBUG: No network, sync skipped');
      await this.refreshAppStatus();
      return false;
    }

    this.isSyncing = true;
    this.pushedThisCycle = false;
    console.info('SYNC_DEBUG: ========== Sync started ==========');

    let success: boolean = true;
    try {
      await this.pushChanges();
    } catch (err) {
      console.error('SYNC_DEBUG: Push phase error: ' + JSON.stringify(err));
      success = false;
    }
    try {
      await this.pullChanges();
    } catch (err) {
      console.error('SYNC_DEBUG: Pull phase error: ' + JSON.stringify(err));
      success = false;
    }

    this.isSyncing = false;
    await this.refreshAppStatus();

    // 本轮有本端修改推送成功 → 通过分布式软总线广播，
    // 其它同账号在线设备 DistributedSyncManager 监听到后立即触发 sync()
    if (this.pushedThisCycle && distributedSyncManager.isReady()) {
      distributedSyncManager.broadcastChange();
    }

    console.info('SYNC_DEBUG: ========== Sync finished (success=' + success +
      ', pushed=' + this.pushedThisCycle + ') ==========');
    return success;
  }

  /**
   * Refresh AppStatusStore counts from the database.
   *
   * 双通道桌面视觉反馈：
   *   1. 角标 badgeService.setBadge(count)
   *      —— 精确数字，1..99 显示具体值，>=100 自动 "99+"。
   *   2. 动态应用图标 dynamicIconService.updateForPendingCount(count)
   *      —— 按阈值切换四档图标资源：
   *         0      → app_icon_default
   *         1..3   → app_icon_level_1
   *         4..7   → app_icon_level_2
   *         >=8    → app_icon_level_3
   *
   * count 语义：业务维度的"待完成日程数"（未归档 + 未完成），
   * 与 UI Stats Card "待完成" 保持一致。
   */
  async refreshAppStatus(): Promise<void> {
    try {
      const pending: number = await scheduleRepository.getPendingCount();
      const failed: number = await scheduleRepository.getFailedCount();
      appStatusStore.setPendingCount(pending);
      appStatusStore.setFailedCount(failed);

      const business: LocalSchedule[] = await scheduleRepository.getPending();
      const businessCount: number = business.length;
      badgeService.setBadge(businessCount);
      dynamicIconService.updateForPendingCount(businessCount);
    } catch (_e) {
      // DB not ready yet — ignore
    }
  }

  // ==================== Push (Upload) ====================

  private async pushChanges(): Promise<void> {
    await this.pushCreates();
    await this.pushUpdates();
    await this.pushDeletes();
  }

  /**
   * Push pending creates (sync_status = 1).
   * Batch POST /schedule → write back server ids.
   * On failure: mark each record as sync_failed.
   */
  private async pushCreates(): Promise<void> {
    const creates: LocalSchedule[] = await scheduleRepository.getPendingCreates();
    if (creates.length === 0) return;

    console.info('SYNC_DEBUG: Pushing ' + creates.length + ' new schedule(s)');

    const schedules: Schedule[] = [];
    for (let i = 0; i < creates.length; i++) {
      schedules.push(this.toSchedule(creates[i]));
    }

    try {
      const res: ScheduleCreateResponse = await httpUtil.createSchedule(schedules);
      if (res.success && res.ids) {
        const count: number = Math.min(creates.length, res.ids.length);
        for (let i = 0; i < count; i++) {
          await scheduleRepository.updateServerId(creates[i].local_id, res.ids[i]);
          await scheduleRepository.clearSyncFailed(creates[i].local_id);
          console.info('SYNC_DEBUG: Created local_id=' + creates[i].local_id +
            ' → server id=' + res.ids[i]);
        }
        if (count > 0) this.pushedThisCycle = true;
      } else {
        // Server rejected — mark all as failed
        for (let i = 0; i < creates.length; i++) {
          await scheduleRepository.markSyncFailed(creates[i].local_id);
        }
        console.error('SYNC_DEBUG: Push creates failed: ' + (res.error || 'no ids returned'));
      }
    } catch (err) {
      // Network error — mark all as failed
      for (let i = 0; i < creates.length; i++) {
        await scheduleRepository.markSyncFailed(creates[i].local_id);
      }
      console.error('SYNC_DEBUG: Push creates exception: ' + JSON.stringify(err));
    }
  }

  /**
   * Push pending updates (sync_status = 2).
   * Per-record PUT /schedule/<id>.
   */
  private async pushUpdates(): Promise<void> {
    const updates: LocalSchedule[] = await scheduleRepository.getPendingUpdates();
    if (updates.length === 0) return;

    console.info('SYNC_DEBUG: Pushing ' + updates.length + ' updated schedule(s)');

    for (let i = 0; i < updates.length; i++) {
      const local: LocalSchedule = updates[i];
      if (local.id <= 0) {
        console.warn('SYNC_DEBUG: Skipping update for local_id=' + local.local_id + ' (no server id)');
        continue;
      }
      try {
        const schedule: Schedule = this.toSchedule(local);
        const res: ScheduleSimpleResponse = await httpUtil.updateSchedule(local.id, schedule);
        if (res.success) {
          await scheduleRepository.markSynced(local.local_id);
          await scheduleRepository.clearSyncFailed(local.local_id);
          this.pushedThisCycle = true;
          console.info('SYNC_DEBUG: Updated server id=' + local.id + ' OK');
        } else {
          await scheduleRepository.markSyncFailed(local.local_id);
          console.error('SYNC_DEBUG: Update id=' + local.id + ' failed: ' + (res.error || ''));
        }
      } catch (err) {
        await scheduleRepository.markSyncFailed(local.local_id);
        console.error('SYNC_DEBUG: Update id=' + local.id + ' exception: ' + JSON.stringify(err));
      }
    }
  }

  /**
   * Push pending deletes (sync_status = 3).
   * Per-record DELETE /schedule/<id>, then physically remove local row.
   */
  private async pushDeletes(): Promise<void> {
    const deletes: LocalSchedule[] = await scheduleRepository.getPendingDeletes();
    if (deletes.length === 0) return;

    console.info('SYNC_DEBUG: Pushing ' + deletes.length + ' delete(s)');

    for (let i = 0; i < deletes.length; i++) {
      const local: LocalSchedule = deletes[i];

      if (local.id <= 0) {
        await scheduleRepository.physicalDelete(local.local_id);
        console.info('SYNC_DEBUG: Removed unsynced local_id=' + local.local_id);
        continue;
      }

      try {
        const res: ScheduleSimpleResponse = await httpUtil.deleteSchedule(local.id);
        if (res.success) {
          await scheduleRepository.physicalDelete(local.local_id);
          this.pushedThisCycle = true;
          console.info('SYNC_DEBUG: Deleted server id=' + local.id + ' OK');
        } else {
          await scheduleRepository.markSyncFailed(local.local_id);
          console.error('SYNC_DEBUG: Delete id=' + local.id + ' failed: ' + (res.error || ''));
        }
      } catch (err) {
        await scheduleRepository.markSyncFailed(local.local_id);
        console.error('SYNC_DEBUG: Delete id=' + local.id + ' exception: ' + JSON.stringify(err));
      }
    }
  }

  // ==================== Pull (Download + LWW Merge) ====================

  /**
   * Pull remote schedules via GET /schedule, then merge with LWW.
   * Logs per-record merge verdicts for debugging.
   */
  private async pullChanges(): Promise<void> {
    console.info('SYNC_DEBUG: Pulling remote schedules...');
    try {
      const res: ScheduleListResponse = await httpUtil.getSchedules();
      if (!res.success) {
        console.error('SYNC_DEBUG: Pull failed: ' + (res.error || 'unknown'));
        return;
      }

      const remote: Schedule[] = res.schedules || [];
      console.info('SYNC_DEBUG: Received ' + remote.length + ' remote schedule(s)');

      let inserted: number = 0;
      let updated: number = 0;
      let lwwRemote: number = 0;
      let lwwLocal: number = 0;
      let identical: number = 0;

      for (let i = 0; i < remote.length; i++) {
        const verdict: string = await scheduleRepository.upsertFromServer(remote[i]);
        if (verdict === 'inserted') inserted++;
        else if (verdict === 'updated') updated++;
        else if (verdict === 'lww_remote') lwwRemote++;
        else if (verdict === 'lww_local') lwwLocal++;
        else identical++;
      }

      console.info('SYNC_DEBUG: Pull complete — inserted=' + inserted +
        ' updated=' + updated +
        ' lww_remote=' + lwwRemote +
        ' lww_local=' + lwwLocal +
        ' identical=' + identical);
    } catch (err) {
      console.error('SYNC_DEBUG: Pull exception: ' + JSON.stringify(err));
    }
  }

  // ==================== Helpers ====================

  private toSchedule(local: LocalSchedule): Schedule {
    const s: Schedule = {
      id: local.id,
      timestamp: local.timestamp,
      type: local.type,
      content: local.content,
      finished: local.finished,
      archived: local.archived
    };
    return s;
  }
}

const syncManager = new SyncManager();
export default syncManager;
