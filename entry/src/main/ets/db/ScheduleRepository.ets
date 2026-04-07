import { relationalStore } from '@kit.ArkData';
import dbHelper from './DbHelper';
import { Schedule, ScheduleContent } from '../common/ScheduleModel';

const TABLE: string = 'schedule';

// Sync status constants
export const SYNC_SYNCED: number = 0;
export const SYNC_PENDING_CREATE: number = 1;
export const SYNC_PENDING_UPDATE: number = 2;
export const SYNC_PENDING_DELETE: number = 3;

// Local schedule with local management fields
export interface LocalSchedule {
  local_id: number;
  sync_status: number;
  sync_failed: boolean;
  id: number;
  timestamp: string;
  type: string;
  content: ScheduleContent;
  finished: boolean;
  archived: boolean;
}

class ScheduleRepository {

  // ==================== Row ↔ Object Mapping ====================

  private rowToLocal(rs: relationalStore.ResultSet): LocalSchedule {
    const localId: number = rs.getLong(rs.getColumnIndex('local_id'));
    const serverId: number = rs.getLong(rs.getColumnIndex('id'));
    const syncStatus: number = rs.getLong(rs.getColumnIndex('sync_status'));
    const timestamp: string = rs.getString(rs.getColumnIndex('timestamp'));
    const type: string = rs.getString(rs.getColumnIndex('type'));
    const title: string = rs.getString(rs.getColumnIndex('title'));
    const beginTimeRaw: string = rs.getString(rs.getColumnIndex('begin_time'));
    const endTimeRaw: string = rs.getString(rs.getColumnIndex('end_time'));
    const location: string = rs.getString(rs.getColumnIndex('location'));
    const repeatRule: string = rs.getString(rs.getColumnIndex('repeat_rule'));
    const description: string = rs.getString(rs.getColumnIndex('description'));
    const finished: boolean = rs.getLong(rs.getColumnIndex('finished')) === 1;
    const archived: boolean = rs.getLong(rs.getColumnIndex('archived')) === 1;
    const syncFailed: boolean = rs.getLong(rs.getColumnIndex('sync_failed')) === 1;

    let beginTime: string[] = [];
    let endTime: string[] = [];
    try { beginTime = JSON.parse(beginTimeRaw) as string[]; } catch (_e) { beginTime = []; }
    try { endTime = JSON.parse(endTimeRaw) as string[]; } catch (_e) { endTime = []; }

    const content: ScheduleContent = {
      title: title,
      begin_time: beginTime,
      end_time: endTime,
      location: location,
      repeat: repeatRule,
      description: description
    };

    const local: LocalSchedule = {
      local_id: localId,
      sync_status: syncStatus,
      sync_failed: syncFailed,
      id: serverId,
      timestamp: timestamp,
      type: type,
      content: content,
      finished: finished,
      archived: archived
    };
    return local;
  }

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

  private nowTimestamp(): string {
    const d: Date = new Date();
    return d.getFullYear().toString() + '-' +
      this.pad(d.getMonth() + 1) + '-' +
      this.pad(d.getDate()) + ' ' +
      this.pad(d.getHours()) + ':' +
      this.pad(d.getMinutes()) + ':' +
      this.pad(d.getSeconds());
  }

  private pad(n: number): string {
    return n < 10 ? '0' + n.toString() : n.toString();
  }

  /**
   * Normalize a timestamp to 'YYYY-MM-DD HH:MM:SS' string for LWW comparison.
   * Handles both string and numeric (Unix seconds) formats from the backend.
   */
  normalizeTimestamp(ts: number | string | undefined): string {
    if (ts === undefined || ts === null) return '';
    if (typeof ts === 'string') return ts;
    // Numeric — treat as Unix seconds
    const d: Date = new Date(ts * 1000);
    return d.getFullYear().toString() + '-' +
      this.pad(d.getMonth() + 1) + '-' +
      this.pad(d.getDate()) + ' ' +
      this.pad(d.getHours()) + ':' +
      this.pad(d.getMinutes()) + ':' +
      this.pad(d.getSeconds());
  }

  // ==================== UI-Facing CRUD ====================

  /**
   * Get all visible schedules (sync_status != 3).
   * Used for "总日程" page.
   */
  async getAll(): Promise<LocalSchedule[]> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.notEqualTo('sync_status', SYNC_PENDING_DELETE);
    const rs: relationalStore.ResultSet = await store.query(predicates);
    const list: LocalSchedule[] = [];
    while (rs.goToNextRow()) {
      list.push(this.rowToLocal(rs));
    }
    rs.close();
    return list;
  }

  /**
   * Get pending (not finished, not archived, not soft-deleted) schedules.
   * Used for home page "待完成" list.
   */
  async getPending(): Promise<LocalSchedule[]> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.notEqualTo('sync_status', SYNC_PENDING_DELETE);
    predicates.equalTo('finished', 0);
    predicates.equalTo('archived', 0);
    const rs: relationalStore.ResultSet = await store.query(predicates);
    const list: LocalSchedule[] = [];
    while (rs.goToNextRow()) {
      list.push(this.rowToLocal(rs));
    }
    rs.close();
    return list;
  }

  /**
   * Get a single schedule by local_id.
   */
  async getByLocalId(localId: number): Promise<LocalSchedule | null> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('local_id', localId);
    const rs: relationalStore.ResultSet = await store.query(predicates);
    let result: LocalSchedule | null = null;
    if (rs.goToNextRow()) {
      result = this.rowToLocal(rs);
    }
    rs.close();
    return result;
  }

  /**
   * Get a single schedule by server id.
   */
  async getByServerId(serverId: number): Promise<LocalSchedule | null> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', serverId);
    const rs: relationalStore.ResultSet = await store.query(predicates);
    let result: LocalSchedule | null = null;
    if (rs.goToNextRow()) {
      result = this.rowToLocal(rs);
    }
    rs.close();
    return result;
  }

  /**
   * Insert a new schedule (offline-first).
   * Sets id = -1, sync_status = PENDING_CREATE.
   * Returns the local_id (SQLite rowId).
   */
  async insert(schedule: Schedule): Promise<number> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const ts: string = this.nowTimestamp();

    const bucket: relationalStore.ValuesBucket = {
      'id': -1,
      'sync_status': SYNC_PENDING_CREATE,
      'timestamp': ts,
      'type': schedule.type || 'todo',
      'title': schedule.content.title,
      'begin_time': JSON.stringify(schedule.content.begin_time),
      'end_time': JSON.stringify(schedule.content.end_time),
      'location': schedule.content.location || '',
      'repeat_rule': schedule.content.repeat || 'none',
      'description': schedule.content.description || '',
      'finished': 0,
      'archived': 0
    };

    const rowId: number = await store.insert(TABLE, bucket);
    console.info('DB_DEBUG: Inserted schedule, local_id=' + rowId);
    return rowId;
  }

  /**
   * Update an existing schedule by local_id.
   * sync_status transitions:
   *   - was SYNCED(0) → becomes PENDING_UPDATE(2)
   *   - was PENDING_CREATE(1) → stays PENDING_CREATE(1)
   *   - was PENDING_UPDATE(2) → stays PENDING_UPDATE(2)
   */
  async update(localId: number, schedule: Schedule): Promise<boolean> {
    const store: relationalStore.RdbStore = dbHelper.getStore();

    // Read current sync_status
    const readPred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    readPred.equalTo('local_id', localId);
    const rs: relationalStore.ResultSet = await store.query(readPred, ['sync_status']);
    let oldStatus: number = SYNC_SYNCED;
    if (rs.goToNextRow()) {
      oldStatus = rs.getLong(rs.getColumnIndex('sync_status'));
    }
    rs.close();

    // Determine new sync_status
    let newStatus: number;
    if (oldStatus === SYNC_PENDING_CREATE) {
      newStatus = SYNC_PENDING_CREATE;
    } else {
      newStatus = SYNC_PENDING_UPDATE;
    }

    const ts: string = this.nowTimestamp();
    const finishedVal: number = (schedule.finished === true) ? 1 : 0;
    const archivedVal: number = (schedule.archived === true || schedule.archive === true) ? 1 : 0;

    const bucket: relationalStore.ValuesBucket = {
      'sync_status': newStatus,
      'timestamp': ts,
      'type': schedule.type || 'todo',
      'title': schedule.content.title,
      'begin_time': JSON.stringify(schedule.content.begin_time),
      'end_time': JSON.stringify(schedule.content.end_time),
      'location': schedule.content.location || '',
      'repeat_rule': schedule.content.repeat || 'none',
      'description': schedule.content.description || '',
      'finished': finishedVal,
      'archived': archivedVal
    };

    const updatePred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    updatePred.equalTo('local_id', localId);
    const rows: number = await store.update(bucket, updatePred);
    console.info('DB_DEBUG: Updated local_id=' + localId + ', rows=' + rows + ', newStatus=' + newStatus);
    return rows > 0;
  }

  /**
   * Delete a schedule by local_id.
   * - If sync_status == PENDING_CREATE (never synced) → physical DELETE.
   * - Otherwise → soft delete (sync_status = PENDING_DELETE).
   */
  async delete(localId: number): Promise<boolean> {
    const store: relationalStore.RdbStore = dbHelper.getStore();

    // Read current sync_status
    const readPred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    readPred.equalTo('local_id', localId);
    const rs: relationalStore.ResultSet = await store.query(readPred, ['sync_status']);
    let oldStatus: number = SYNC_SYNCED;
    if (rs.goToNextRow()) {
      oldStatus = rs.getLong(rs.getColumnIndex('sync_status'));
    }
    rs.close();

    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);

    if (oldStatus === SYNC_PENDING_CREATE) {
      // Never synced → physical delete
      const rows: number = await store.delete(pred);
      console.info('DB_DEBUG: Physical delete local_id=' + localId + ', rows=' + rows);
      return rows > 0;
    } else {
      // Already synced → soft delete for server-side sync
      const bucket: relationalStore.ValuesBucket = {
        'sync_status': SYNC_PENDING_DELETE
      };
      const rows: number = await store.update(bucket, pred);
      console.info('DB_DEBUG: Soft delete local_id=' + localId + ', rows=' + rows);
      return rows > 0;
    }
  }

  /**
   * Mark a schedule as archived by local_id.
   * Follows the same sync_status transition as update().
   */
  async archive(localId: number): Promise<boolean> {
    const store: relationalStore.RdbStore = dbHelper.getStore();

    const readPred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    readPred.equalTo('local_id', localId);
    const rs: relationalStore.ResultSet = await store.query(readPred, ['sync_status']);
    let oldStatus: number = SYNC_SYNCED;
    if (rs.goToNextRow()) {
      oldStatus = rs.getLong(rs.getColumnIndex('sync_status'));
    }
    rs.close();

    let newStatus: number;
    if (oldStatus === SYNC_PENDING_CREATE) {
      newStatus = SYNC_PENDING_CREATE;
    } else {
      newStatus = SYNC_PENDING_UPDATE;
    }

    const bucket: relationalStore.ValuesBucket = {
      'archived': 1,
      'sync_status': newStatus,
      'timestamp': this.nowTimestamp()
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);
    const rows: number = await store.update(bucket, pred);
    console.info('DB_DEBUG: Archive local_id=' + localId + ', rows=' + rows);
    return rows > 0;
  }

  // ==================== SyncManager Helpers (Phase 2) ====================

  /** Get all records pending creation on server. */
  async getPendingCreates(): Promise<LocalSchedule[]> {
    return this.queryBySyncStatus(SYNC_PENDING_CREATE);
  }

  /** Get all records pending update on server. */
  async getPendingUpdates(): Promise<LocalSchedule[]> {
    return this.queryBySyncStatus(SYNC_PENDING_UPDATE);
  }

  /** Get all records pending deletion on server. */
  async getPendingDeletes(): Promise<LocalSchedule[]> {
    return this.queryBySyncStatus(SYNC_PENDING_DELETE);
  }

  /** After server confirms creation, write back the real server id and mark synced. */
  async updateServerId(localId: number, serverId: number): Promise<void> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {
      'id': serverId,
      'sync_status': SYNC_SYNCED
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);
    await store.update(bucket, pred);
    console.info('DB_DEBUG: updateServerId local_id=' + localId + ' → serverId=' + serverId);
  }

  /** Mark a record as synced. */
  async markSynced(localId: number): Promise<void> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {
      'sync_status': SYNC_SYNCED
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);
    await store.update(bucket, pred);
  }

  /** Physical delete after server confirms deletion. */
  async physicalDelete(localId: number): Promise<void> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);
    await store.delete(pred);
    console.info('DB_DEBUG: physicalDelete local_id=' + localId);
  }

  /**
   * Upsert a record from server data (pull sync) with LWW conflict resolution.
   *
   * Returns a merge verdict string for logging:
   *   'inserted'      — new record from server
   *   'updated'       — local was clean (status=0), overwritten with remote
   *   'lww_remote'    — conflict: remote timestamp wins, local overwritten
   *   'lww_local'     — conflict: local timestamp wins, kept local version
   *   'identical'     — timestamps match, no action needed
   */
  async upsertFromServer(schedule: Schedule): Promise<string> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const remoteTs: string = this.normalizeTimestamp(schedule.timestamp);

    // Look up existing local row by server id
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('id', schedule.id);
    const rs: relationalStore.ResultSet = await store.query(pred,
      ['local_id', 'sync_status', 'timestamp']);

    if (rs.goToNextRow()) {
      const existingLocalId: number = rs.getLong(rs.getColumnIndex('local_id'));
      const syncStatus: number = rs.getLong(rs.getColumnIndex('sync_status'));
      const localTs: string = rs.getString(rs.getColumnIndex('timestamp'));
      rs.close();

      if (syncStatus === SYNC_SYNCED) {
        // ── Case 1: Local not modified ──
        if (remoteTs === localTs) {
          return 'identical';
        }
        // Remote has a different (presumably newer) version → overwrite
        const bucket: relationalStore.ValuesBucket = this.scheduleToBucket(schedule, SYNC_SYNCED);
        bucket['sync_failed'] = 0;
        const updatePred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
        updatePred.equalTo('local_id', existingLocalId);
        await store.update(bucket, updatePred);
        console.info('LWW: Case1 overwrite id=' + schedule.id +
          ' localTs=' + localTs + ' remoteTs=' + remoteTs);
        return 'updated';
      } else {
        // ── Case 2: Both sides modified (local has pending changes) ──
        if (remoteTs > localTs) {
          // Remote is strictly newer → LWW: remote wins
          const bucket: relationalStore.ValuesBucket = this.scheduleToBucket(schedule, SYNC_SYNCED);
          bucket['sync_failed'] = 0;
          const updatePred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
          updatePred.equalTo('local_id', existingLocalId);
          await store.update(bucket, updatePred);
          console.info('LWW: Remote wins for id=' + schedule.id +
            ' localTs=' + localTs + ' remoteTs=' + remoteTs +
            ' oldStatus=' + syncStatus);
          return 'lww_remote';
        } else {
          // Local is same or newer → keep local, push next cycle
          console.info('LWW: Local wins for id=' + schedule.id +
            ' localTs=' + localTs + ' remoteTs=' + remoteTs);
          return 'lww_local';
        }
      }
    } else {
      rs.close();
      // New record from server — insert
      const bucket: relationalStore.ValuesBucket = this.scheduleToBucket(schedule, SYNC_SYNCED);
      bucket['id'] = schedule.id;
      bucket['sync_failed'] = 0;
      await store.insert(TABLE, bucket);
      console.info('LWW: Inserted new from server id=' + schedule.id);
      return 'inserted';
    }
  }

  /** Remove all locally-synced records (used before full pull). */
  async clearSynced(): Promise<void> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('sync_status', SYNC_SYNCED);
    await store.delete(pred);
  }

  // ==================== Failure Tracking ====================

  /** Mark a record as failed-to-sync (UI will show warning icon). */
  async markSyncFailed(localId: number): Promise<void> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const bucket: relationalStore.ValuesBucket = { 'sync_failed': 1 };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);
    await store.update(bucket, pred);
  }

  /** Clear the sync-failed flag (called on successful push). */
  async clearSyncFailed(localId: number): Promise<void> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const bucket: relationalStore.ValuesBucket = { 'sync_failed': 0 };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('local_id', localId);
    await store.update(bucket, pred);
  }

  // ==================== Aggregate Counts (for AppStatusStore) ====================

  /** Count records with sync_status != 0 (pending sync). */
  async getPendingCount(): Promise<number> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.notEqualTo('sync_status', SYNC_SYNCED);
    const rs: relationalStore.ResultSet = await store.query(pred, ['local_id']);
    const count: number = rs.rowCount;
    rs.close();
    return count;
  }

  /** Count records with sync_failed = 1. */
  async getFailedCount(): Promise<number> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('sync_failed', 1);
    const rs: relationalStore.ResultSet = await store.query(pred, ['local_id']);
    const count: number = rs.rowCount;
    rs.close();
    return count;
  }

  /** Convert a Schedule to a ValuesBucket (shared by insert-from-server and update-from-server). */
  private scheduleToBucket(s: Schedule, syncStatus: number): relationalStore.ValuesBucket {
    const finVal: number = (s.finished === true) ? 1 : 0;
    const archVal: number = (s.archived === true || s.archive === true) ? 1 : 0;
    const bucket: relationalStore.ValuesBucket = {
      'sync_status': syncStatus,
      'timestamp': this.normalizeTimestamp(s.timestamp),
      'type': s.type || 'todo',
      'title': s.content.title,
      'begin_time': JSON.stringify(s.content.begin_time),
      'end_time': JSON.stringify(s.content.end_time),
      'location': s.content.location || '',
      'repeat_rule': s.content.repeat || 'none',
      'description': s.content.description || '',
      'finished': finVal,
      'archived': archVal
    };
    return bucket;
  }

  // ==================== Private Helpers ====================

  private async queryBySyncStatus(status: number): Promise<LocalSchedule[]> {
    const store: relationalStore.RdbStore = dbHelper.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('sync_status', status);
    const rs: relationalStore.ResultSet = await store.query(pred);
    const list: LocalSchedule[] = [];
    while (rs.goToNextRow()) {
      list.push(this.rowToLocal(rs));
    }
    rs.close();
    return list;
  }
}

const scheduleRepository = new ScheduleRepository();
export default scheduleRepository;
