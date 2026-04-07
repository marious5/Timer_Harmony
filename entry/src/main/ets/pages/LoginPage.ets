import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import httpUtil from '../common/HttpUtil';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State isLoginMode: boolean = true;

  async handleSubmit(): Promise<void> {
    if (!this.username.trim() || !this.password.trim()) {
      promptAction.showToast({ message: '请输入用户名和密码' });
      return;
    }
    this.isLoading = true;
    try {
      if (this.isLoginMode) {
        const res = await httpUtil.login(this.username, this.password);
        if (res.success) {
          promptAction.showToast({ message: '登录成功' });
          router.replaceUrl({ url: 'pages/MainPage' });
        } else {
          promptAction.showToast({ message: res.error || '登录失败' });
        }
      } else {
        const res = await httpUtil.register(this.username, this.password);
        if (res.success) {
          promptAction.showToast({ message: '注册成功，请登录' });
          this.isLoginMode = true;
        } else {
          promptAction.showToast({ message: res.error || '注册失败' });
        }
      }
    } catch (err) {
      promptAction.showToast({ message: '网络错误，请稍后重试' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // Logo area
      Column() {
        Image($r('app.media.startIcon'))
          .width(80)
          .height(80)
          .borderRadius(16)
          .margin({ bottom: 12 })

        Text('欢迎使用')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1d1d1f')

        Text(this.isLoginMode ? '登录你的账号' : '创建新账号')
          .fontSize(14)
          .fontColor('#86868b')
          .margin({ top: 6 })
      }
      .margin({ top: 80, bottom: 48 })
      .alignItems(HorizontalAlign.Center)

      // Form area
      Column() {
        TextInput({ placeholder: '用户名', text: this.username })
          .type(InputType.Normal)
          .height(50)
          .width('100%')
          .borderRadius(12)
          .backgroundColor('#f5f5f7')
          .padding({ left: 16, right: 16 })
          .fontSize(16)
          .onChange((value: string) => {
            this.username = value;
          })

        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password)
          .height(50)
          .width('100%')
          .borderRadius(12)
          .backgroundColor('#f5f5f7')
          .padding({ left: 16, right: 16 })
          .fontSize(16)
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.password = value;
          })

        Button(this.isLoading ? '请稍候...' : (this.isLoginMode ? '登 录' : '注 册'))
          .type(ButtonType.Capsule)
          .width('100%')
          .height(50)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#007AFF')
          .margin({ top: 32 })
          .enabled(!this.isLoading)
          .onClick(() => {
            this.handleSubmit();
          })

        Row() {
          Text(this.isLoginMode ? '没有账号？' : '已有账号？')
            .fontSize(14)
            .fontColor('#86868b')

          Text(this.isLoginMode ? '立即注册' : '返回登录')
            .fontSize(14)
            .fontColor('#007AFF')
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              this.isLoginMode = !this.isLoginMode;
            })
        }
        .margin({ top: 20 })
        .justifyContent(FlexAlign.Center)
      }
      .padding({ left: 32, right: 32 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}
