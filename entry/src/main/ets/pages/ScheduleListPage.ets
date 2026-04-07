import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import scheduleRepository, { LocalSchedule } from '../db/ScheduleRepository';
import syncManager from '../db/SyncManager';

interface DetailParams {
  local_id: number;
}

interface DateGroup {
  date: string;
  items: LocalSchedule[];
}

@Entry
@Component
struct ScheduleListPage {
  @State schedules: LocalSchedule[] = [];
  @State groups: DateGroup[] = [];
  @State isLoading: boolean = false;
  @State filterType: string = 'pending';
  @State pageTitle: string = '待完成日程';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['filter']) {
      this.filterType = params['filter'];
    }
    if (this.filterType === 'all') {
      this.pageTitle = '全部日程';
    } else {
      this.pageTitle = '待完成日程';
    }
    this.loadData();
  }

  private isArchived(item: LocalSchedule): boolean {
    return item.archived === true;
  }

  private getEndTimeStr(item: LocalSchedule): string {
    if (item.content.end_time && item.content.end_time.length >= 2) {
      return item.content.end_time[0] + ' ' + item.content.end_time[1];
    }
    return '';
  }

  private getEndDateStr(item: LocalSchedule): string {
    if (item.content.end_time && item.content.end_time.length >= 1) {
      return item.content.end_time[0];
    }
    return '未知日期';
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

  private groupByDate(list: LocalSchedule[]): DateGroup[] {
    const sorted: LocalSchedule[] = this.sortByEndTime(list);
    const result: DateGroup[] = [];
    let currentDate: string = '';
    let currentItems: LocalSchedule[] = [];
    for (let i = 0; i < sorted.length; i++) {
      const d: string = this.getEndDateStr(sorted[i]);
      if (d !== currentDate) {
        if (currentItems.length > 0) {
          const group: DateGroup = { date: currentDate, items: currentItems };
          result.push(group);
        }
        currentDate = d;
        currentItems = [] as LocalSchedule[];
      }
      currentItems.push(sorted[i]);
    }
    if (currentItems.length > 0) {
      const group: DateGroup = { date: currentDate, items: currentItems };
      result.push(group);
    }
    return result;
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      let filtered: LocalSchedule[];
      if (this.filterType === 'all') {
        filtered = await scheduleRepository.getAll();
      } else {
        filtered = await scheduleRepository.getPending();
      }
      this.schedules = filtered;
      this.groups = this.groupByDate(filtered);
    } catch (err) {
      promptAction.showToast({ message: '加载数据失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleArchive(localId: number): Promise<void> {
    try {
      const ok: boolean = await scheduleRepository.archive(localId);
      if (ok) {
        promptAction.showToast({ message: '已标记完成' });
        syncManager.refreshAppStatus();
        syncManager.sync();
        await this.loadData();
      } else {
        promptAction.showToast({ message: '操作失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '操作失败' });
    }
  }

  private getTypeIcon(type: string): string {
    if (type === 'meeting') return '🤝';
    if (type === 'reminder') return '🔔';
    return '📋';
  }

  private getTypeBg(type: string): string {
    if (type === 'meeting') return '#fff3e0';
    if (type === 'reminder') return '#f3e5f5';
    return '#e3f2fd';
  }

  build() {
    Column() {
      // Top bar
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#007AFF')
          .onClick(() => { router.back(); })
          .margin({ right: 12 })
        Text(this.pageTitle)
          .fontSize(20)
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
      .margin({ bottom: 16 })

      if (this.schedules.length === 0 && !this.isLoading) {
        Column() {
          Text('📭')
            .fontSize(40)
            .margin({ bottom: 8 })
          Text('暂无日程')
            .fontSize(15)
            .fontColor('#86868b')
        }
        .width('100%')
        .padding({ top: 60 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.groups, (group: DateGroup) => {
              // Date header
              Row() {
                Text('📅 ' + group.date)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1d1d1f')
              }
              .width('100%')
              .margin({ top: 12, bottom: 8 })

              // Cards under this date
              ForEach(group.items, (item: LocalSchedule) => {
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
                          Text('⏰ ' + item.content.end_time.join(' '))
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

                    if (this.isArchived(item)) {
                      Text('✅')
                        .fontSize(18)
                    } else if (item.sync_failed) {
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

                  if (!this.isArchived(item) && item.finished !== true) {
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
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.isArchived(item) ? '#f0f0f0' : '#f5f5f7')
                .borderRadius(12)
                .opacity(this.isArchived(item) ? 0.7 : 1.0)
                .margin({ bottom: 8 })
                .onClick(() => {
                  const params: DetailParams = { local_id: item.local_id };
                  router.pushUrl({
                    url: 'pages/ScheduleDetailPage',
                    params: params
                  });
                })
              }, (item: LocalSchedule) => item.local_id.toString())
            }, (group: DateGroup) => group.date)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 54 })
  }
}
