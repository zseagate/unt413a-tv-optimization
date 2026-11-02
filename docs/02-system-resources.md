# 02 · 系统资源与空转服务排查

> 采集时间：2026-11-03
> 结论：CPU 其实大量空闲，负载高是 **D 状态 I/O** 堆出来的；根因是几个出厂脚本/服务在空转。

## 资源现状

| 项目 | 结果 |
| --- | --- |
| CPU | 4×A53，最高 2.016 GHz，`interactive` |
| 空闲率 | 约 86% |
| 负载 | 5.x（1 分钟），但 CPU 大量空闲 |
| 内存 | 2 GB，用户开多个影视 App 时约 1.4 GB |
| zram | 256 MB，使用 0 |
| 温度 | SoC 约 62 °C |
| `/cache` | 1 GB 基本空 |
| SELinux | Permissive（0 条 avc 拒绝） |

## 1. SMI_RAC：出厂 eMMC 全盘扫描没有关

文件：`/system/etc/SMI_RAC_TDAT16M30S.sh`，由 `/init.unionman.rc` 注册为
`smi_rac_tdat16m30s`，`class main` 开机自启。

核心逻辑：

```sh
sector_per_read=32768          # 32768 * 512 = 16 MB
dd if=/dev/block/mmcblk0 of=/dev/null bs=512 count=$sector_per_read skip=$skip_LBA
echo 3 > /proc/sys/vm/drop_caches
sleep 30
```

- 每 30 秒读 16 MB eMMC，读完 8 GB 再从 0 开始，**无限循环**；
- 每次 `drop_caches`，把系统页缓存清空；
- dmesg 每 30 秒一条：

```
SMI_RAC_TDAT16M (3307): drop_caches: 3
```

这是 eMMC 厂商（Biwin）的产线读盘/老化测试脚本，量产固件忘了关。
后果：持续 eMMC 磨损、缓存反复被清空、App 重新读盘、负载虚高。

## 2. testagent：每 5 秒重试不存在的程序

```
/sdcard/testagent.log（8.7 MB，持续增长）
[2026-11-02 23:49:45.777] FileProcessDeamon::_RunExtraApps::_StartDeamonApp
  /data/data/com.vixtel.stb.agent/stbagent
```

`/system/bin/startstbagent.sh` 拉起 `testagent`（Vixtel 工厂测试代理），后者每 5 秒
尝试启动不存在的 `stbagent`，永远重试并写日志。

## 3. startthirdservice：init 少写了一个 oneshot

`/system/bin/startthirdservice.sh`：

```sh
while [ 1 -eq 1 ]; do
  if [ -n "$serialno" ]; then
    if ps -A | grep testagent; then break; fi
    start xiriservice; start stbdetector; start softdetector
  fi
  sleep 2
done
```

testagent 已在运行时脚本立刻 `break` 退出；但 `/init.unionman.rc` 里这个 service
没有 `oneshot`，退出后被 init 立即重启，形成每秒级 fork/exit 循环：

```
[init.svc.startthirdservice]: [restarting]
/data/startser.log: "service is running,break"
```

## 4. logd 每 5 秒崩溃重启（未修）

```
logd: failed to set CAP_SETGID, CAP_SYSLOG or CAP_AUDIT_CONTROL (1)
logd: logd.daemon: failed to set AID_SYSTEM AID_PACKAGE_INFO groups
```

`init.svc.logd` 一直 `restarting`，导致 logcat 基本不可用。
属于厂商 SELinux/权限配置问题，修它要改 init rc 或 sepolicy，风险大于收益，**保持现状**。

## 5. IPTV 原生服务

`/init.unionman.rc` 里 `class main` 常驻：

- `IptvService`、`iptvd`、`amtprox`（IPTV 认证/代理）
- `configserver`、`networkserver`（`networktest_server`）

实测：`IptvService`/`iptvd`/`amtprox` 可以停；
**`configserver`/`networkserver` 不能停**——停掉后盒子会黑屏并丢失有线网络。

## 6. 端口与 App 级代理

| 端口 | 进程 | 来源 | 说明 |
| --- | --- | --- | --- |
| 6800 | `aria2c --rpc-listen-all` | 小白文件管理器 | **无 `--rpc-secret`**，局域网可控制下载/写文件 |
| 7777 | `go_proxy_video` | 小苹果戏曲 | PCDN/代理，与播放无关 |
| 9978 / 39273 | App 自身 | 小苹果戏曲 | 播放器内部服务 |
| 5555 | adbd | 系统 | ADB（本机保留） |

> `go_proxy_video` 与另一款已卸载的“小苹果破解版 5.0”里的 `new_go_proxy_wex`
> 属于同一类 PCDN 组件。证据见文章素材，仓库不展开。

## 优化方案

| 方案 | 内容 | 风险 |
| --- | --- | --- |
| S1 | 修 3 个空转循环，保留所有服务 | 低 |
| S2 | S1 + 停 3 个纯 IPTV 服务 | 中（需验证网络） |
| S3 | S2 + 修 logd + 精简 `/system` + 调 I/O/zram | 高，收益递减 |

最终采用 S2，并为 IPTV 停止加入“网络异常自动拉起”的自愈逻辑。
执行记录见 [`03-changes-and-rollback.md`](03-changes-and-rollback.md)。
