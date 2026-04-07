import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Schedule, ScheduleContent } from '../common/ScheduleModel';
import scheduleRepository, { LocalSchedule } from '../db/ScheduleRepository';
import syncManager from '../db/SyncManager';

interface RouterParams {
  local_id: number;
}

@Entry
@Component
struct ScheduleDetailPage {
  @State schedule: LocalSchedule | null = null;
  @State isLoading: boolean = true;
  @State isEditing: boolean = false;
  @State editTitle: string = '';
  @State editBeginTime: string = '';
  @State editEndTime: string = '';
  @State editLocation: string = '';
  @State editRepeat: string = 'none';
  @State editDescription: string = '';
  @State editType: string = 'todo';
  private localId: number = -1;

  aboutToAppear(): void {
    const params = router.getParams() as RouterParams;
    if (params && params.local_id) {
      this.localId = params.local_id;
      this.loadDetail();
    }
  }

  async loadDetail(): Promise<void> {
    this.isLoading = true;
    try {
      const local: LocalSchedule | null = await scheduleRepository.getByLocalId(this.localId);
      if (local) {
        this.schedule = local;
      } else {
        promptAction.showToast({ message: '日程不存在' });
      }
    } catch (err) {
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  startEdit(): void {
    if (!this.schedule) return;
    this.editTitle = this.schedule.content.title;
    this.editBeginTime = this.schedule.content.begin_time.join(' ');
    this.editEndTime = this.schedule.content.end_time.join(' ');
    this.editLocation = this.schedule.content.location;
    this.editRepeat = this.schedule.content.repeat;
    this.editDescription = this.schedule.content.description;
    this.editType = this.schedule.type;
    this.isEditing = true;
  }

  async handleSave(): Promise<void> {
    if (!this.schedule) return;
    try {
      const content: ScheduleContent = {
        title: this.editTitle,
        begin_time: this.timeToArr(this.editBeginTime),
        end_time: this.timeToArr(this.editEndTime),
        location: this.editLocation,
        repeat: this.editRepeat,
        description: this.editDescription
      };
      const updated: Schedule = {
        id: this.schedule.id,
        timestamp: this.schedule.timestamp,
        type: this.editType,
        content: content
      };
      const ok: boolean = await scheduleRepository.update(this.localId, updated);
      if (ok) {
        promptAction.showToast({ message: '更新成功' });
        this.isEditing = false;
        syncManager.refreshAppStatus();
        syncManager.sync();
        this.loadDetail();
      } else {
        promptAction.showToast({ message: '更新失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '更新失败' });
    }
  }

  async handleDelete(): Promise<void> {
    if (!this.schedule) return;
    try {
      const ok: boolean = await scheduleRepository.delete(this.localId);
      if (ok) {
        promptAction.showToast({ message: '已删除' });
        syncManager.refreshAppStatus();
        syncManager.sync();
        router.back();
      } else {
        promptAction.showToast({ message: '删除失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async handleArchive(): Promise<void> {
    if (!this.schedule) return;
    try {
      const ok: boolean = await scheduleRepository.archive(this.localId);
      if (ok) {
        promptAction.showToast({ message: '已归档完成' });
        syncManager.refreshAppStatus();
        syncManager.sync();
        router.back();
      } else {
        promptAction.showToast({ message: '归档失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '归档失败' });
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#007AFF')
          .onClick(() => { router.back(); })
        Text('日程详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1d1d1f')
          .margin({ left: 12 })
        Blank()
        if (!this.isEditing && this.schedule) {
          Text('编辑')
            .fontSize(16)
            .fontColor('#007AFF')
            .fontWeight(FontWeight.Medium)
            .onClick(() => { this.startEdit(); })
        }
      }
      .width('100%')
      .padding({ top: 12, bottom: 16 })

      if (this.isLoading) {
        Column() {
          Text('加载中...')
            .fontSize(16)
            .fontColor('#86868b')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width('100%')
      } else if (this.isEditing) {
        this.editView()
      } else if (this.schedule) {
        this.detailView()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 50 })
    .backgroundColor('#ffffff')
  }

  @Builder
  detailView() {
    Scroll() {
      Column() {
        // Type badge + Title
        Row() {
          Text(this.getTypeLabel(this.schedule!.type))
            .fontSize(12)
            .fontColor('#ffffff')
            .backgroundColor(this.getTypeColor(this.schedule!.type))
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .margin({ right: 10 })
          Text(this.schedule!.content.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1d1d1f')
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ bottom: 12 })

        // Sync Status Indicator
        if (this.schedule!.sync_failed) {
          Row() {
            Text('⚠️')
              .fontSize(14)
              .margin({ right: 6 })
            Text('同步失败，点击重试')
              .fontSize(13)
              .fontColor('#ffffff')
              .layoutWeight(1)
            Text('重试')
              .fontSize(13)
              .fontColor('#ffffff')
              .fontWeight(FontWeight.Medium)
              .decoration({ type: TextDecorationType.Underline })
              .onClick(() => {
                promptAction.showToast({ message: '正在重试同步...' });
                syncManager.sync().then(() => { this.loadDetail(); });
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FF3B30')
          .borderRadius(10)
          .margin({ bottom: 12 })
        } else if (this.schedule!.sync_status !== 0) {
          Row() {
            Text('☁️')
              .fontSize(14)
              .margin({ right: 6 })
            Text('待同步')
              .fontSize(13)
              .fontColor('#ffffff')
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FF9500')
          .borderRadius(10)
          .margin({ bottom: 12 })
        }

        // Info Card
        Column() {
          this.infoRow('🕐 开始时间', this.schedule!.content.begin_time.join(' ') || '未设置')
          Divider().color('#e5e5ea').margin({ top: 10, bottom: 10 })
          this.infoRow('🕑 结束时间', this.schedule!.content.end_time.join(' ') || '未设置')
          Divider().color('#e5e5ea').margin({ top: 10, bottom: 10 })
          this.infoRow('📍 地点', this.schedule!.content.location || '未设置')
          Divider().color('#e5e5ea').margin({ top: 10, bottom: 10 })
          this.infoRow('🔁 重复', this.getRepeatLabel(this.schedule!.content.repeat))
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#f5f5f7')
        .borderRadius(14)
        .margin({ bottom: 16 })

        // Description
        if (this.schedule!.content.description) {
          Column() {
            Text('备注')
              .fontSize(14)
              .fontColor('#86868b')
              .margin({ bottom: 6 })
            Text(this.schedule!.content.description)
              .fontSize(15)
              .fontColor('#3c3c43')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#f5f5f7')
          .borderRadius(14)
          .margin({ bottom: 24 })
          .alignItems(HorizontalAlign.Start)
        }

        // Action Buttons
        Button('✅ 标记完成')
          .type(ButtonType.Capsule)
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#34C759')
          .margin({ bottom: 12 })
          .onClick(() => { this.handleArchive(); })

        Button('🗑 删除日程')
          .type(ButtonType.Capsule)
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FF3B30')
          .backgroundColor('#f5f5f7')
          .onClick(() => { this.handleDelete(); })
      }
      .width('100%')
    }
    .layoutWeight(1)
  }

  @Builder
  editView() {
    Scroll() {
      Column() {
        Text('编辑日程')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1d1d1f')
          .width('100%')
          .margin({ bottom: 16 })

        this.editField('任务标题', this.editTitle, (v: string) => { this.editTitle = v; })
        this.editBeginTimeField()
        this.editEndTimeField()
        this.editField('地点', this.editLocation, (v: string) => { this.editLocation = v; })
        this.editField('描述', this.editDescription, (v: string) => { this.editDescription = v; })

        Row() {
          Button('取消')
            .type(ButtonType.Capsule)
            .height(44)
            .fontSize(15)
            .backgroundColor('#f5f5f7')
            .fontColor('#1d1d1f')
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => { this.isEditing = false; })

          Button('保存')
            .type(ButtonType.Capsule)
            .height(44)
            .fontSize(15)
            .backgroundColor('#007AFF')
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => { this.handleSave(); })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('100%')
    }
    .layoutWeight(1)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#3c3c43')
      Blank()
      Text(value)
        .fontSize(15)
        .fontColor('#86868b')
    }
    .width('100%')
  }

  private padZero(n: number): string {
    const num: number = Number(n);
    return num < 10 ? '0' + num.toString() : num.toString();
  }

  private timeToArr(s: string): string[] {
    const noSpaces: string = s.split(' ').join('');
    if (noSpaces.length >= 15) {
      const datePart: string = noSpaces.substring(0, 10);
      let timePart: string = noSpaces.substring(10);
      if (timePart.length === 5) {
        timePart = timePart + ':00';
      }
      return [datePart, timePart];
    }
    return [s, '00:00:00'];
  }

  @State private selectedDateStr: string = '';

  showEditBeginPicker(): void {
    DatePickerDialog.show({
      start: new Date('2020-1-1'),
      end: new Date('2030-12-31'),
      selected: new Date(),
      onAccept: (value: DatePickerResult) => {
        const y: number = Number(value.year ?? 2026);
        const m: number = Number(value.month ?? 0) + 1;
        const d: number = Number(value.day ?? 1);
        this.selectedDateStr = y.toString() + '-' + this.padZero(m) + '-' + this.padZero(d);
        this.showEditBeginTimePicker();
      }
    });
  }

  showEditBeginTimePicker(): void {
    TimePickerDialog.show({
      useMilitaryTime: true,
      selected: new Date(),
      onAccept: (value: TimePickerResult) => {
        const h: number = Number(value.hour ?? 8);
        const min: number = Number(value.minute ?? 0);
        const timeStr: string = this.padZero(h) + ':' + this.padZero(min) + ':00';
        this.editBeginTime = this.selectedDateStr + ' ' + timeStr;
      }
    });
  }

  showEditEndPicker(): void {
    DatePickerDialog.show({
      start: new Date('2020-1-1'),
      end: new Date('2030-12-31'),
      selected: new Date(),
      onAccept: (value: DatePickerResult) => {
        const y: number = Number(value.year ?? 2026);
        const m: number = Number(value.month ?? 0) + 1;
        const d: number = Number(value.day ?? 1);
        this.selectedDateStr = y.toString() + '-' + this.padZero(m) + '-' + this.padZero(d);
        this.showEditEndTimePicker();
      }
    });
  }

  showEditEndTimePicker(): void {
    TimePickerDialog.show({
      useMilitaryTime: true,
      selected: new Date(),
      onAccept: (value: TimePickerResult) => {
        const h: number = Number(value.hour ?? 8);
        const min: number = Number(value.minute ?? 0);
        const timeStr: string = this.padZero(h) + ':' + this.padZero(min) + ':00';
        this.editEndTime = this.selectedDateStr + ' ' + timeStr;
      }
    });
  }

  @Builder
  editBeginTimeField() {
    Column() {
      Text('开始时间')
        .fontSize(13)
        .fontColor('#86868b')
        .margin({ bottom: 4 })
      Row() {
        Text(this.editBeginTime || '点击选择日期时间')
          .fontSize(15)
          .fontColor(this.editBeginTime ? '#1d1d1f' : '#c7c7cc')
          .layoutWeight(1)
        Text('📅')
          .fontSize(18)
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor('#f5f5f7')
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.showEditBeginPicker(); })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  editEndTimeField() {
    Column() {
      Text('结束时间')
        .fontSize(13)
        .fontColor('#86868b')
        .margin({ bottom: 4 })
      Row() {
        Text(this.editEndTime || '点击选择日期时间')
          .fontSize(15)
          .fontColor(this.editEndTime ? '#1d1d1f' : '#c7c7cc')
          .layoutWeight(1)
        Text('📅')
          .fontSize(18)
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor('#f5f5f7')
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.showEditEndPicker(); })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  editField(label: string, value: string, onChange: (value: string) => void) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#86868b')
        .margin({ bottom: 4 })
      TextInput({ text: value, placeholder: label })
        .height(44)
        .width('100%')
        .borderRadius(10)
        .backgroundColor('#f5f5f7')
        .fontSize(15)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  getTypeLabel(type: string): string {
    if (type === 'meeting') return '会议';
    if (type === 'reminder') return '提醒';
    return '待办';
  }

  getTypeColor(type: string): string {
    if (type === 'meeting') return '#FF9500';
    if (type === 'reminder') return '#AF52DE';
    return '#007AFF';
  }

  getRepeatLabel(repeat: string): string {
    if (repeat === 'daily') return '每天';
    if (repeat === 'weekly') return '每周';
    if (repeat === 'monthly') return '每月';
    return '不重复';
  }
}
