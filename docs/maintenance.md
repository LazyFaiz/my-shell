# 环境检查、更新与恢复

## 启用维护命令

第一次获取本次更新时，在现有仓库目录执行：

```sh
git pull --ff-only
bash scripts/install-config.sh
exec zsh
```

安装脚本会把仓库实际路径写入配置目录的 `repository` 文件。仓库搬家后重新执行安装脚本，或在 `local.zsh` 设置 `MY_SHELL_REPO=/实际仓库路径`。路径作为数据读取，不作为命令执行。

## 环境检查

在当前 Zsh 里执行：

```zsh
shell-doctor
```

显示系统、Zsh 版本、工具路径和版本、用户 bin 目录是否被 PATH 遮挡、配置文件是否齐全、四个插件是否在当前会话成功加载，以及 fzf 预览选项的引号检查。还会列出可选图片/PDF/视频预览工具，不输出整个环境变量或 Git 身份信息，也不执行自定义预览命令。

- `[OK]` 表示检查通过。
- `[WARN]` 给出缺失、旧版本或需要重新加载的项目。可选工具没装也可能产生警告，不代表整个 Shell 无法使用。
- `[INFO]` 表示可选能力。终端字体、图片协议、剪贴板及真实预览仍需手动验证。
- 退出码：没有警告为 0，有警告为 1。

插件“已加载”指当前配置加载时成功 source；它不会为了检查而重新启动或下载插件。`exec zsh` 后再运行可确认新配置的状态。

预览工具显示 `absent` 时，按 [补齐 Yazi 预览依赖](install.md#补齐-yazi-预览依赖) 安装 ffmpeg、Poppler、resvg 和 7-Zip。`7zz` / `7z` 有一个可用即可；安装后执行 `rehash`、`shell-doctor`，并重新打开 Yazi 检查实际预览。系统依赖由原包管理器更新。

## 分类更新

```zsh
shell-update config          # git pull --ff-only，更新并安装 Zsh 配置
shell-update plugins         # 更新已安装的四个 Zsh 插件
shell-update tools           # 更新本仓库管理的 Neovim、Zellij、Yazi、tealdeer
shell-update tools tealdeer  # 只更新仓库管理的 tldr
shell-update tools yazi      # 只更新 Yazi（同时检查 ya）
shell-update all             # 顺序执行上述三类更新
```

无参数显示帮助，不做更新。没有加载函数时可在仓库中运行 `bash scripts/update.sh tools` 等同类命令。

配置更新遇到未提交修改会退出，不自动覆盖或 stash。Git 更新只允许快进，分叉时需自行处理。个人设置写在 `local.zsh` 中，安装时会保留。更新后执行 `exec zsh` 使新配置、插件和别名生效。

工具更新只处理指向 `~/.local/opt/` 内本仓库版本目录的用户入口，不会自动安装未安装的工具，也不运行 apt、dnf、pacman 或 brew 升级系统。系统包管理的软件仍用原包管理器更新。AstroNvim 插件本身使用 Neovim 内的 `:Lazy sync`。

工具安装器仍需请求 GitHub 最新稳定版元数据；版本、架构资源标记和程序实际版本都一致时，跳过安装包下载、解压与切换入口。缺少或损坏 `ya` 会重新安装 Yazi。旧安装器没有版本标记，因此首次用新安装器更新可能重装一次，后续即可跳过。

`all` 遇到失败会停止，前面成功的步骤不会自动撤销；纠正错误后可只重跑失败类别。

## 安装失败如何处理

脚本会输出类似：

```text
[FAILED] install-yazi.sh: step=checksum, exit=1
Backup: /.../yazi-entry-backup-...
Downloaded version directory: /.../yazi-v...-...
```

只有已创建的路径才会显示。失败阶段包括依赖检查、发布信息查询、下载、校验、解压、启动验证、入口切换，以及配置备份/复制。临时下载目录会清理；已安装版本和备份不会自动删除。

| 阶段 | 处理方式 |
| --- | --- |
| preflight | 安装输出中提示的缺失依赖，或确认系统与架构支持 |
| release-metadata | 检查 GitHub API 访问、限流及发布资源信息，稍后重试 |
| archive-download | 检查网络和磁盘空间，再运行原命令 |
| checksum / extract-archive | 文件校验或解压失败；重新下载，不跳过校验 |
| verify-binary | 检查架构、系统兼容性和二进制运行错误 |
| activate-entry | 检查用户目录权限、入口是否异常；按下节恢复 |
| backup-config / copy-config | 检查权限、空间；保留已打印的备份目录 |
| plugin-update | 检查失败插件的 Git 工作区和网络，不要直接删除私有修改 |

## 恢复工具入口

示例恢复 Zellij。将 `backup` 替换为失败输出或旧安装输出中的确切备份目录，先退出正在使用的工具：

```bash
bash <<'BASH'
set -euo pipefail
backup="$HOME/.local/opt/zellij-entry-backup-替换为实际目录"
entry="$HOME/.local/bin/zellij"
[[ -e "$backup/zellij" || -L "$backup/zellij" ]] || { echo '备份不存在'; exit 1; }
[[ ! -d "$entry" ]] || { echo '入口是目录，停止恢复'; exit 1; }
if [[ -e "$entry" || -L "$entry" ]]; then
  mv "$entry" "$entry.before-restore.$(date +%Y%m%d-%H%M%S).$$"
fi
cp -a "$backup/zellij" "$entry"
BASH
```

Neovim 使用 `nvim-entry-backup-*` 和 `nvim`。Yazi 使用 `yazi-entry-backup-*`，对 `yazi` 和 `ya` 两个入口分别恢复。备份为空意味着此前没有用户入口，不是备份失败。恢复后执行 `rehash` 或 `exec zsh`，再用 `command -v` 与 `--version` 验证。

若想回到系统包管理的版本，可将用户入口改名保留，随后 `rehash`；不要删除对应的 `~/.local/opt/` 旧目录，备份软链接可能还指向它。

## 恢复 Zsh 配置

配置备份在 `${XDG_STATE_HOME:-~/.local/state}/my-shell/backups/install-*`。脚本备份的是更新前状态：

| 备份项 | 原位置 |
| --- | --- |
| `zsh/` | `${XDG_CONFIG_HOME:-~/.config}/zsh/` |
| `zshenv` | `~/.zshenv` |
| `zshrc` | `~/.zshrc` |
| `gitconfig` | `${GIT_CONFIG_GLOBAL:-~/.gitconfig}` |
| `xdg-gitconfig` | `${XDG_CONFIG_HOME:-~/.config}/git/config` |

先开启一个 Bash 会话，把当前文件或目录改名保留，再将对应备份复制回原位置，最后启动 Zsh。没有备份项表示安装前不存在该文件；例如原先没有 `.zshenv`，可删除新增的 `BEGIN my-shell` 到 `END my-shell` 段。Git 配置恢复时注意保留备份之后新增的个人设置。

## 自动化检查

GitHub Actions 在 push、pull request 和手动触发时，分别使用 Linux 与 macOS 运行：

```bash
bash scripts/check.sh
```

检查所有 Bash 脚本和 Zsh 模块语法，执行下载校验、版本跳过、备份、更新保护、当前会话诊断、fzf 特殊文件名、Yazi 目录跟随等测试。需要 Bash、Zsh、Python 3、jq、unzip 和 file。CI 明确要求 Zsh，避免因为缺少 Zsh 而跳过相关测试。

测试里的下载与架构信息采用固定样例，不会在 CI 安装全部真实桌面工具。真实终端交互、字体、图片预览，以及所有发行版的实际二进制兼容性仍不在测试范围内。工作流提交并推送后才会在 GitHub 上开始运行。

Yazi/ya 的多行版本输出也会参与版本检查，诊断会显示 Version 行中的版本号。旧版 tealdeer 的缓存兼容性提醒及迁移步骤见 [安装指南](install.md)。tealdeer 入口恢复使用 `tldr-entry-backup-*` 中的 `tldr`，与上面的工具恢复流程相同。
