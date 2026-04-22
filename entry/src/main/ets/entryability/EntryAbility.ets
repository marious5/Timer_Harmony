import { AbilityConstant, ConfigurationConstant, UIAbility, Want, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import preferencesUtil from '../common/PreferencesUtil';
import httpUtil from '../common/HttpUtil';
import breakpointUtil from '../common/BreakpointUtil';
import dynamicIconService from '../common/DynamicIconService';
import dbHelper from '../db/DbHelper';
import syncManager from '../db/SyncManager';
import appStatusStore from '../db/AppStatusStore';
import distributedSyncManager from '../db/DistributedSyncManager';

const DOMAIN = 0x0000;
const BUNDLE_NAME: string = 'com.example.myapplication';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    syncManager.stopNetworkMonitor();
    breakpointUtil.unregister();
    distributedSyncManager.close();
  }

  /** 请求分布式数据同步权限（user_grant 必须运行时申请） */
  private async requestDistributedPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const perms: Permissions[] = ['ohos.permission.DISTRIBUTED_DATASYNC'];
      const res = await atManager.requestPermissionsFromUser(this.context, perms);
      const granted: boolean = res.authResults.length > 0 && res.authResults[0] === 0;
      hilog.info(DOMAIN, 'testTag', 'DISTRIBUTED_DATASYNC granted=%{public}s', granted.toString());
      return granted;
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'requestPermission failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 1. 注册栅格断点监听（所有设备立即生效，独立于登录态）
    breakpointUtil.register();

    preferencesUtil.init(this.context).then(async () => {
      // Initialize global status store + local database
      appStatusStore.init();
      await dbHelper.init(this.context);
      const loggedIn = await preferencesUtil.isLoggedIn();
      let targetPage = 'pages/LoginPage';
      if (loggedIn) {
        await httpUtil.loadCookie(); // loads both cookie and userId
        syncManager.startNetworkMonitor();
        targetPage = 'pages/MainPage';
      }
      windowStage.loadContent(targetPage, (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });

      // 3. 登录态下异步启动分布式软总线（不阻塞首屏渲染）
      //    权限弹窗不阻塞 loadContent，用户同意后分布式通道才生效，拒绝则降级为纯端云同步
      if (loggedIn) {
        this.setupDistributedSync();
      }

      // 4. 启动诊断：打印 AGC 上已注册的动态图标列表，方便核对 ICON_ID_MAP 配置
      //    真机+已上架才有数据，模拟器或未上架会 catch 住并 warn，不影响主流程
      dynamicIconService.queryAvailableIcons();
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to init preferences. Cause: %{public}s', JSON.stringify(err));
      windowStage.loadContent('pages/LoginPage');
    });
  }

  /** 异步初始化分布式软总线（fire-and-forget，不阻塞 UI） */
  private async setupDistributedSync(): Promise<void> {
    const granted: boolean = await this.requestDistributedPermission();
    if (!granted) {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Distributed permission denied, fallback to cloud-only sync');
      return;
    }
    await distributedSyncManager.init(this.context, BUNDLE_NAME);
    distributedSyncManager.setRemoteChangeHandler(() => {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Remote change → triggering sync');
      syncManager.sync();
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}