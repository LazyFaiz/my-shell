# Zsh 配置

参考 [radleylewis/zsh](https://github.com/radleylewis/zsh) 的模块划分与功能设计，保留上游 MIT 许可。适用于 Linux、macOS、WSL 中的 Zsh，不适用于直接在 PowerShell 中加载。

包含历史记录共享、大小写不敏感补全、Vi 模式、自动建议、历史子串搜索、语法高亮，以及可选的 fzf、zoxide 和 Starship。没有安装增强工具时仍可使用基础配置。插件改为手动安装，启动终端不会自动下载。

## 安装

至少需要 Zsh；安装插件还需要 Git。请先在目标系统安装这些依赖。可选增强工具为 `fzf`、`fd`、`bat`、`eza`、`zoxide`、`starship`、`neovim`、`ripgrep`。Ubuntu 的 `fdfind`、`batcat` 会自动识别。

Starship 使用官方 [Pastel Powerline Preset](https://starship.rs/presets/pastel-powerline)，包含柔和色块、Powerline 分隔符、用户名、目录、Git 状态、语言版本和时间。请在终端中安装并启用 Nerd Font（官方示例使用 Caskaydia Cove Nerd Font），以正确显示图标和分隔符。

在 **Zsh 或 Bash** 中进入本目录，然后复制配置（`cp -i` 会在存在同名文件时询问）：

```sh
# WSL 下本项目通常位于此处：
cd /mnt/f/Desktop/product/shell/zsh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
mkdir -p "$config_dir"
cp -i .zshenv .zshrc aliases.zsh bindings.zsh fzf.zsh plugins.zsh \
  prompt.zsh starship.toml local.zsh.example LICENSE "$config_dir/"
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
| `prompt.zsh` / `starship.toml` | 提示符及主题 |
| `local.zsh.example` | 私有设置示例，复制为 `local.zsh` 使用 |

常用命令：`ll`、`la`、`..`、`...`、`gs`、`gd`、`glog`、`mkcd 目录名`；`c 文件名` 用 bat 查看文件。保留原始 `cat`、`grep` 的行为。

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
