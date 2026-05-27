# Pet Y 阿里云 ECS 运维说明

这份文档记录 Pet Y 公网 Relay 的日常操作方式。不要把密码、私钥、真实 token 写进仓库。

## 服务器信息

- 实例名称：launch-advisor-20260114
- 实例 ID：i-bp16ldwoshleyczaw9tb
- 地域：华东 1（杭州）
- 可用区：H
- 公网 IP：47.99.98.43
- 操作系统：Alibaba Cloud Linux 3.2104 LTS 64 位
- 配置：2 核 vCPU / 2 GiB 内存
- Relay 地址：http://47.99.98.43:8787

## 登录

当前可用的直接运维方式：

```bash
ssh root@47.99.98.43
```

曾经创建过的 `ecs-assist-user` 当前没有可用 shell，不适合直接运维。

## 关键路径

```text
/opt/pet-y                         Relay 项目目录
/opt/pet-y/server.js               当前公网 Relay 服务代码
/opt/pet-y/data/relay-state.json   用户、好友、邀请、访问状态持久化
/opt/pet-y/data/analytics.jsonl    匿名统计事件日志
/opt/pet-y/backups                 手动更新前保留的备份
/etc/systemd/system/pet-y-relay.service
/etc/systemd/system/pet-y-relay.service.d/10-env.conf
/etc/pet-y-relay.env               Relay 环境变量，不要提交到 Git
```

`/etc/pet-y-relay.env` 里目前使用的变量包括：

```text
PET_Y_RELAY_SECRET
PET_Y_ANALYTICS_SALT
PET_Y_RELAY_ONLY
```

## 查看服务状态

```bash
systemctl status pet-y-relay.service --no-pager
```

确认端口：

```bash
ss -lntp | grep 8787
```

确认公网健康状态：

```bash
curl http://47.99.98.43:8787/api/health
```

在服务器本机读取管理统计：

```bash
curl http://127.0.0.1:8787/api/admin/stats
```

管理统计默认不对公网开放。公网访问 `/api/admin/stats` 返回 403 是正常的。

## 查看日志

最近日志：

```bash
journalctl -u pet-y-relay.service -n 120 --no-pager
```

持续跟随日志：

```bash
journalctl -u pet-y-relay.service -f
```

查看匿名统计日志：

```bash
tail -n 50 /opt/pet-y/data/analytics.jsonl
```

## 重启 Relay

```bash
systemctl restart pet-y-relay.service
systemctl status pet-y-relay.service --no-pager
curl http://127.0.0.1:8787/api/health
```

如果改了 systemd 配置：

```bash
systemctl daemon-reload
systemctl restart pet-y-relay.service
```

## 更新服务器代码

更新前先备份当前服务代码和状态文件：

```bash
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "/opt/pet-y/backups/$stamp"
cp /opt/pet-y/server.js "/opt/pet-y/backups/$stamp/server.js"
cp /opt/pet-y/data/relay-state.json "/opt/pet-y/backups/$stamp/relay-state.json"
```

从本地复制新 Relay 代码到服务器：

```bash
scp server.js root@47.99.98.43:/opt/pet-y/server.js
```

然后在服务器上重启并验证：

```bash
systemctl restart pet-y-relay.service
systemctl status pet-y-relay.service --no-pager
curl http://127.0.0.1:8787/api/health
```

如果服务启动失败，可以用刚才的备份恢复：

```bash
cp "/opt/pet-y/backups/$stamp/server.js" /opt/pet-y/server.js
systemctl restart pet-y-relay.service
```

## 运营监控

本地项目里可以运行：

```bash
npm run monitor:usage
```

这个脚本会通过 SSH 登录服务器，读取本机 admin stats 和匿名 `analytics.jsonl`，输出新增、活跃、留存、好友绑定和串门数据。

Codex 里已经创建了自动任务：

```text
Pet Y usage monitor
```

当前频率：每 6 小时汇总一次。

## 安全注意事项

- 不要把 `/etc/pet-y-relay.env` 内容写入 Git。
- 不要把 SSH 私钥、密码、Relay secret、analytics salt 写入文档。
- `/api/admin/stats` 只应允许本机读取，公网 403 是正确状态。
- `data/relay-state.json` 包含产品运行状态，不要公开发布。
- `analytics.jsonl` 是匿名统计日志，但仍应当只用于内部运营分析。
