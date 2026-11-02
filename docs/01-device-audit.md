# 01 · 设备与预装排查

> 采集时间：2026-11-02
> 方式：网络 ADB（5555），全程只读，未做修改。
> 地址统一以 `<BOX_IP>` 表示。

## 设备实况

| 项目 | 结果 |
| --- | --- |
| 固件型号 | `UNT413A_796` / `UNT413A5_GD2` |
| 厂商 / 芯片 | JIULIAN 九联 / Amlogic S905L3，4×Cortex-A53，Mali-450 |
| 系统 | Android 9（API 28），`userdebug` + `test-keys`，安全补丁 2018-08，编译于 2021-09 |
| 内存 | 2 GB |
| 存储 | `/data` 3.7 GB，已用 2.9 GB，剩余 825 MB（79%） |
| `/system` | 1.2 GB，已用 810 MB |
| 网络 | 有线 eth0，ADB 5555 常开、无认证，连接即 root |
| 桌面 | 当贝桌面，安装为系统 priv-app（目录伪装成 `Settingservice`） |

## 预装推广 / 遥测

| 包名 | 作用 | 常驻内存 |
| --- | --- | --- |
| `com.dangbei.tvlauncher` | 当贝桌面，含友盟推送、悬浮窗、`push` 子进程 | 52 MB + 80 MB |
| `tv.icntv.vendor` | ICNTV 未来电视 / IPTV 设置（内容推荐） | 57 MB |
| `tv.cmcc.vendor` | 定制厂商组件 | — |
| `com.cmcc.mid.softdetector` | 定制“软件检测”，上报已装应用 | 13 MB |
| `com.um.checkdatasize` | 定制流量/应用检测 | 67 MB |
| `com.um.networkstatus` | 网络状态上报 | — |
| `com.amt.networkService` | AMT 网络服务（认证相关） | — |
| `com.xiaobaifile.tv` | 小白文件管理器 | 12 MB |
| `com.hpplay.happyplay.aw` | 乐播投屏 | — |
| `com.dongge.manager` / `com.dg.market` | 应用市场（悬浮窗 + 可装应用） | — |
| `com.iflytek.bt.auto` | 讯飞蓝牙自动连接（配合蓝牙遥控） | — |
| 屏保/壁纸 | PhotoTable、BasicDreams、LiveWallpapersPicker、WallpaperCropper/Backup | — |

## 第三方 App（19 个，全部为影视/直播类）

- 其中 12 个申请了 `REQUEST_INSTALL_PACKAGES`（可拉起安装其它应用）；
- 多个已获 `RECORD_AUDIO`、`READ_PHONE_STATE`、`ACCESS_FINE_LOCATION`；
- 常驻后台的有 3 个播放器 + 2 个“小苹果”系 App；
- 其中 2 个在私有目录释放了代理/下载二进制（见 `02-system-resources.md`）。

> 为避免给具体应用做宣传或定性，仓库不列出全部第三方 App 名称；设备上的预装包清单在
> `debloat/debloat-unt413a.txt`。

## 存储

| 项目 | 大小 |
| --- | --- |
| `/data/app` | 1.39 GB |
| `/data/user_de` | 1.17 GB |
| `/data/media` | 394 MB |
| `/data/data` | 35 MB |
| `/data/dalvik-cache` | 40 MB |
| 安装包残留（`com.android.packageinstaller/files`） | 约 100 MB |
| `/sdcard/UniversalImageLoader` | 224 MB |

## 安全

- ADB 5555 无认证且直接 root：同一局域网内任何设备都能完全控制盒子；
- `/system` 可写；
- 部分 App 的更新包与官方签名不一致（见 `03-changes-and-rollback.md`）；
- 部分 App 在 `0.0.0.0` 上监听 RPC / 代理端口。

## 可逆性

- 已备份 `getprop`、全部包列表、settings；
- 所有停用均使用 `pm disable-user`（等价于系统设置里的“停用”），不删除文件；
- 原系统脚本、APK 均保留副本。

## 结论

这台盒子的“慢”不是硬件不够，而是：

1. 预装桌面/推送/遥测长期占用内存和网络；
2. 影视 App 互相拉起、后台常驻；
3. 系统里有 3 个产线脚本/服务在空转（见下一节）；
4. `/data` 只剩 825 MB，缓存和残留安装包挤占空间。

以上四类都可以在不刷机的前提下处理。
