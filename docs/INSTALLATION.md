# ClipboardX 安装与首次启动说明

本文档适用于从 GitHub Releases 下载 `ClipboardX-macos.zip` 的用户。

ClipboardX 目前使用 **ad-hoc 本地签名**（非 Apple Developer ID，也未经过 Apple 公证）。macOS 的 **Gatekeeper** 会拦截这类应用，首次打开时需要你在系统设置里手动放行。这是 macOS 的正常安全机制，**不代表应用本身有问题**。

> **隐私承诺**：ClipboardX 是纯本地应用，不上传剪贴板内容，不需要账号，也不联网同步数据。所有数据保存在 `~/Library/Application Support/ClipboardX/`。

---

## 系统要求

- macOS 14（Sonoma）或更高版本
- 从 GitHub Releases 下载并解压 `ClipboardX-macos.zip`

---

## 第一步：解压并放到合适位置

1. 双击 `ClipboardX-macos.zip` 解压，得到 `ClipboardX.app`。
2. 建议将 `ClipboardX.app` 拖到 **应用程序（Applications）** 文件夹，便于日后管理。
3. **不要从 Launchpad 里长按/右键**——Launchpad 不提供「打开」快捷菜单；请在 **Finder** 中操作。

---

## 第二步：首次打开（绕过 Gatekeeper）

根据你的 macOS 版本，选择对应方式。**只需在首次启动时操作一次**；放行之后，以后可以像普通应用一样双击打开。

### macOS 14 / 15 通用方式（推荐）

适用于所有版本，也是 **macOS 15 Sequoia 及更高版本的唯一方式**。

1. 在 Finder 中 **双击** `ClipboardX.app` 尝试打开。
2. 系统会弹出警告，提示类似：
   - *「Apple 无法验证此 App 是否包含恶意软件」*，或
   - *「无法打开 ClipboardX，因为 Apple 无法检查其是否包含恶意软件」*
3. 点击 **「完成」** 或 **「移到废纸篓」** 旁边的 **「完成」**（**不要** 点「移到废纸篓」）。
4. 打开 **系统设置（System Settings）** → **隐私与安全性（Privacy & Security）**。
5. 向下滚动到 **安全性（Security）** 区域。
6. 你会看到类似 **「已阻止使用 ClipboardX，以保护 Mac」** 的提示。
7. 点击 **「仍要打开（Open Anyway）」**。
   > 该按钮只在你 **尝试打开应用后的约一小时内** 出现。如果没看到，请回到第 1 步再双击一次应用，然后立即打开系统设置查看。
8. 再次确认弹窗中点击 **「打开（Open）」**。
9. 如系统要求，输入 **登录密码** 并确认。

完成后，ClipboardX 会被加入安全例外列表，之后可直接双击启动。

### macOS 14 Sonoma 快捷方式（可选）

在 **macOS 14** 上，还可以用 Finder 快捷菜单一次性放行：

1. 在 Finder 中找到 `ClipboardX.app`（**不要用 Launchpad**）。
2. **按住 Control 键并点击**（或右键点击）应用图标。
3. 选择 **「打开（Open）」**。
4. 在弹窗中再次点击 **「打开（Open）」**。

> **注意**：从 **macOS 15 Sequoia** 起，Apple 已禁用上述 Control-click 快捷方式，必须使用上一节的「系统设置 → 仍要打开」流程。

---

## 第三步：授予辅助功能权限

ClipboardX 需要在粘贴时模拟 `Cmd + V`，因此首次使用时系统会请求 **辅助功能（Accessibility）** 权限。

1. 首次启动后，如弹出权限请求，点击 **「打开系统设置」** 并按提示开启。
2. 或手动前往：**系统设置 → 隐私与安全性 → 辅助功能**。
3. 在列表中找到 **ClipboardX**，打开开关。
4. 如列表中没有 ClipboardX，点击 **「+」** 手动添加 `ClipboardX.app`。

授权后，菜单栏会出现 ClipboardX 图标（本应用无 Dock 图标）。

---

## 常见问题

### 双击后没有任何反应？

- 确认你已完成 **第二步** 的 Gatekeeper 放行。
- 确认 macOS 版本 ≥ 14。
- 打开 **活动监视器**，搜索 `ClipboardX` 是否已在运行（菜单栏应用可能不易察觉）。

### 「仍要打开」按钮找不到？

1. 先双击 `ClipboardX.app` 触发拦截。
2. **立即** 打开 **系统设置 → 隐私与安全性**，滚动到最底部 **安全性** 区域查看。
3. 按钮有效期约 **1 小时**；超时后需重新双击应用再试。

### 更新到新版本后又要重新放行？

每次下载的新版本在 macOS 看来可能是「新的二进制」，有时需要重新执行 **第二步**。若应用内置更新替换了 `.app`，也可能触发重新检查——按相同步骤再次 **「仍要打开」** 即可。

### 为什么不做正式签名？

ClipboardX 是个人/开源本地工具，当前使用 ad-hoc 签名以便辅助功能权限在多次启动间保持一致。正式 **Developer ID + 公证（Notarization）** 需要 Apple 开发者账号与持续维护成本，后续版本可能会改进。在此之前，请按本文档手动放行。

### 安全提示

Apple 官方说明：手动绕过 Gatekeeper 是 Mac 感染恶意软件最常见的途径之一。请 **只对你信任的来源**（例如本项目的 [GitHub Releases 页面](https://github.com/XinchaoGou/ClipboardX/releases)）下载的 ClipboardX 执行上述操作，并核对发布者/仓库地址无误。

参考 Apple 官方文档：

- [Safely open apps on your Mac](https://support.apple.com/en-us/102445)
- [Open a Mac app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac)
- [Apple can't check app for malicious software](https://support.apple.com/guide/mac-help/apple-cant-check-app-for-malicious-software-mchleab3a043/mac)

---

## 快速验证是否安装成功

1. 菜单栏出现 ClipboardX 图标。
2. 复制一段文字（如 `echo "hello" | pbcopy`）。
3. 按 **Shift + Cmd + V** 打开搜索面板，应能看到刚复制的内容。

---

## 卸载

1. 退出 ClipboardX（菜单栏图标 → Quit）。
2. 删除 `/Applications/ClipboardX.app`（或你放置 `.app` 的位置）。
3. （可选）删除数据目录：`~/Library/Application Support/ClipboardX/`
