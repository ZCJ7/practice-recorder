# Practice Recorder

练习录像助手 MVP —— 帮你在练琴 / 唱歌 / 舞蹈时快速筛选录像、维护当前最佳版本，练习结束一键清理废片。

## 功能（MVP 1.0 + V1.1）

- Session 练习会话
- 系统相机录制（前后摄）
- 录制后 3 秒决策：最佳 / 保留 / 删除
- 对比当前最佳（A/B 切换）
- 备注
- 练习总结 + 批量清理废片
- **V1.1**：练习主页「⇄ 与下一次录制对比」

## 技术栈

- Flutter + Riverpod
- SQLite（sqflite）
- camera / video_player / gal

## 本地运行

```bash
# 建议使用国内镜像
setx PUB_HOSTED_URL "https://pub.flutter-io.cn"
setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"

flutter pub get
flutter run
```

## 打 APK

本机若已安装 Android SDK：

```bash
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

也可在 GitHub Actions 中构建：推送代码后，在仓库 Actions 页手动运行 **Build APK** workflow，再下载 artifact。

### 环境变量（国内网络建议）

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

Flutter SDK 可放在 `C:\Users\<you>\devtools\flutter` 并加入 PATH。

## 权限

- Camera / Microphone：录制
- Photos / Videos / Storage：保存、回放、清理

## 产品原则

1. 录制结束 ≠ 练习结束  
2. 录制是主流程（录制 → 判断 → 继续）  
3. 最佳版本优先
