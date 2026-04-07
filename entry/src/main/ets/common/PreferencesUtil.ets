import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

const PREFERENCES_NAME = 'user_auth_store';
const KEY_USERNAME = 'username';
const KEY_IS_LOGGED_IN = 'isLoggedIn';
const KEY_COOKIE = 'cookie';
const KEY_USER_ID = 'user_id';

class PreferencesUtil {
  private prefs: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    this.prefs = await preferences.getPreferences(context, PREFERENCES_NAME);
  }

  async saveLoginInfo(username: string, cookie: string, userId: string = ''): Promise<void> {
    if (!this.prefs) return;
    await this.prefs.put(KEY_USERNAME, username);
    await this.prefs.put(KEY_IS_LOGGED_IN, true);
    await this.prefs.put(KEY_COOKIE, cookie);
    await this.prefs.put(KEY_USER_ID, userId);
    await this.prefs.flush();
  }

  async getUsername(): Promise<string> {
    if (!this.prefs) return '';
    return (await this.prefs.get(KEY_USERNAME, '')) as string;
  }

  async isLoggedIn(): Promise<boolean> {
    if (!this.prefs) return false;
    return (await this.prefs.get(KEY_IS_LOGGED_IN, false)) as boolean;
  }

  async getCookie(): Promise<string> {
    if (!this.prefs) return '';
    return (await this.prefs.get(KEY_COOKIE, '')) as string;
  }

  async getUserId(): Promise<string> {
    if (!this.prefs) return '';
    return (await this.prefs.get(KEY_USER_ID, '')) as string;
  }

  async clearLoginInfo(): Promise<void> {
    if (!this.prefs) return;
    await this.prefs.delete(KEY_USERNAME);
    await this.prefs.delete(KEY_IS_LOGGED_IN);
    await this.prefs.delete(KEY_COOKIE);
    await this.prefs.delete(KEY_USER_ID);
    await this.prefs.flush();
  }
}

const preferencesUtil = new PreferencesUtil();
export default preferencesUtil;
