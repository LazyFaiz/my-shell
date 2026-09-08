# Zsh 配置

参考 [radleylewis/zsh](https://github.com/radleylewis/zsh) 的模块划分与功能设计，保留上游 [MIT 许可](../LICENSE)。适用于 Linux、macOS、WSL 中的 Zsh，不适用于直接在 PowerShell 中加载。

包含历史记录共享、大小写不敏感补全、Vi 模式、自动建议、历史子串搜索、语法高亮，以及可选的 fzf、zoxide 和 Starship。没有安装增强工具时仍可使用基础配置。插件改为手动安装，启动终端不会自动下载。

## 安装

完整工具环境（AstroNvim、Zellij、Yazi、btop、jq、tealdeer、git-delta）请按 [多系统安装指南](../docs/install.md) 操作。以下为仅复制 Zsh 配置的方式。

至少需要 Zsh；安装插件还需要 Git。请先在目标系统安装这些依赖。可选增强工具为 `fzf`、`fd`、`bat`、`eza`、`zoxide`、`starship`、`neovim`、`ripgrep`。Ubuntu 的 `fdfind`、`batcat` 会自动识别。

Starship 使用官方 [Pastel Powerline Preset](https://starship.rs/presets/pastel-powerline)，包含柔和色块、Powerline 分隔符、用户名、目录、Git 状态、语言版本和时间。请在终端中安装并启用 Nerd Font（官方示例使用 Caskaydia Cove Nerd Font），以正确显示图标和分隔符。

在 **Zsh 或 Bash** 中进入本目录，然后复制配置（`cp -i` 会在存在同名文件时询问）：

```sh
# 在仓库的 zsh 目录中执行：
cd ~/my-shell/zsh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
mkdir -p "$config_dir"
cp -i .zshenv .zshrc aliases.zsh bindings.zsh fzf.zsh plugins.zsh maintenance.zsh \
  prompt.zsh starship.toml local.zsh.example ../LICENSE "$config_dir/"
```

Linux/macOS 请将 `cd` 路径替换为实际目录。接下来，在 `~/.zshenv` **末尾添加一次**以下内容；已有文件请保留原内容。无需修改 `/etc/zsh/zshenv`：

```sh
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ ! -r "$ZDOTDIR/.zshenv" ]] || source "$ZDOTDIR/.zshenv"
```

若已有自定义 `ZDOTDIR`，请将上述引导段放入 Zsh 当前实际读取的 `.zshenv`。新配置生效后将使用配置目录内的 `.zshrc`；原有 `~/.zshrc` 不会被自动加载，可把需要保留的设置迁入 `local.zsh`。

```sh
zsh
# 在新打开的 Zsh 中执行；此步骤会从 GitHub 下载四个插件：
zplugin-install
exec zsh
```

不安装插件也可直接使用。以后通过 `zplugin-update` 更新插件，完成后重新打开终端。插件存放于 `${XDG_DATA_HOME:-~/.local/share}/zsh/plugins`；安装失败时查看命令输出后重试。

## 快捷键

| 按键 | 功能 |
| --- | --- |
| Esc / i | Vi 普通模式 / 插入模式 |
| Ctrl+R | fzf 历史搜索；无 fzf 时使用内置历史搜索 |
| Ctrl+T | fzf 文件搜索（安装 fd 后包含隐藏文件） |
| Ctrl+F | fzf 文件搜索，排除隐藏文件 |
| Ctrl+← / Ctrl+→ | 按词移动 |
| ↑ / ↓ | 有插件时搜索历史子串，否则按前缀搜索 |
| Ctrl+\ | 启用/停用自动建议（需插件） |

Ctrl+T / Ctrl+R 的 fzf 集成需要支持 `fzf --zsh` 的版本，或系统包提供 `shell/key-bindings.zsh`；常见 Homebrew/Linux 安装路径已兼容。

## 文件与自定义

| 文件 | 用途 |
| --- | --- |
| `.zshenv` | XDG 目录、PATH、编辑器 |
| `.zshrc` | 主入口、历史、补全 |
| `aliases.zsh` | 别名及 `mkcd` 函数 |
| `bindings.zsh` | Vi 模式及快捷键 |
| `fzf.zsh` | 模糊搜索与预览 |
| `plugins.zsh` | 插件安装、更新及加载 |
| `maintenance.zsh` | 当前会话诊断与分类更新 |
| `prompt.zsh` / `starship.toml` | 提示符及主题 |
| `local.zsh.example` | 私有设置示例，复制为 `local.zsh` 使用 |

常用命令：`ll`、`la`、`..`、`...`、`gs`、`gd`、`glog`、`mkcd 目录名`；`c 文件名` 用 bat 查看文件。`ll` 和 `la` 均以详细列表显示文件（包含隐藏文件），有 eza 时使用 eza，否则使用 ls。保留原始 `cat`、`grep` 的行为。

历史文件位于 `$XDG_STATE_HOME/zsh/history`，补全缓存位于 `$XDG_CACHE_HOME/zsh`。历史中以空格开头的命令不保存。

## 检查与恢复

在目标系统运行语法检查：

```sh
for file in .zshenv .zshrc *.zsh; do zsh -n "$file" || break; done
```

临时试用（在本目录内执行，无需编辑用户配置）：

```sh
ZDOTDIR="$PWD" zsh
```

恢复旧配置时，删除此前添加到 `~/.zshenv` 的引导段，并恢复原来的 `ZDOTDIR` 设置，然后重新打开终端。

## 新增工具命令

| 命令 | 功能 |
| --- | --- |
| `btop` | 系统监控 |
| `lt` | 两层目录树（eza） |
| `rgh 关键词` | 包含隐藏文件的文本搜索 |
| `t 命令` | 查看 tldr 示例（首次先 `tldr --update`） |
| `jqp 文件.json` | 格式化 JSON，也可接收管道输入 |
| `ports` | Linux 显示 TCP/UDP 监听端口；macOS 回退为 TCP 监听端口 |
| `disk` / `mem` | 磁盘 / 内存；macOS 内存输出使用 vm_stat |
| `y [目录]` | 打开 Yazi，q 退出跟随目录；Q 退出保持原目录 |
| `zj` | 打开 Zellij |
| `za work` / `zl` | 创建或连接 work 会话 / 列出会话 |
| `extract 文件` | 解压到文件旁的新 `.extracted` 目录 |

可选工具未安装时不会定义相应别名。`extract` 支持 tar、tar.gz、tar.bz2、tar.xz、zip、7z、rar；RAR 支持取决于安装的 7-Zip 构建。`c` 仍用于 bat 查看文件，不表示清屏。delta 通过安装脚本的 `--delta` 选项配置 Git 后生效。

## 修复旧版本的 fzf 预览报错

旧版本将 fzf 的 `{}` 占位符放在 Zsh 的默认值参数展开内部，会生成不完整的预览命令，出现 `parse error near '}'`。更新配置后，旧终端可能仍继承错误的环境变量，请执行：

```zsh
unset FZF_CTRL_T_OPTS
exec zsh
```

如果在 `local.zsh` 中自定义预览选项，也请检查该设置。新版保留已有的自定义选项，不会自动覆盖。

## 日常维护

使用 `shell-doctor` 检查版本、PATH、插件加载和预览依赖。使用 `shell-update config`、`shell-update plugins`、`shell-update tools` 分类更新，或 `shell-update all` 顺序执行。具体恢复步骤与测试说明见 [维护指南](../docs/maintenance.md)。手动复制配置的用户需要在 `local.zsh` 中设置 `MY_SHELL_REPO`，或运行一次 `install-config.sh` 记录仓库位置。

zoxide 最新稳定版可用 `bash scripts/install-config.sh --zoxide` 安装，或单独运行 `bash scripts/install-zoxide.sh`；随后 `exec zsh`，以后用 `shell-update tools zoxide` 更新。
