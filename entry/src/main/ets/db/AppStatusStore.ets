/**
 * AppStatusStore — Global sync & network state backed by AppStorage.
 *
 * UI components bind via:
 *   @StorageProp('app_isOffline')        isOffline: boolean = false;
 *   @StorageProp('app_pendingSyncCount') pendingCount: number = 0;
 *   @StorageProp('app_failedSyncCount')  failedCount: number = 0;
 */

// Key constants — must match what UI components reference
const KEY_OFFLINE: string = 'app_isOffline';
const KEY_PENDING: string = 'app_pendingSyncCount';
const KEY_FAILED: string = 'app_failedSyncCount';

class AppStatusStore {
  private inited: boolean = false;

  /** Call once during app init (e.g. EntryAbility.onWindowStageCreate). */
  init(): void {
    if (this.inited) return;
    AppStorage.setOrCreate<boolean>(KEY_OFFLINE, false);
    AppStorage.setOrCreate<number>(KEY_PENDING, 0);
    AppStorage.setOrCreate<number>(KEY_FAILED, 0);
    this.inited = true;
  }

  // ==================== Setters ====================

  setOffline(offline: boolean): void {
    AppStorage.set<boolean>(KEY_OFFLINE, offline);
  }

  setPendingCount(count: number): void {
    AppStorage.set<number>(KEY_PENDING, count);
  }

  setFailedCount(count: number): void {
    AppStorage.set<number>(KEY_FAILED, count);
  }

  // ==================== Getters (non-reactive, for logic use) ====================

  isOffline(): boolean {
    return AppStorage.get<boolean>(KEY_OFFLINE) ?? false;
  }

  getPendingCount(): number {
    return AppStorage.get<number>(KEY_PENDING) ?? 0;
  }

  getFailedCount(): number {
    return AppStorage.get<number>(KEY_FAILED) ?? 0;
  }
}

const appStatusStore = new AppStatusStore();
export default appStatusStore;
