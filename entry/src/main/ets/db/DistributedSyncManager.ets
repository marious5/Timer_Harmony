import { distributedKVStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/**
 * DistributedSyncManager — 基于鸿蒙分布式软总线（Distributed Soft Bus）
 * 构建的跨端实时同步信号通道。
 *
 * 架构定位：
 *   - 端云同步（HTTP + SQLite + LWW）解决"任意设备登录任意网络"的数据一致性；
 *   - 本服务在此之上补充"同账号同网络下多设备即时感知"能力：
 *     任一端写操作后向分布式 KV 写入一个 change_signal，
 *     其它登录同账号的设备通过软总线收到 dataChange(REMOTE) 通知，
 *     立即触发 SyncManager.sync() 拉取最新数据。
 *
 * 底层原理：
 *   distributedKVStore.autoSync=true 时，数据变化会通过系统
 *   分布式软总线（softbus）在可信设备间透明分发，无需开发者
 *   处理 deviceId / session / peerStart 等底层流程，符合 Stage 模型
 *   "纯 ArkTS 即可使用分布式能力"的设计理念。
 *
 * 所需权限（module.json5）：
 *   ohos.permission.DISTRIBUTED_DATASYNC  (user_grant，需运行时申请)
 */

const STORE_ID: string = 'smart_schedule_sync';
const KEY_CHANGE_SIGNAL: string = 'change_signal';

class DistributedSyncManager {
  private kvManager: distributedKVStore.KVManager | null = null;
  private kvStore: distributedKVStore.SingleKVStore | null = null;
  private onRemoteChange: (() => void) | null = null;
  private initialized: boolean = false;

  /**
   * 初始化分布式 KV 通道。
   * @param context   UIAbility context
   * @param bundleName 应用包名（用于 KVManager 隔离）
   */
  async init(context: Context, bundleName: string): Promise<void> {
    if (this.initialized) return;
    try {
      const config: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: bundleName
      };
      this.kvManager = distributedKVStore.createKVManager(config);

      const options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      };
      this.kvStore = await this.kvManager.getKVStore<distributedKVStore.SingleKVStore>(
        STORE_ID, options);

      // 订阅来自其它可信设备的变更（软总线透传）
      this.kvStore.on('dataChange',
        distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE,
        (data: distributedKVStore.ChangeNotification) => {
          console.info('DIST_DEBUG: remote dataChange received, insertLen=' +
            (data.insertEntries ? data.insertEntries.length : 0) +
            ', updateLen=' + (data.updateEntries ? data.updateEntries.length : 0));
          if (this.onRemoteChange) {
            this.onRemoteChange();
          }
        });

      this.initialized = true;
      console.info('DIST_DEBUG: DistributedSyncManager initialized');
    } catch (err) {
      console.error('DIST_DEBUG: init failed (distributed permission not granted?): ' +
        JSON.stringify(err));
    }
  }

  /**
   * 本端写操作后广播一次变更信号。
   * 写入 KV 后软总线会自动分发到同账号可信设备。
   */
  async broadcastChange(): Promise<void> {
    if (!this.kvStore) return;
    try {
      const ts: string = Date.now().toString();
      await this.kvStore.put(KEY_CHANGE_SIGNAL, ts);
      console.info('DIST_DEBUG: broadcasted change_signal=' + ts);
    } catch (err) {
      console.error('DIST_DEBUG: broadcast failed: ' + JSON.stringify(err));
    }
  }

  /**
   * 设置远端变更回调。SyncManager 将其绑定为一次 sync() 触发。
   */
  setRemoteChangeHandler(handler: () => void): void {
    this.onRemoteChange = handler;
  }

  /** 应用销毁时释放订阅，避免泄露。 */
  close(): void {
    if (this.kvStore) {
      try {
        this.kvStore.off('dataChange');
      } catch (_e) {
        // ignore
      }
    }
    this.initialized = false;
  }

  isReady(): boolean {
    return this.initialized && this.kvStore !== null;
  }
}

const distributedSyncManager = new DistributedSyncManager();
export default distributedSyncManager;
