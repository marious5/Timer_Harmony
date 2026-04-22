import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import preferencesUtil from '../common/PreferencesUtil';
import dynamicIconService from '../common/DynamicIconService';
import scheduleRepository, { LocalSchedule } from '../db/ScheduleRepository';
import syncManager from '../db/SyncManager';

interface DetailParams {
  local_id: number;
}

interface ListFilterParams {
  filter: string;
}

@Component
struct HomePage {
  @State username: string = '';
  @State schedules: LocalSchedule[] = [];
  @State pendingCount: number = 0;
  @State totalCount: number = 0;
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @StorageProp('app_isOffline') appIsOffline: boolean = false;
  @StorageProp('app_pendingSyncCount') appPendingCount: number = 0;
  @StorageProp('app_failedSyncCount') appFailedCount: number = 0;
  @StorageProp('app_breakpoint') currentBp: string = 'sm';
  @StorageProp('app_icon_level') currentIconLevel: string = 'default';

  aboutToAppear(): void {
    preferencesUtil.getUsername().then((name: string) => {
      this.username = name;
    });
    this.loadData();
  }

  private getEndTimeStr(item: LocalSchedule): string {
    if (item.content.end_time && item.content.end_time.length >= 2) {
      return item.content.end_time[0] + ' ' + item.content.end_time[1];
    }
    return '';
  }

  private sortByEndTime(list: LocalSchedule[]): LocalSchedule[] {
    const arr: LocalSchedule[] = list.slice();
    for (let i = 1; i < arr.length; i++) {
      const key: LocalSchedule = arr[i];
      const keyTime: string = this.getEndTimeStr(key);
      let j: number = i - 1;
      while (j >= 0 && this.getEndTimeStr(arr[j]) > keyTime) {
        arr[j + 1] = arr[j];
        j--;
      }
      arr[j + 1] = key;
    }
    return arr;
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const all: LocalSchedule[] = await scheduleRepository.getAll();
      this.totalCount = all.length;
      const pending: LocalSchedule[] = await scheduleRepository.getPending();
      this.pendingCount = pending.length;
      this.schedules = this.sortByEndTime(pending);
    } catch (err) {
      console.error('HomePage loadData error: ' + JSON.stringify(err));
      promptAction.showToast({ message: '加载数据失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleSync(): Promise<void> {
    this.isRefreshing = true;
    try {
      await syncManager.sync();
      await this.loadData();
      promptAction.showToast({ message: '同步完成' });
    } catch (err) {
      promptAction.showToast({ message: '同步失败' });
    } finally {
      this.isRefreshing = false;
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Column() {
          Text(`你好, ${this.username || '用户'} 👋`)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1d1d1f')
          Text('欢迎回来')
            .fontSize(14)
            .fontColor('#86868b')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 动态应用图标预览 —— @StorageProp 订阅 app_icon_level，
        // 随未完成日程数量（0 / 1-3 / 4-7 / ≥8）自动切换四档 PNG
        Image(dynamicIconService.getResourceForLevel(this.currentIconLevel))
          .width(40)
          .height(40)
          .borderRadius(10)
          .margin({ right: 12 })

        Text(this.isRefreshing ? '⏳' : '🔄')
          .fontSize(22)
          .onClick(() => { this.handleSync(); })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // Offline / Sync Status Banner
      if (this.appIsOffline || this.appPendingCount > 0 || this.appFailedCount > 0) {
        Row() {
          Text(this.appIsOffline ? '📡' : (this.appFailedCount > 0 ? '⚠️' : '☁️'))
            .fontSize(14)
            .margin({ right: 6 })
          Text(this.getBannerText())
            .fontSize(13)
            .fontColor('#ffffff')
            .layoutWeight(1)
          if (this.appFailedCount > 0 && !this.isRefreshing) {
            Text('重试')
              .fontSize(13)
              .fontColor('#ffffff')
              .fontWeight(FontWeight.Medium)
              .decoration({ type: TextDecorationType.Underline })
              .onClick(() => { this.handleSync(); })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(this.appIsOffline ? '#FF9500' : (this.appFailedCount > 0 ? '#FF3B30' : '#007AFF'))
        .borderRadius(10)
        .margin({ bottom: 12 })
      }

      // Stats Card — 响应式栅格（遵循华为应用设计规范）
      //   xs(手表): 2 卡单列堆叠   sm(手机): 并排   md/lg(平板/2in1): 并排带更大间距
      GridRow({
        columns: 2,
        gutter: { x: 12, y: 12 },
        breakpoints: {
          value: ['320vp', '600vp', '840vp', '1440vp'],
          reference: BreakpointsReference.WindowSize
        }
      }) {
        GridCol({ span: { xs: 2, sm: 1, md: 1, lg: 1, xl: 1 } }) {
          Column() {
            Text('待完成')
              .fontSize(13)
              .fontColor('#86868b')
            Text(this.pendingCount.toString())
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#007AFF')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 16, bottom: 16 })
          .backgroundColor('#f5f5f7')
          .borderRadius(14)
          .onClick(() => {
            const p: ListFilterParams = { filter: 'pending' };
            router.pushUrl({ url: 'pages/ScheduleListPage', params: p });
          })
        }

        GridCol({ span: { xs: 2, sm: 1, md: 1, lg: 1, xl: 1 } }) {
          Column() {
            Text('总日程')
              .fontSize(13)
              .fontColor('#86868b')
            Text(this.totalCount.toString())
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF9500')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 16, bottom: 16 })
          .backgroundColor('#f5f5f7')
          .borderRadius(14)
          .onClick(() => {
            const p: ListFilterParams = { filter: 'all' };
            router.pushUrl({ url: 'pages/ScheduleListPage', params: p });
          })
        }
      }
      .width('100%')
      .margin({ bottom: 16 })

      // Schedule List Header
      Row() {
        Text('待办日程')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1d1d1f')
        Blank()
        if (this.isLoading) {
          Text('加载中...')
            .fontSize(13)
            .fontColor('#86868b')
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      // Schedule List
      if (this.schedules.length === 0 && !this.isLoading) {
        Column() {
          Text('📭')
            .fontSize(40)
            .margin({ bottom: 8 })
          Text('暂无待办日程')
            .fontSize(15)
            .fontColor('#86868b')
        }
        .width('100%')
        .padding({ top: 40 })
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.schedules, (item: LocalSchedule) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(this.getTypeIcon(item.type))
                      .fontSize(20)
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(20)
                  .backgroundColor(this.getTypeBg(item.type))
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .margin({ right: 12 })

                  Column() {
                    Text(item.content.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1d1d1f')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row() {
                      if (item.content.end_time && item.content.end_time.length > 0) {
                        Text('⏰ 截止: ' + item.content.end_time.join(' '))
                          .fontSize(12)
                          .fontColor('#FF9500')
                          .margin({ right: 10 })
                      }
                      if (item.content.location) {
                        Text('📍 ' + item.content.location)
                          .fontSize(12)
                          .fontColor('#86868b')
                      }
                    }
                    .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (item.sync_failed) {
                    Text('⚠️')
                      .fontSize(16)
                  } else if (item.sync_status !== 0) {
                    Text('☁️')
                      .fontSize(14)
                      .opacity(0.6)
                  } else {
                    Text('›')
                      .fontSize(20)
                      .fontColor('#c7c7cc')
                  }
                }
                .width('100%')

                Row() {
                  if (item.sync_failed) {
                    Text('⚠️ 同步失败')
                      .fontSize(12)
                      .fontColor('#FF3B30')
                  } else if (item.sync_status !== 0) {
                    Text('☁️ 待同步')
                      .fontSize(12)
                      .fontColor('#FF9500')
                  }
                  Blank()
                  if (item.sync_failed) {
                    Button('重试同步')
                      .type(ButtonType.Capsule)
                      .height(30)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .backgroundColor('#FF3B30')
                      .fontColor('#ffffff')
                      .margin({ right: 8 })
                      .onClick(() => {
                        promptAction.showToast({ message: '正在重试同步...' });
                        syncManager.sync().then(() => { this.loadData(); });
                      })
                  }
                  Button('已完成')
                    .type(ButtonType.Capsule)
                    .height(30)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .backgroundColor('#34C759')
                    .fontColor('#ffffff')
                    .onClick((event: ClickEvent) => {
                      this.handleArchive(item.local_id);
                    })
                }
                .width('100%')
                .margin({ top: 8 })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#f5f5f7')
              .borderRadius(12)
              .onClick(() => {
                const params: DetailParams = { local_id: item.local_id };
                router.pushUrl({
                  url: 'pages/ScheduleDetailPage',
                  params: params
                });
              })
            }
          }, (item: LocalSchedule) => item.local_id.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.sidePadding(), right: this.sidePadding(), top: 54 })
  }

  /**
   * 华为设计规范推荐的响应式两侧留白：
   *   xs 10vp / sm 20vp / md 48vp / lg 80vp / xl 120vp
   * 大屏设备上通过加大 padding 实现内容居中收束（避免超宽阅读疲劳）。
   */
  private sidePadding(): number {
    if (this.currentBp === 'xs') return 10;
    if (this.currentBp === 'sm') return 20;
    if (this.currentBp === 'md') return 48;
    if (this.currentBp === 'lg') return 80;
    return 120;
  }

  async handleArchive(localId: number): Promise<void> {
    try {
      const ok: boolean = await scheduleRepository.archive(localId);
      if (ok) {
        promptAction.showToast({ message: '已标记完成' });
        await this.loadData();
        // Refresh status counts immediately, then background sync
        syncManager.refreshAppStatus();
        syncManager.sync();
      } else {
        promptAction.showToast({ message: '操作失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '操作失败' });
    }
  }

  private getBannerText(): string {
    if (this.appIsOffline) {
      if (this.appPendingCount > 0) {
        return '当前处于离线模式，有 ' + this.appPendingCount + ' 项修改待同步';
      }
      return '当前处于离线模式';
    }
    if (this.appFailedCount > 0) {
      return this.appFailedCount + ' 项同步失败，点击重试';
    }
    return this.appPendingCount + ' 项修改待同步';
  }

  getTypeIcon(type: string): string {
    if (type === 'meeting') return '🤝';
    if (type === 'reminder') return '🔔';
    return '📋';
  }

  getTypeBg(type: string): string {
    if (type === 'meeting') return '#fff3e0';
    if (type === 'reminder') return '#f3e5f5';
    return '#e3f2fd';
  }
}

@Component
struct ProfilePage {
  @State username: string = '';

  aboutToAppear(): void {
    preferencesUtil.getUsername().then((name) => {
      this.username = name;
    });
  }

  handleLogout(): void {
    preferencesUtil.clearLoginInfo().then(() => {
      promptAction.showToast({ message: '已退出登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
    });
  }

  build() {
    Column() {
      // Avatar
      Column() {
        Text(this.username ? this.username.charAt(0).toUpperCase() : 'U')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
      }
      .width(90)
      .height(90)
      .borderRadius(45)
      .backgroundColor('#007AFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 60, bottom: 16 })

      Text(this.username || '用户')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1d1d1f')
        .margin({ bottom: 40 })

      // Menu items
      Column() {
        this.menuItem('账号设置', '#007AFF')
        Divider().color('#e5e5ea').margin({ left: 16, right: 16 })
        this.menuItem('隐私与安全', '#34C759')
        Divider().color('#e5e5ea').margin({ left: 16, right: 16 })
        this.menuItem('关于应用', '#FF9500')
      }
      .width('100%')
      .backgroundColor('#f5f5f7')
      .borderRadius(16)
      .margin({ bottom: 32 })

      Button('退出登录')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(50)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FF3B30')
        .backgroundColor('#f5f5f7')
        .onClick(() => {
          this.handleLogout();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  menuItem(title: string, color: string) {
    Row() {
      Circle({ width: 10, height: 10 })
        .fill(color)
        .margin({ right: 12 })
      Text(title)
        .fontSize(16)
        .fontColor('#1d1d1f')
      Blank()
      Text('›')
        .fontSize(22)
        .fontColor('#c7c7cc')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@Component
struct CreateTab {
  build() {
    Column() {
      Text('➕')
        .fontSize(40)
        .margin({ bottom: 12 })
      Text('创建新待办')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1d1d1f')
        .margin({ bottom: 6 })
      Text('点击下方按钮进入创建页面')
        .fontSize(14)
        .fontColor('#86868b')
        .margin({ bottom: 32 })

      Button('开始创建')
        .type(ButtonType.Capsule)
        .width(200)
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#007AFF')
        .onClick(() => {
          router.pushUrl({ url: 'pages/CreateSchedulePage' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct MainPage {
  @State currentIndex: number = 0;

  @Builder
  tabBarBuilder(title: string, targetIndex: number, iconText: string) {
    Column() {
      Text(iconText)
        .fontSize(22)
      Text(title)
        .fontSize(11)
        .fontColor(this.currentIndex === targetIndex ? '#007AFF' : '#8e8e93')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.tabBarBuilder('首页', 0, '🏠'))

      TabContent() {
        CreateTab()
      }
      .tabBar(this.tabBarBuilder('创建待办', 1, '➕'))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.tabBarBuilder('我的', 2, '👤'))
    }
    .barHeight(56)
    .barBackgroundColor('#f9f9f9')
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}
