# UNT413A / UNT431A 机顶盒优化记录

> 一台九联 UNT413A IPTV 盒子（Amlogic S905L3，Android 9）的完整优化过程：
> 换桌面、去预装、限制后台、修复出厂测试脚本空转、处理内置 PCDN 代理。
> 全部改动可逆，不刷机、不 root 新系统，只利用盒子自带的 `userdebug` + ADB。

English: A field report and reusable scripts for debloating and speeding up a Chinese
IPTV set-top box (Unionman/九联 UNT413A, Amlogic S905L3, Android 9). No firmware flashing;
everything is done through the box's own ADB and `pm disable-user`.

## 结果

| 指标 | 优化前 | 优化后 |
| --- | --- | --- |
| 默认桌面 | 当贝桌面（含推送、悬浮窗） | CleanYourTV 启动器（574 KB，无网络权限） |
| 预装推广/遥测 | 12 个启用 | 12 个停用 |
| 后台影视进程 | 9 个常驻 | 0 个 |
| `/data` 已用 | 2.9 GB / 3.7 GB（剩 825 MB） | 1.6 GB / 3.7 GB（剩 2.0 GB） |
| eMMC 全盘扫描 | 每 30 秒读 16 MB + `drop_caches`，无限循环 | 已停止（`drop_caches` 计数 0） |
| 工厂测试代理 | 每 5 秒重试 + 写 8.7 MB 日志 | 已停止 |
| 局域网端口 | 6800 / 7777 对所有网卡开放 | 仅本机可用 |

| 优化前 | 优化后 |
| --- | --- |
| ![](docs/screenshots/home-before.png) | ![](docs/screenshots/home-after.png) |

## 设备

| 项目 | 值 |
| --- | --- |
| 固件型号 | `UNT413A_796` / `UNT413A5_GD2`（用户常称 UNT431A） |
| 厂商 / 芯片 | JIULIAN 九联 / Amlogic S905L3，4×Cortex-A53 |
| 系统 | Android 9（API 28），`userdebug`、`test-keys`，安全补丁 2018-08 |
| 内存 / 存储 | 2 GB / 8 GB eMMC（`/data` 3.7 GB） |
| 网络 | 有线 Ethernet，ADB 5555 |

> 示例地址统一用 `<BOX_IP>` 表示，请替换成你的盒子地址。
> 仓库不包含任何设备序列号、STB ID、MAC 或账号信息。

## 关键发现

1. **eMMC 出厂扫描脚本没关**
   `/system/etc/SMI_RAC_TDAT16M30S.sh` 每 30 秒 `dd` 读 16 MB 整盘，读完 8 GB 再从头，
   无限循环，并且每次先 `drop_caches`。这是产线老化测试脚本，导致持续 I/O 和缓存被清空。

2. **Vixtel 工厂测试代理空转**
   `testagent` 每 5 秒尝试启动不存在的 `stbagent`，日志写到 `/sdcard/testagent.log`。

3. **init 服务缺少 `oneshot`**
   `startthirdservice` 脚本执行到 `break` 就退出，但 init 会立刻重新拉起，
   形成每秒级 fork/exit 循环。

4. **影视 App 内置 PCDN / 代理**
   部分“破解版”影视 App 会在私有目录释放 `go_proxy_video`、`new_go_proxy_wex` 等二进制，
   监听 `0.0.0.0` 并回连远程接口，和播放无关。

5. **签名不一致导致更新死循环**
   渠道修改版 App 与官方包签名不同，Android 拒绝覆盖安装，App 内更新静默失败，
   退出重进又提示升级。

## 做了什么

- 编译并安装 [CleanYourTV](https://github.com/Gathin23/cleanyourtv) 启动器（574 KB），
  把没有 leanback 入口的 App 通过 `library_apps` 预置进 Home。
- 用 `pm disable-user` 停用 12 个预装推广/遥测/屏保包，不卸载、可还原。
- 对第三方 App 设置 `RUN_IN_BACKGROUND=ignore` + `RUN_ANY_IN_BACKGROUND=ignore`，
  并清掉残留安装包与缓存（约 1.3 GB）。
- 替换 3 个空转脚本，保留语音、蓝牙遥控和以太网/显示所需的 `configserver`/`networkserver`。
- 用 iptables 阻止局域网访问 6800（aria2 RPC）和 7777（PCDN），规则开机自动恢复。
- 详细记录见 [`docs/`](docs/)。

## 目录

```
docs/                    排查与变更记录（已脱敏）
debloat/                 预装包停用清单
system/                  替换后的系统脚本
scripts/rollback.sh      一键回滚（adb）
```

## 快速使用

```bash
git clone https://github.com/zseagate/unt413a-tv-optimization
cd unt413a-tv-optimization

# 1. 连接盒子（先确认 5555 可连）
BOX_IP=你的盒子IP
adb connect "$BOX_IP:5555"

# 2. 应用预装包清单（需要 cleanyourtv 的 disable.sh，或按 docs 手动 pm disable-user）
#    参考：https://github.com/Gathin23/cleanyourtv
TV_HOST="$BOX_IP" tools/disable.sh debloat/debloat-unt413a.txt

# 3. 需要时替换系统脚本（先备份！/system 需 remount rw）
adb shell 'mount -o remount,rw /system'
adb push system/SMI_RAC_TDAT16M30S.sh /system/etc/SMI_RAC_TDAT16M30S.sh
adb push system/startthirdservice.sh /system/bin/startthirdservice.sh
adb push system/startstbagent.sh /system/bin/startstbagent.sh
adb shell 'chmod 755 /system/etc/SMI_RAC_TDAT16M30S.sh /system/bin/startthirdservice.sh /system/bin/startstbagent.sh; sync; mount -o remount,ro /system'
```

> 不同固件的服务名和路径可能不同，应用前请先按 `docs/` 里的命令核对。
> 修改 `/system` 有风险，务必先备份原文件。

## 回滚

```bash
bash scripts/rollback.sh "$BOX_IP"
```

脚本会恢复预装包、后台权限、系统脚本、防火墙规则，并切回原桌面（如果仍保留）。
具体步骤见 [`docs/03-changes-and-rollback.md`](docs/03-changes-and-rollback.md)。

## 免责声明

- 本项目仅记录在一台**自有设备**上的操作，不提供固件、不包含任何厂商 APK。
- 修改 `/system`、停用系统服务可能导致设备无法启动；请先备份并确认自己能通过
  ADB 或恢复模式救回。
- 不同批次/固件的包名、服务名可能不同，请勿直接照搬。
- 文中提到的第三方 App 名称仅用于说明问题，不构成推荐或分发。

## 致谢

- [CleanYourTV](https://github.com/Gathin23/cleanyourtv)：启动器与去预装思路
- [adb-shell](https://github.com/JeffLIrion/adb_shell)：纯 Python ADB 客户端
- Android / Amlogic / 九联的公开工具链

## License

MIT，见 [LICENSE](LICENSE)。截图中的第三方应用图标归各自所有者。
