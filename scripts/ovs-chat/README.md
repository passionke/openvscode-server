# OVS Chat Agent 模式验证

基于 **openvscode-server v1.109.5**（`openvscode-server-v1.109.5`），用 `extensions/ovs-chat-demo` 打通 Chat participant 派发链。

发布仓库：`git@github.com:passionke/openvscode-releases.git`

## 架构与打包（本地 vs CI）

| 场景 | 平台 | 产物 | 怎么打 |
|------|------|------|--------|
| **本机 Mac 开发**（`run-dev.sh`） | `darwin-arm64`（Apple Silicon）或 `darwin-x64` | `../vscode-reh-web-darwin-*` | `bash scripts/ovs-chat/build-ovs.sh` |
| **Podman 容器 / Linux 服务器** | `linux-arm64`（Mac 上 podman 优先）或 `linux-x64` | `openvscode-server-v*-linux-*.tar.gz` | GitHub Actions **OVS Chat Linux Build**，或 `passionke/openvscode-releases` Release workflow |

**结论：** 本地跑 3100 **要打本机架构包**（你是 M 系列 → **darwin-arm64**）；CI 打 **linux-arm64 + linux-x64** 给容器部署，不能拿 linux 包在 Mac 上直接 `run-dev.sh`。

CI 触发：GitHub → Actions → **OVS Chat Linux Build** → Run workflow。

## 成功标准

1. Output **OVS Chat Demo**：`handler mode="agent" prompt="ping"`
2. Chat 显示 **demo ok (agent)**
3. 日志含 `[OVS-CHAT]` 链路：`chatServiceImpl` → `chatAgents` → `mainThread` → `extHost`

## 本地开发（源码编译）

```bash
# 已在 ovs-chat-fix 分支（基于 v1.109.5）
chmod +x scripts/ovs-chat/*.sh
./scripts/ovs-chat/build-ovs.sh    # 首次较慢
./scripts/ovs-chat/run-dev.sh      # http://127.0.0.1:3000/
```

浏览器：Chat → `@demo ping` → 查看 Output 与 Console（过滤 `OVS-CHAT`）。

Remote EH 日志：

```bash
tail -f .build/ovs-server-data/data/logs/*/exthost*/remoteexthost.log | grep OVS-CHAT
```

## 打包 VSIX

```bash
./scripts/ovs-chat/package-ovs-extension-vsix.sh
# → .build/ovs-chat-demo.vsix
```

## 容器验证（自建 release 后）

```bash
./scripts/ovs-chat/package-ovs-extension-vsix.sh
podman build -f scripts/ovs-chat/Containerfile.openvscode \
  --build-arg RELEASE_ORG=passionke \
  --build-arg RELEASE_TAG=openvscode-server-v1.109.5 \
  -t passionke/openvscode-server:ovs-chat .
podman run --rm -p 3000:3000 passionke/openvscode-server:ovs-chat
```

## 诊断日志插入点

| 文件 | 标记 |
|------|------|
| `chatServiceImpl.ts` | `[OVS-CHAT] chatServiceImpl invokeAgent` |
| `chatAgents.ts` | `[OVS-CHAT] chatAgents invokeAgent` |
| `mainThreadChatAgents2.ts` | `[OVS-CHAT] mainThread invoke` |
| `extHostChatAgents2.ts` | `[OVS-CHAT] extHost $invokeAgent` |

## 发布流程

1. 推送 `ovs-chat-fix` 到 `passionke/openvscode-server`（需先 fork）
2. 在 `passionke/openvscode-releases` 触发 Release workflow，`commit` 填分支名
3. 更新 `Containerfile` 的 `RELEASE_TAG` 指向新 release

Author: kejiqing
