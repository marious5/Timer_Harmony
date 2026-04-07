import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import httpUtil from '../common/HttpUtil';
import { Schedule, ScheduleContent } from '../common/ScheduleModel';
import scheduleRepository from '../db/ScheduleRepository';
import syncManager from '../db/SyncManager';

interface AIParseResult {
  title: string;
  begin_time: string;
  end_time: string;
  location: string;
  repeat: string;
  description: string;
  type: string;
}

interface RouterParams {
  local_id: number;
}

@Entry
@Component
struct CreateSchedulePage {
  @State aiInput: string = '';
  @State isParsing: boolean = false;
  @State isSubmitting: boolean = false;
  @State title: string = '';
  @State beginTime: string = '';
  @State endTime: string = '';
  @State location: string = '';
  @State repeat: string = 'none';
  @State description: string = '';
  @State scheduleType: string = 'todo';

  async handleAIParse(): Promise<void> {
    if (!this.aiInput.trim()) {
      promptAction.showToast({ message: '请输入待办描述' });
      return;
    }
    this.isParsing = true;
    try {
      const raw: string = await httpUtil.parseWithAI(this.aiInput);
      const cleaned: string = raw.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      const parsed: AIParseResult = JSON.parse(cleaned) as AIParseResult;
      this.title = parsed.title || '';
      this.beginTime = parsed.begin_time || '';
      this.endTime = parsed.end_time || '';
      this.location = parsed.location || '';
      this.repeat = parsed.repeat || 'none';
      this.description = parsed.description || '';
      this.scheduleType = parsed.type || 'todo';
      promptAction.showToast({ message: 'AI 解析完成' });
    } catch (err) {
      promptAction.showToast({ message: 'AI 解析失败，请手动填写' });
    } finally {
      this.isParsing = false;
    }
  }

  async handleCreate(): Promise<void> {
    if (!this.title.trim()) {
      promptAction.showToast({ message: '请填写任务标题' });
      return;
    }
    this.isSubmitting = true;
    try {
      const content: ScheduleContent = {
        title: this.title,
        begin_time: this.timeToArr(this.beginTime),
        end_time: this.timeToArr(this.endTime),
        location: this.location,
        repeat: this.repeat,
        description: this.description
      };
      const schedule: Schedule = {
        id: -1,
        timestamp: Math.floor(Date.now() / 1000),
        type: this.scheduleType,
        content: content
      };
      // Write to local DB (offline-first)
      const localId: number = await scheduleRepository.insert(schedule);
      if (localId > 0) {
        promptAction.showToast({ message: '创建成功' });
        // Refresh status counts immediately, then background sync
        syncManager.refreshAppStatus();
        syncManager.sync();
        const params: RouterParams = { local_id: localId };
        router.replaceUrl({
          url: 'pages/ScheduleDetailPage',
          params: params
        });
      } else {
        promptAction.showToast({ message: '创建失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '创建失败' });
    } finally {
      this.isSubmitting = false;
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
        Text('创建待办')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1d1d1f')
          .margin({ left: 12 })
        Blank()
      }
      .width('100%')
      .padding({ top: 12, bottom: 16 })

      Scroll() {
        Column() {
          // AI Parse Section
          Column() {
            Text('✨ AI 智能解析')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#007AFF')
              .width('100%')
              .margin({ bottom: 10 })

            TextArea({ placeholder: '输入一段话描述你的待办，例如："明天下午3点在会议室开项目评审会，预计1小时"', text: this.aiInput })
              .height(100)
              .width('100%')
              .borderRadius(10)
              .backgroundColor('#ffffff')
              .fontSize(14)
              .onChange((value: string) => { this.aiInput = value; })

            Button(this.isParsing ? '解析中...' : 'AI 解析填入')
              .type(ButtonType.Capsule)
              .width('100%')
              .height(40)
              .fontSize(15)
              .backgroundColor('#007AFF')
              .margin({ top: 10 })
              .enabled(!this.isParsing)
              .onClick(() => { this.handleAIParse(); })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#f0f6ff')
          .borderRadius(14)
          .margin({ bottom: 20 })

          // Form Section
          Column() {
            Text('📝 待办信息')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1d1d1f')
              .width('100%')
              .margin({ bottom: 14 })

            this.formField('任务标题', this.title, (v: string) => { this.title = v; })
            this.beginTimeField()
            this.endTimeField()
            this.formField('地点', this.location, (v: string) => { this.location = v; })
            this.formField('描述', this.description, (v: string) => { this.description = v; })

            // Type Selector
            Row() {
              Text('类型')
                .fontSize(14)
                .fontColor('#86868b')
                .width(90)
              Row() {
                this.typeChip('todo', '待办')
                this.typeChip('meeting', '会议')
                this.typeChip('reminder', '提醒')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })

            // Repeat Selector
            Row() {
              Text('重复')
                .fontSize(14)
                .fontColor('#86868b')
                .width(90)
              Row() {
                this.repeatChip('none', '不重复')
                this.repeatChip('daily', '每天')
                this.repeatChip('weekly', '每周')
                this.repeatChip('monthly', '每月')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#f5f5f7')
          .borderRadius(14)
          .margin({ bottom: 24 })

          // Submit Button
          Button(this.isSubmitting ? '提交中...' : '创建日程')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#34C759')
            .enabled(!this.isSubmitting)
            .onClick(() => { this.handleCreate(); })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 50 })
    .backgroundColor('#ffffff')
  }

  @Builder
  formField(label: string, value: string, onChange: (value: string) => void) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#86868b')
        .margin({ bottom: 4 })
      TextInput({ text: value, placeholder: label })
        .height(44)
        .width('100%')
        .borderRadius(10)
        .backgroundColor('#ffffff')
        .fontSize(15)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  private padZero(n: number): string {
    const num: number = Number(n);
    return num < 10 ? '0' + num.toString() : num.toString();
  }

  private timeToArr(s: string): string[] {
    // Convert display string 'YYYY-MM-DD HH:MM:SS' to backend array ['YYYY-MM-DD', 'HH:MM:SS']
    // First strip all extra spaces (ArkTS DatePicker quirk)
    const noSpaces: string = s.split(' ').join('');
    // noSpaces = 'YYYY-MM-DDHH:MM:SS' or 'YYYY-MM-DDHH:MM'
    if (noSpaces.length >= 15) {
      const datePart: string = noSpaces.substring(0, 10);
      let timePart: string = noSpaces.substring(10);
      if (timePart.length === 5) {
        timePart = timePart + ':00';
      }
      return [datePart, timePart];
    }
    // Fallback for empty or short strings
    return [s, '00:00:00'];
  }

  @Builder
  beginTimeField() {
    Column() {
      Text('开始时间')
        .fontSize(13)
        .fontColor('#86868b')
        .margin({ bottom: 4 })
      Row() {
        Text(this.beginTime || '点击选择日期时间')
          .fontSize(15)
          .fontColor(this.beginTime ? '#1d1d1f' : '#c7c7cc')
          .layoutWeight(1)
        Text('📅')
          .fontSize(18)
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor('#ffffff')
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.showBeginPicker(); })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  endTimeField() {
    Column() {
      Text('结束时间')
        .fontSize(13)
        .fontColor('#86868b')
        .margin({ bottom: 4 })
      Row() {
        Text(this.endTime || '点击选择日期时间')
          .fontSize(15)
          .fontColor(this.endTime ? '#1d1d1f' : '#c7c7cc')
          .layoutWeight(1)
        Text('📅')
          .fontSize(18)
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor('#ffffff')
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.showEndPicker(); })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @State private selectedDateStr: string = '';

  showBeginPicker(): void {
    DatePickerDialog.show({
      start: new Date('2020-1-1'),
      end: new Date('2030-12-31'),
      selected: new Date(),
      onAccept: (value: DatePickerResult) => {
        const y: number = Number(value.year ?? 2026);
        const m: number = Number(value.month ?? 0) + 1;
        const d: number = Number(value.day ?? 1);
        this.selectedDateStr = y.toString() + '-' + this.padZero(m) + '-' + this.padZero(d);
        this.showBeginTimePicker();
      }
    });
  }

  showBeginTimePicker(): void {
    TimePickerDialog.show({
      useMilitaryTime: true,
      selected: new Date(),
      onAccept: (value: TimePickerResult) => {
        const h: number = Number(value.hour ?? 8);
        const min: number = Number(value.minute ?? 0);
        const timeStr: string = this.padZero(h) + ':' + this.padZero(min) + ':00';
        this.beginTime = this.selectedDateStr + ' ' + timeStr;
      }
    });
  }

  showEndPicker(): void {
    DatePickerDialog.show({
      start: new Date('2020-1-1'),
      end: new Date('2030-12-31'),
      selected: new Date(),
      onAccept: (value: DatePickerResult) => {
        const y: number = Number(value.year ?? 2026);
        const m: number = Number(value.month ?? 0) + 1;
        const d: number = Number(value.day ?? 1);
        this.selectedDateStr = y.toString() + '-' + this.padZero(m) + '-' + this.padZero(d);
        this.showEndTimePicker();
      }
    });
  }

  showEndTimePicker(): void {
    TimePickerDialog.show({
      useMilitaryTime: true,
      selected: new Date(),
      onAccept: (value: TimePickerResult) => {
        const h: number = Number(value.hour ?? 8);
        const min: number = Number(value.minute ?? 0);
        const timeStr: string = this.padZero(h) + ':' + this.padZero(min) + ':00';
        this.endTime = this.selectedDateStr + ' ' + timeStr;
      }
    });
  }

  @Builder
  typeChip(type: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.scheduleType === type ? '#ffffff' : '#007AFF')
      .backgroundColor(this.scheduleType === type ? '#007AFF' : '#e8f0fe')
      .borderRadius(14)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .onClick(() => { this.scheduleType = type; })
  }

  @Builder
  repeatChip(val: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.repeat === val ? '#ffffff' : '#34C759')
      .backgroundColor(this.repeat === val ? '#34C759' : '#e8f8ed')
      .borderRadius(14)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .margin({ right: 6 })
      .onClick(() => { this.repeat = val; })
  }
}
