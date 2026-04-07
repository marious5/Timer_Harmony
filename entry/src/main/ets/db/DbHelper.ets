import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

const DB_NAME = 'smart_schedule.db';

const CREATE_TABLE_SCHEDULE: string =
  'CREATE TABLE IF NOT EXISTS schedule (' +
  'local_id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'id INTEGER DEFAULT -1, ' +
  'sync_status INTEGER DEFAULT 1, ' +
  'timestamp TEXT, ' +
  'type TEXT DEFAULT \'todo\', ' +
  'title TEXT NOT NULL DEFAULT \'\', ' +
  'begin_time TEXT DEFAULT \'[]\', ' +
  'end_time TEXT DEFAULT \'[]\', ' +
  'location TEXT DEFAULT \'\', ' +
  'repeat_rule TEXT DEFAULT \'none\', ' +
  'description TEXT DEFAULT \'\', ' +
  'finished INTEGER DEFAULT 0, ' +
  'archived INTEGER DEFAULT 0, ' +
  'sync_failed INTEGER DEFAULT 0' +
  ')';

class DbHelper {
  private rdbStore: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;

  async init(context: Context): Promise<void> {
    if (this.initialized && this.rdbStore !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.rdbStore = await relationalStore.getRdbStore(context, config);
    await this.rdbStore.executeSql(CREATE_TABLE_SCHEDULE);
    // Migration: add sync_failed column if upgrading from older schema
    try {
      await this.rdbStore.executeSql('ALTER TABLE schedule ADD COLUMN sync_failed INTEGER DEFAULT 0');
    } catch (_e) {
      // Column already exists — safe to ignore
    }
    this.initialized = true;
    console.info('DB_DEBUG: DbHelper initialized, table created.');
  }

  getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('DbHelper not initialized. Call init(context) first.');
    }
    return this.rdbStore;
  }

  isReady(): boolean {
    return this.initialized && this.rdbStore !== null;
  }
}

const dbHelper = new DbHelper();
export default dbHelper;
