# Fish 配置

参考本仓库 Zsh 的主题、别名与维护方式，为 Fish 单独编写。支持 Linux、macOS 和 WSL；PowerShell 不能直接加载。安装器每次查询 [Fish 官方最新稳定版](https://github.com/fish-shell/fish-shell/releases/latest)，不使用开发分支或预发布版本。2026-09-08 核对版本为 **4.9.2**，脚本没有写死此版本。

## 功能对应

| 功能 | Fish 实现 |
| --- | --- |
| Pastel Powerline 主题 | 同 Zsh 的 Starship 配置 |
| 自动建议、语法高亮、补全、历史搜索 | Fish 内置，无需安装四个 Zsh 插件 |
| Vi 模式 | 原生 fish_vi_key_bindings，默认从插入模式开始 |
| 文件与历史搜索 | 已安装 fzf 的官方 Fish 集成 |
| 目录跳转 | zoxide 的 z / zi，兼容旧版 zoxide 与 Fish 内嵌函数 |
| 工具别名 | ll / la 均显示隐藏文件，bat、fd、Git、tldr、Zellij 等 |
| Yazi | y 打开，q 退出跟随目录；Q 退出保持原目录 |
| 维护命令 | shell-doctor、shell-update，在 Fish 中操作 Fish 配置 |

启动时不安装插件、不联网更新工具，也不自动进入 Zellij。无需 Fisher、Oh My Fish 或 Go/Rust 工具链。Fish 使用自己的历史文件和语法，不会读取或转换 Zsh 历史与 local.zsh。

## 从已有 Zsh 环境增加 Fish

工具依赖已经安装过时，在 **Bash/Zsh/Fish 均可执行**：

```sh
cd ~/my-shell
git pull --ff-only
bash scripts/install-fish-config.sh
exec "$HOME/.local/bin/fish"
```

安装最新稳定版 Fish（含 fish_indent、fish_key_reader）和 zoxide 到用户目录；备份已有 Fish 配置，再追加配置入口。Zsh 文件和默认登录 Shell 不变，退出 Fish 用 `exit`（如果使用了 exec，则会退出当前 SSH 会话）。

## 全新服务器安装

在目标账号下运行，普通用户仅安装系统包时使用 sudo。以下 Debian 13 / Ubuntu 24.04 命令使用 sudo，root 去掉 sudo；Ubuntu 需先启用 universe 软件源。

```sh
sudo apt update
sudo apt install -y git curl ca-certificates jq tar xz-utils unzip file \
  btop git-delta fzf fd-find bat eza ripgrep 7zip \
  ffmpeg poppler-utils build-essential

git clone https://github.com/LazyFaiz/my-shell.git ~/my-shell
cd ~/my-shell
bash scripts/install-fish-config.sh --astronvim --zellij --yazi --tealdeer --delta
```

其他 Linux 发行版与 macOS 的工具包名参见 [多系统安装指南](../docs/install.md)。Fish 本身由本安装器下载，无需使用发行版里的旧版 Fish；Linux 需要 xz，macOS 需要 unzip。

Starship 安装：Debian 13 可用 `sudo apt install starship`，macOS 可用 `brew install starship`。Ubuntu 24.04 可在 Bash/Zsh 中运行下面整段；如果已在 Fish 中，先输入 `bash`：

```sh
bash <<'BASH'
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
curl -fsSL https://starship.rs/install.sh -o "$work/install.sh"
mkdir -p "$HOME/.local/bin"
sh "$work/install.sh" -y -b "$HOME/.local/bin"
BASH
```

SVG 预览依赖 resvg，Debian 13 可用 `sudo apt install resvg`，其他系统见安装指南。图片显示仍需 SSH 客户端/Zellij 支持，字体在本地终端选用 Nerd Font。

Ubuntu 的旧版 fzf 可能低于 Yazi 所需的 0.53。已有新版可复用；否则在尚无 `~/.fzf` 目录时使用官方 Git 安装方式：

```sh
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
bash ~/.fzf/install --bin
mkdir -p ~/.local/bin
ln -s "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
```

若已有这些路径，先检查 `fzf --version` 和现有安装，不要覆盖未知文件。通过 Git 安装的 fzf 后续仍由其原安装方式更新。

进入 Fish：

```sh
exec "$HOME/.local/bin/fish"
```

然后执行：

```fish
shell-doctor
tldr --update
tldr tar
ll
```

使用了 `--astronvim` 时，打开 `nvim` 完成首次插件下载，再执行 `:Lazy sync`、`:Mason`、`:checkhealth`，按需安装 tree-sitter-cli。已有 Neovim 配置保留。

## 安装器行为与文件

`bash scripts/install-fish.sh` 只安装 Fish 程序。Linux x86_64/ARM64 使用官方自包含 tar.xz；macOS Intel/Apple Silicon 使用官方通用 app 包中的程序及资源，不运行 GUI 安装程序。下载校验 GitHub 发布 SHA-256 摘要，验证程序与内置函数后切换用户入口。版本与三个命令入口都一致时跳过下载。

`bash scripts/install-fish-config.sh` 默认安装最新稳定版 Fish、zoxide 并写入配置。支持与 Zsh 相同的 `--astronvim`、`--zellij`、`--yazi`、`--tealdeer`、`--zoxide`、`--delta`。使用 `--config-only` 时跳过默认的 Fish/zoxide 程序下载（显式添加 `--zoxide` 仍会安装 zoxide），要求已安装 Fish 4+；不要用它检查是否为最新版本。

| 路径（默认 XDG） | 用途 |
| --- | --- |
| ~/.local/bin/fish | Fish 命令入口 |
| ~/.local/bin/fish_indent、fish_key_reader | 格式化与按键诊断 |
| ~/.local/opt/fish-版本-随机目录/ | 已安装版本和运行资源 |
| ~/.config/fish/config.fish | 保留原内容，追加一次本仓库 source 入口 |
| ~/.config/fish/my-shell/ | 本仓库的 Fish 模块、主题和 repository 路径记录 |
| ~/.config/fish/my-shell/local.fish | 个人设置，更新保留 |
| ~/.local/state/my-shell/backups/fish-*/fish/ | 安装前的完整 Fish 配置备份 |
| ~/.local/opt/fish-entry-backup-*/ | 原有三个命令入口的备份 |

不会清空 fish_variables、conf.d、functions 或 completions。已有用户配置会先执行，本仓库模块随后执行，local.fish 最后执行；同名别名与快捷键以最后加载者为准。请不要直接将仓库克隆到 Fish 配置目标目录。

zoxide 可单独运行 `bash scripts/install-zoxide.sh` 安装；Linux/macOS 的 x86_64/ARM64 均查询 [zoxide 官方最新稳定版](https://github.com/ajeetdsouza/zoxide/releases/latest)，校验 SHA-256、备份旧用户入口，安装到 `~/.local/opt/zoxide-版本-随机目录/`。2026-09-08 核对为 0.10.0，脚本不写死版本。系统包不会被卸载；首次运行本安装器后才能由统一更新入口管理。恢复使用 `zoxide-entry-backup-*` 中的 zoxide。

## 自定义与快捷键

复制示例：

```fish
cp -i "$MY_SHELL_FISH_DIR/local.fish.example" "$MY_SHELL_FISH_DIR/local.fish"
```

示例设置：

```fish
set -gx EDITOR nvim
fish_add_path --global --path "$HOME/work/bin"
# fish_default_key_bindings  # 改成 Emacs 模式
```

已有 STARSHIP_CONFIG 会保留；若从 Zsh 启动 Fish，可能继承其主题路径（当前两个主题相同）。需要独立主题时在 local.fish 设置 `set -gx STARSHIP_CONFIG "$MY_SHELL_FISH_DIR/starship.toml"`。

| 按键 | 功能 |
| --- | --- |
| Esc / i | Vi 普通模式 / 插入模式 |
| → | 接受自动建议 |
| ↑ / ↓ | Fish 原生历史搜索/多行移动 |
| Ctrl+R | fzf 历史搜索；未加载 fzf 时保留 Fish 默认行为 |
| Ctrl+T | fzf 文件搜索，默认包含隐藏文件并用 bat 预览 |
| Ctrl+F | fzf 文件搜索，排除隐藏文件（无 fzf 时保留原行为） |
| Ctrl+← / Ctrl+→ | 按词移动 |
| Ctrl+\ | 开关自动建议 |

`ll`/`la`、`lt`、`c 文件`、`mkcd 目录`、`extract 压缩包`、`gs`、`gd`、`glog`、`jqp`、`ports`、`disk`、`mem`、`zj`、`za work`、`zl`、`zk work` 等与 Zsh 对应。`zk work` 会终止 work 会话及其中的终端任务；暂时离开请使用 detach。`c` 表示 bat 查看文件；返回上一目录用 `cd -`。extract 只用于可信压缩包，目标目录已存在时拒绝解压。

Fish 不是 Bash/Zsh：例如环境变量使用 `set -gx`，不要 source .zshrc 或 Bash 安装脚本。运行本仓库脚本始终用 `bash scripts/xxx.sh`。

## 检查与更新

在 Fish 内：

```fish
shell-doctor
shell-update config          # 只更新并安装 Fish 配置，不写 Zsh
shell-update tools           # 更新已由仓库管理的工具和 Fish
shell-update tools fish      # 只更新 Fish 最新稳定版
shell-update tools tealdeer  # 只更新 tldr
shell-update tools zoxide    # 只更新 zoxide 最新稳定版
shell-update all             # Fish 配置 + 已管理工具
exec fish
```

`shell-update plugins` 会说明 Fish 使用内置功能，无需外部插件更新。不管理用户自行安装的 Fisher 插件。诊断检查当前工具、版本、配置、PATH 和 fzf 绑定，不联网、不执行预览；0 个警告返回 0，否则返回 1。字体、图片、剪贴板、tldr 缓存下载和 Neovim 插件仍需实际验证。

不在 Fish 内时，使用 `bash scripts/update.sh --shell fish config` 或 `--shell fish tools fish`。默认不加 `--shell` 仍操作 Zsh。通过 apt/brew、手工复制安装的工具不会被自动接管。

## 设置默认 Shell（可选）

先确认 Fish 配置与 SSH 登录所需 PATH 正常。Fish 不自动读取 Bash 的 /etc/profile。下面整段可从任何 Shell 运行；普通用户需 sudo：

```sh
bash -c 'set -eu; entry="$HOME/.local/bin/fish"; test -x "$entry"; if ! grep -Fxq "$entry" /etc/shells; then printf "%s\n" "$entry" | sudo tee -a /etc/shells; fi; chsh -s "$entry"'
```

root 去掉命令中的 sudo。下次登录生效；先保留当前 SSH 会话，再新开连接检查。不要删除已设为登录 Shell 的命令入口。

## 恢复

先在另一个 Bash/Zsh 会话中操作。根据安装输出定位备份，将当前 `~/.config/fish` 改名保留，再把备份中的 fish 目录复制回来。若安装前没有 Fish 配置，可移除 config.fish 中 BEGIN/END my-shell fish 段和本仓库模块目录。

程序入口恢复方法与 [维护指南](../docs/maintenance.md) 相同，对 fish、fish_indent、fish_key_reader 分别恢复。改回默认 Zsh 后再考虑移走 Fish 程序。保留版本目录，备份软链接可能仍指向它。

## 验证与参考

`bash scripts/check.sh` 必须能找到 Fish 与 Zsh，运行两种 Shell 的语法检查及回归测试。CI 在 Linux/macOS 安装 Fish 官方最新稳定版后执行。测试覆盖配置保留、版本跳过、校验失败保护、特殊路径、fzf 引号、Yazi 跟随目录及旧 zoxide 兼容；macOS 和 ARM64 的安装资源映射也有固定样例测试，交互 UI 仍需手动检查。

- [Fish 官方安装与配置](https://fishshell.com/docs/current/)
- [Fish 交互功能](https://fishshell.com/docs/current/interactive.html)
- [fzf 官方 Fish 集成](https://github.com/junegunn/fzf)
- [Starship Pastel Powerline](https://starship.rs/presets/pastel-powerline)
- [Yazi 目录跟随](https://yazi-rs.github.io/docs/quick-start/)

本配置沿用仓库根目录的 MIT 许可；Fish 程序本身及其他工具遵循各自上游许可证。

配置备份会保存软链接指向的实际内容（含目录内的链接），形成独立快照；恢复得到普通文件/目录，不会自动重建原 dotfiles 链接关系。嵌套的断链或循环链接导致备份失败时，会在写入配置前停止，请先修复链接再重试。此规则仅用于配置备份，程序入口备份仍保留软链接。
