import { mediaquery } from '@kit.ArkUI';

/**
 * BreakpointUtil — 华为应用设计规范官方断点体系
 *
 * 断点定义（window width in vp）：
 *   xs : [0,   320)   —— 智能手表 / 超小屏
 *   sm : [320, 600)   —— 手机竖屏
 *   md : [600, 840)   —— 手机横屏 / 小折叠 / 平板竖屏
 *   lg : [840, 1440)  —— 平板横屏 / 2in1
 *   xl : [1440, ∞)    —— 大屏设备
 *
 * 用法：
 *   1. EntryAbility.onWindowStageCreate 中调用 breakpointUtil.register()
 *   2. 任意 @Component 中 @StorageProp('app_breakpoint') currentBp: string = 'sm'
 *   3. build() 中根据 currentBp 返回不同布局，或传入 GridRow 的 breakpoints
 */

export const BP_KEY: string = 'app_breakpoint';

interface BPEntry {
  query: string;
  bp: string;
}

class BreakpointUtil {
  private listeners: mediaquery.MediaQueryListener[] = [];
  private registered: boolean = false;

  register(): void {
    if (this.registered) return;
    AppStorage.setOrCreate<string>(BP_KEY, 'sm');

    const entries: BPEntry[] = [
      { query: '(width < 320vp)', bp: 'xs' },
      { query: '(320vp <= width) and (width < 600vp)', bp: 'sm' },
      { query: '(600vp <= width) and (width < 840vp)', bp: 'md' },
      { query: '(840vp <= width) and (width < 1440vp)', bp: 'lg' },
      { query: '(1440vp <= width)', bp: 'xl' }
    ];

    for (let i = 0; i < entries.length; i++) {
      const entry: BPEntry = entries[i];
      const bp: string = entry.bp;
      const listener: mediaquery.MediaQueryListener = mediaquery.matchMediaSync(entry.query);

      // Initial sync
      if (listener.matches) {
        AppStorage.set<string>(BP_KEY, bp);
      }

      const handler: (result: mediaquery.MediaQueryResult) => void =
        (result: mediaquery.MediaQueryResult) => {
          if (result.matches) {
            AppStorage.set<string>(BP_KEY, bp);
            console.info('BP_DEBUG: breakpoint changed -> ' + bp);
          }
        };
      listener.on('change', handler);
      this.listeners.push(listener);
    }
    this.registered = true;
    console.info('BP_DEBUG: BreakpointUtil registered');
  }

  unregister(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i].off('change');
      } catch (_e) {
        // ignore
      }
    }
    this.listeners = [];
    this.registered = false;
  }

  current(): string {
    return AppStorage.get<string>(BP_KEY) ?? 'sm';
  }

  isHandset(): boolean {
    const bp: string = this.current();
    return bp === 'xs' || bp === 'sm';
  }

  isTablet(): boolean {
    const bp: string = this.current();
    return bp === 'md' || bp === 'lg';
  }

  isLargeScreen(): boolean {
    const bp: string = this.current();
    return bp === 'lg' || bp === 'xl';
  }
}

const breakpointUtil = new BreakpointUtil();
export default breakpointUtil;
