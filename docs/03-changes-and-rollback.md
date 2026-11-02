# 03 · 变更记录与回滚

> 执行时间：2026-11-02 21:57 – 2026-11-03 00:30
> 原则：只停用/替换，不卸载系统组件；所有原文件都有备份。

## 1. 桌面

- 编译并安装 [CleanYourTV](https://github.com/Gathin23/cleanyourtv) 启动器（574 KB，
  `com.gathin.tvhome`），设为默认 Home；
- 停用当贝桌面 `com.dangbei.tvlauncher`（保留 APK，可随时启用）；
- 本固件的 `/sdcard/Android/data` 对启动器不可读，主题热推送无效，
  因此 dock 顺序直接编译进 `config.xml`；
- 7 个没有 `LEANBACK_LAUNCHER` 入口的 App 通过 `library_apps` 预置进 Home，
  否则它们不会显示。

## 2. 预装包（12 个，全部 `pm disable-user`）

```
tv.icntv.vendor
tv.cmcc.vendor
com.amt.networkService
com.cmcc.mid.softdetector
com.um.checkdatasize
com.um.networkstatus
com.dangbei.tvlauncher
com.android.dreams.basic
com.android.dreams.phototable
com.android.wallpaper.livepicker
com.android.wallpapercropper
com.android.wallpaperbackup
```

保留：小白文件管理器、蓝牙语音、乐播投屏、应用市场（按机主选择）、以及全部影视 App 本体。

## 3. 第三方 App 后台限制

对 16 个影视/市场 App 设置：

```sh
cmd appops set <pkg> RUN_IN_BACKGROUND ignore
cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore
```

并 `am force-stop`。注意：Android 9 的 `RUN_IN_BACKGROUND` **拦不住
`BOOT_COMPLETED` 广播**，部分 App 仍会在开机时短暂启动；真正要禁止需要停用包本身。

## 4. 存储清理

- `com.android.packageinstaller/files/*.apk`：约 100 MB 安装包残留；
- `/sdcard/UniversalImageLoader`：224 MB 图片缓存；
- 各 App 的 `cache` 目录：约 1 GB；
- `/sdcard/testagent.log`：8.7 MB。

`/data` 从 2.9 GB 降到 1.6 GB。

## 5. 系统脚本

### 5.1 SMI 全盘扫描

`/system/etc/SMI_RAC_TDAT16M30S.sh` 替换为 sleeper：

```sh
while true; do sleep 3600; done
```

服务名不变，init 不会进入重启循环。验证：重启后 `dmesg | grep -c drop_caches` = 0。

### 5.2 testagent

`/system/bin/startstbagent.sh` 改为 `exit 0`，`/sdcard/testagent.log` 删除。

### 5.3 startthirdservice

`/system/bin/startthirdservice.sh` 替换为：

```sh
start xiriservice
for i in eth0 wlan0; do
    iptables -I INPUT -i $i -p tcp --dport 6800 -j DROP 2>/dev/null
    iptables -I INPUT -i $i -p tcp --dport 7777 -j DROP 2>/dev/null
done
sleep 45
stop IptvService
stop iptvd
stop amtprox
sleep 10
if ! ping -c1 -W2 223.5.5.5 >/dev/null 2>&1; then
    start IptvService; start iptvd; start amtprox
fi
while true; do sleep 3600; done
```

- 不再无限重启；
- 保留 `xiriservice`（语音）；
- 停 3 个纯 IPTV 服务，并带“网络异常自动拉起”；
- **不要停 `configserver` / `networkserver`**。

## 6. 防火墙

对 `eth0` / `wlan0` 入站拦截：

```
iptables -I INPUT -i eth0  -p tcp --dport 6800 -j DROP
iptables -I INPUT -i wlan0 -p tcp --dport 6800 -j DROP
iptables -I INPUT -i eth0  -p tcp --dport 7777 -j DROP
iptables -I INPUT -i wlan0 -p tcp --dport 7777 -j DROP
```

本机 loopback 调用不受影响。规则由 5.3 的脚本在每次开机时重新写入。

## 7. 星火电视更新死循环

| | 已安装 | 官方更新包 |
| --- | --- | --- |
| 版本 | 1.0.52-cs2 | 1.0.53.3 |
| 签名 SHA256 | `f9bbb6fd…` | `450c0527…` |
| 更新地址 | — | `http://live1.aesq.top:93/update/yhzb.apk` |

已装版本被重新签名，Android 不允许签名不同的 APK 覆盖安装，App 内更新静默失败。
处理：卸载旧版 → 安装官方包 → 重新设置后台限制。旧 APK 与数据已备份。

## 8. 事故与教训

第一次把 `configserver`/`networkserver` 也一起停掉后，盒子出现：

- 能进桌面，随后黑屏；
- 有线网络丢失，ADB 不可达；
- 需要断电重启，且重启后会重复。

回退为“只停 3 个纯 IPTV 服务 + 自愈脚本”后恢复正常。
**结论：这两个服务参与以太网/显示初始化，不能停。**

`logd` 每 5 秒重启的问题没有处理：属于厂商权限/SELinux 配置，修它风险大于收益。

## 9. 验证

- 重启后连续观察 4 分钟：显示常亮、网络正常、ADB 在线；
- `dmesg | grep -c drop_caches` = 0；
- `iptables -L INPUT -n | grep -cE '6800|7777'` = 4；
- `init.svc.configserver` / `init.svc.networkserver` = running；
- `IptvService` / `iptvd` / `amtprox` = stopped；
- Home 解析到 `com.gathin.tvhome/.MainActivity`；
- `/data` 剩余 2.0 GB。

## 10. 回滚

`scripts/rollback.sh` 做这些事：

1. 恢复 12 个预装包（`pm enable`）；
2. 恢复第三方 App 的后台权限（`appops default`）；
3. 恢复 3 个系统脚本（从备份推送）；
4. 清除 6800/7777 防火墙规则；
5. 恢复 softdetector APK 文件名；
6. 切回当贝桌面；
7. 可选卸载 CleanYourTV 启动器。

```bash
bash scripts/rollback.sh 192.168.1.50
```

> 恢复系统脚本和 softdetector 后需要重启一次才生效。
