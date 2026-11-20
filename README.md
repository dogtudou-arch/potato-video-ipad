# 土豆视频 iPad 版

1.2.0 起，应用启动及联网请求前会向 `https://rui.tail735079.ts.net/potato/api/check` 上报设备与应用版本，接收后台启用状态。旧 IPA 不会自动获得此功能，需要重新构建、签名并安装。

独立的 SwiftUI iPad 工程，与 `PotatoVideo-iOS` iPhone 工程分开。沿用现有影片搜索、搜索历史、收藏文件夹、选集、在线播放和播放器触控操作。收藏保存在本机。iPad 页面使用居中的宽栏布局，支持横竖屏与分屏；播放器保持当前屏幕方向。最低系统为 iPadOS 16。

## 构建 IPA

将本目录作为 GitHub 仓库根目录提交。每次推送会在 macOS GitHub Actions 运行 `.github/workflows/build-ipa.yml`，上传 `PotatoVideo-iPad-unsigned-ipa` 构建产物。解压后得到 `PotatoVideo-iPad-unsigned.ipa`，需要自行签名安装。此工程使用独立包名 `org.libretv.mobile.ipad`，可与 iPhone 版区分。

当前 Windows 环境没有 Xcode，需以 macOS 上的 Xcode 或 Actions 构建结果验证实际设备运行。
