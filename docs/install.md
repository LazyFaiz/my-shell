# 多系统安装指南

适用：Debian 13、Ubuntu 24.04 及以上、Arch Linux、Fedora、macOS（Homebrew）。WSL 按内部 Linux 发行版选择命令。其他版本的软件源可能缺包；不要混用不同发行版的软件源。以下步骤安装当前用户环境，不安装 Go、Go 工具或 Fish。

## 1. 安装系统依赖

选择自己系统的一组。Linux 普通用户使用 sudo；root 用户去掉 sudo。macOS 的 brew 不要使用 sudo。

### Debian / Ubuntu

Ubuntu 需启用 universe 仓库。先安装工具，Neovim、Zellij、Starship 若版本不适用或无软件包，按下一节的官方方式安装：

```bash
sudo apt update
sudo apt install -y zsh git curl ca-certificates file btop jq tealdeer git-delta \
  fzf fd-find bat eza zoxide ripgrep unzip 7zip tar gzip bzip2 xz-utils \
  build-essential ffmpeg poppler-utils
```

Debian 13 可直接安装 Starship 和 SVG 预览工具：

```bash
sudo apt install -y starship resvg
```

### Arch Linux

```bash
sudo pacman -Syu --needed zsh git curl ca-certificates file btop jq tealdeer git-delta \
  fzf fd bat eza zoxide ripgrep unzip 7zip tar gzip bzip2 xz \
  base-devel neovim zellij starship ffmpeg poppler resvg
```

### Fedora

```bash
sudo dnf install -y zsh git curl ca-certificates file btop jq tealdeer git-delta \
  fzf fd-find bat eza zoxide ripgrep unzip 7zip tar gzip bzip2 xz \
  gcc gcc-c++ make neovim zellij starship ffmpeg-free poppler-utils
```

### macOS

先安装 [Homebrew](https://brew.sh/)。编译器来自 Xcode Command Line Tools；没有时执行 `xcode-select --install` 并完成弹窗安装。

```bash
brew install zsh git file btop jq tealdeer git-delta fzf fd bat eza zoxide \
  ripgrep unzip sevenzip neovim zellij starship ffmpeg poppler resvg
```

## 2. 检查 Neovim、Zellij、Starship

```bash
nvim --version
zellij --version
starship --version
```

AstroNvim 当前要求 **Neovim 0.11 或以上的稳定版本**、C 编译器和 Tree-sitter CLI。Tree-sitter CLI 可在首次进入 AstroNvim 后通过 Mason 安装。不要仅根据已安装 `neovim` 软件包判断版本足够。

Linux 缺少这些工具时，使用下列官方来源的安装步骤。已有满足要求的版本可以跳过。macOS 使用上面的 Homebrew 命令。

### Linux / macOS：GitHub 最新稳定版 Neovim

使用 `--astronvim` 时，配置脚本会自动调用 `scripts/install-neovim.sh`，无需先手动升级。无论原版本是 0.10、较新稳定版还是未安装，都会查询 GitHub Releases 的 `/latest`，排除 nightly 和预发布，并下载此次查询得到的确切版本。

也可在克隆本仓库后单独运行：

```bash
cd ~/my-shell
bash scripts/install-neovim.sh
export PATH="$HOME/.local/bin:$PATH"
```

脚本需要 `curl`、`jq`、`tar` 和 `sha256sum` 或 `shasum`（上面的依赖命令及系统基础工具已覆盖）。支持 Linux/macOS 的 x86_64、ARM64；macOS 按当前进程架构选择，Apple Silicon 请优先使用原生终端。

下载文件必须与 GitHub API 提供的 SHA-256 摘要一致，并通过 Neovim 无配置启动检查，之后才切换 `~/.local/bin/nvim`。程序安装到 `~/.local/opt/nvim-版本-随机目录/`；原有用户命令入口会备份，apt/Homebrew 安装不被卸载。失败会退出，不会继续安装 AstroNvim。较旧系统若不兼容最新二进制，需要先升级系统。

重复执行会查询最新稳定版；安装标记与实际版本一致时跳过安装包下载。当前终端需要执行 `rehash`（Zsh）或 `hash -r`（Bash），或重新打开 Zsh，然后用 `command -v nvim` 和 `nvim --version` 确认。

### Linux / macOS：自动安装 Zellij

主脚本加 `--zellij` 即可安装 GitHub 最新稳定版；也可单独运行：

```bash
cd ~/my-shell
bash scripts/install-zellij.sh
export PATH="$HOME/.local/bin:$PATH"
```

支持 Linux/macOS 的 x86_64、ARM64，依赖 `curl`、`jq`、`tar` 和 SHA-256 工具。下载后校验 GitHub 发布摘要，并运行 `zellij --version`，成功后才切换 `~/.local/bin/zellij`。旧入口备份在 `~/.local/opt/zellij-entry-backup-*/`，版本程序位于 `~/.local/opt/zellij-版本-随机目录/`。重复执行会检查最新版，版本一致时跳过下载，不改 Zellij 配置，不自动创建或启动会话。

已有 Zsh 配置的服务器，可以直接更新并执行：

```bash
cd ~/my-shell
git pull --ff-only
bash scripts/install-config.sh --zellij
exec zsh
```

然后使用 `zellij --version` 检查，`za work` 创建或连接会话。

### Linux / macOS：自动安装 Yazi

基础文件管理使用 `--yazi`，同时安装 GitHub 最新稳定版中的 `yazi` 和配套 `ya`。已有配置的服务器执行：

```bash
cd ~/my-shell
git pull --ff-only
bash scripts/install-config.sh --yazi
exec zsh
```

单独安装程序可用 `bash scripts/install-yazi.sh`；需要 `curl`、`jq`、`unzip`、`file` 及 SHA-256 工具。Linux/macOS 均支持 x86_64/ARM64，下载后校验摘要并检查两个程序能否运行，然后备份原入口、安装至用户目录。配置和插件目录不被重写。

```zsh
yazi --version
ya --version
y          # 打开文件管理器，q 退出后跟随最后浏览的目录
y ~/my-shell
```

`Q` 退出并保持 Shell 原目录。`yazi` 原命令仍可直接使用，但退出后不改变 Shell 目录。文件列表中 `.` 切换隐藏文件，`Enter` 打开，`r` 重命名，`y` 复制、`p` 粘贴；`F1` 查看帮助。这里的 Yazi 内部 `y` 按键和 Shell 的 `y` 函数是不同操作。

基础功能复用现有 jq、fd、ripgrep、fzf、zoxide 和 7-Zip。Debian/Ubuntu 只有 `fdfind` 时，安装器会在没有现有 `fd` 入口的情况下创建 `~/.local/bin/fd` 软链接，因为 Yazi 不能使用 Zsh 的 alias。Yazi 的 fzf 导航需要 fzf >= 0.53；旧版本不会阻止基础文件浏览。

预览依赖的安装与已有服务器补装步骤见下节。图片显示和剪贴板能力取决于本地终端与 Zellij/SSH 的支持，不是安装 Yazi 后所有终端都能直接显示图片。

程序位于 `~/.local/opt/yazi-版本-随机目录/`，旧 `yazi` / `ya` 入口备份在 `~/.local/opt/yazi-entry-backup-*/`。重新安装后执行 `exec zsh` 即可启用 `y`。自定义设置按 Yazi 官方文档放在 `~/.config/yazi/`。

### 补齐 Yazi 预览依赖

以下四类依赖由系统包管理器安装；`install-config.sh --yazi` 只安装 Yazi/ya 与用户配置，`shell-update all` 也不会代装系统软件包。已经装过的包无需卸载，重复运行安装命令即可补齐。

| 功能 | 命令 | Debian / Ubuntu 软件包 | Arch / Homebrew 软件包 |
| --- | --- | --- | --- |
| 视频缩略图 | `ffmpeg` | `ffmpeg` | `ffmpeg` |
| PDF 预览 | `pdftoppm` | `poppler-utils` | `poppler` |
| SVG 预览 | `resvg` | `resvg`（取决于发行版软件源） | `resvg` |
| 压缩包预览和解压 | `7zz` 或 `7z` | `7zip` | `7zip` / `sevenzip` |

**已有 Debian 13 服务器（root）直接执行：**

```bash
apt update
apt install -y ffmpeg poppler-utils resvg 7zip
```

普通用户在两条命令前加 `sudo`。其他系统选择对应命令：

```bash
# Ubuntu：先安装软件源中的三项，再检查 resvg 是否有候选版本
sudo apt update
sudo apt install -y ffmpeg poppler-utils 7zip
apt-cache policy resvg
# 有候选版本时执行：sudo apt install -y resvg

# Arch Linux
sudo pacman -Syu --needed ffmpeg poppler resvg 7zip

# Fedora：官方源中的 ffmpeg-free 支持的编解码器少于完整 FFmpeg
sudo dnf install -y ffmpeg-free poppler-utils 7zip
dnf info resvg
# 软件源提供时执行：sudo dnf install -y resvg

# macOS（Homebrew）
brew install ffmpeg poppler resvg sevenzip
```

Ubuntu/Fedora 软件源没有 `resvg` 时，从 [resvg 官方 Releases](https://github.com/linebender/resvg/releases) 选择与系统和 CPU 架构匹配的稳定版命令行程序，解压后将 `resvg` 放入 `~/.local/bin/` 并授予执行权限；不要安装其他发行版的包。也可在已有 Rust/Cargo 的环境执行 `cargo install resvg --locked`，随后把 `~/.cargo/bin` 加入 PATH。本仓库不自动安装 Rust 工具链。

安装后在 Zsh 中检查：

```zsh
rehash
ffmpeg -version | head -n 1
pdftoppm -v
resvg --version
if command -v 7zz >/dev/null; then 7zz i; else 7z i; fi
shell-doctor
y
```

`7zz` 和 `7z` 有一个可用即可，不需要为了另一个 `absent` 重复安装。关闭并重新打开 Yazi，分别选中视频、PDF、SVG 和压缩包，确认实际预览。命令能运行不代表当前 SSH 客户端支持图片显示；压缩格式支持也取决于 7-Zip 的发行版构建。依赖用途参见 [Yazi 官方安装文档](https://yazi-rs.github.io/docs/installation/)。

### Linux：安装 Starship（软件源没有时）

```bash
bash <<'BASH'
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh -o "$work/install-starship.sh"
sh "$work/install-starship.sh" -y -b "$HOME/.local/bin"
BASH
```

在继续下一步前，让当前 Bash 找到用户目录中的程序：

```bash
export PATH="$HOME/.local/bin:$PATH"
nvim --version
zellij --version
starship --version
```

## 3. 安装仓库配置

在目标账号下运行；root 执行会配置 root，不会配置其他用户。普通用户只在安装系统软件时使用 sudo，以下脚本不加 sudo。

```bash
git clone https://github.com/LazyFaiz/my-shell.git ~/my-shell
cd ~/my-shell
bash scripts/install-config.sh --astronvim --zellij --yazi --delta
```

已有仓库时进入原目录执行 `git pull --ff-only`，不必重新克隆。

脚本支持 Linux/macOS 自带 Bash，使用现有的 Zsh、Git 和 delta；启用 `--astronvim` / `--zellij` / `--yazi` 时额外从 GitHub 安装对应工具的最新稳定版到用户目录。它会：

- 备份旧 Zsh 配置、入口文件；更新模块时保留 `local.zsh`。
- 在 `~/.zshenv` 追加一次配置入口，保留原文件内容。
- 使用 `--zellij` 时安装 GitHub 最新稳定版 Zellij，备份旧入口；原配置与会话不变。
- 使用 `--yazi` 时安装最新稳定版 Yazi 和 ya，保留已有 Yazi 设置。
- 使用 `--delta` 时备份 Git 配置，再启用彩色 diff、行号、差异导航；不改 Git 用户名和邮箱。
- 使用 `--astronvim` 时安装最新稳定版 Neovim，再克隆官方 AstroNvim 模板；已有 Neovim 配置会保留，但 Neovim 程序仍会更新。
- 首次安装 AstroNvim 时，将原有 Neovim data/state/cache 目录移到同级 `.bak.时间戳` 目录。

省略全部选项只安装 Zsh 配置。备份位置会在完成后打印，默认在 `~/.local/state/my-shell/backups/`。如果以前设置过自定义 `ZDOTDIR`，需确保 Zsh 实际读取的 `.zshenv` 也包含这里的入口，或先取消旧 `ZDOTDIR` 再启动。

## 4. 安装 Zsh 插件

```bash
zsh
```

进入 Zsh 后执行：

```zsh
zplugin-install
exec zsh
```

共四个插件：自动建议、语法高亮、历史子串搜索和增强 Vi 模式。启动时只加载本地插件，不联网下载。后续更新执行 `zplugin-update` 后重新打开 Zsh。

## 5. 完成 AstroNvim 与工具初始化

```zsh
tldr --update
nvim
```

首次打开 Neovim 会下载 AstroNvim 插件。等待完成后执行：

```vim
:Lazy sync
:Mason
:checkhealth
```

在 Mason 中确认 `tree-sitter-cli` 已安装；没有时安装它，再按 `:checkhealth` 的实际结果处理缺少的依赖。这里不添加任何 Go pack，也不安装 Go 工具链。Node.js、Python 和具体语言服务器按实际编辑需求安装，不是此次默认安装内容。

如果已有 Neovim 配置且想改用 AstroNvim，先退出 Neovim，再备份旧配置并重跑安装脚本：

```bash
mv "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim.bak.$(date +%Y%m%d-%H%M%S)"
bash scripts/install-config.sh --astronvim
```

Zellij 手动运行 `zj`，命名会话可用 `za work`，查看会话用 `zl`。不会每次打开 SSH 时自动启动。

请在本地 SSH 客户端或终端启用 Nerd Font 和真彩色。远程服务器不需要安装字体。纯 SSH 环境不能仅靠安装 xclip 就访问本地剪贴板；复制功能取决于终端的 OSC 52 支持及 Neovim/Zellij 设置。图标、剪贴板和快捷键需在实际终端中检查。

## 6. 默认 Shell（可选）

确认新配置正常后执行：

```sh
command -v zsh
cat /etc/shells
chsh -s "$(command -v zsh)"
```

如果 Zsh 路径未出现在 `/etc/shells`，先由管理员将该绝对路径加入文件。macOS Homebrew Zsh 也可能需要这一步。重新登录后生效。恢复默认 Bash 时可用 `chsh -s /bin/bash`（Linux 且该路径已在 `/etc/shells` 中）。

## 更新与恢复

- 更新配置：在仓库执行 `git pull --ff-only`，再运行 `bash scripts/install-config.sh`，随后 `exec zsh`。
- 更新 AstroNvim：在 Neovim 中执行 `:Lazy sync`；已有配置不会被安装脚本重置。
- 更新工具：包管理器安装的软件用原包管理器更新；用户目录下载的软件按对应步骤重新安装。
- 恢复 Zsh：退出当前 Zsh，把备份目录中的 `zsh`、`zshenv`、`zshrc` 恢复到原位置。若安装前没有 `.zshenv`，删除脚本追加的 `BEGIN/END my-shell` 段即可。
- 恢复 Git：从备份中的 `gitconfig`、`xdg-gitconfig` 恢复对应配置文件。若安装前没有配置文件，可用 `git config --global --unset-all` 分别移除脚本设置的五个键。
- 恢复 Neovim：先备份或移走新 `nvim` 配置，再把手动备份的配置与 `.bak` 运行目录移回原路径。

`extract` 会解压到压缩包旁的新目录 `文件名.extracted`，保留原压缩包并拒绝复用已有目录。它不是解压沙箱，仅用于可信压缩包。

## 官方参考

- [AstroNvim 安装要求与模板](https://docs.astronvim.com/)
- [Neovim 官方安装说明](https://github.com/neovim/neovim/blob/master/INSTALL.md)
- [Zellij 安装](https://zellij.dev/documentation/installation)
- [Starship 安装](https://starship.rs/guide/)
- [delta 配置](https://dandavison.github.io/delta/get-started.html)

- [Yazi 安装](https://yazi-rs.github.io/docs/installation/)
- [Yazi 目录跟随与快捷键](https://yazi-rs.github.io/docs/quick-start/)

## 安装器验证

在已安装 Bash、Python 3、jq、tar 和 SHA-256 工具的 Linux/macOS 上执行：

```sh
bash -n scripts/install-config.sh
bash -n scripts/install-neovim.sh
bash -n scripts/install-zellij.sh
bash -n scripts/install-yazi.sh
python3 -B -m unittest discover -s tests -v
```

测试使用隔离 HOME、模拟发布信息和下载文件，覆盖四种系统/架构映射、旧入口备份、重复安装、预发布拒绝、校验失败、下载失败及二进制启动失败。它验证安装逻辑，不代替真实 macOS/Linux 二进制与系统兼容性测试。

完整的环境检查、分类更新、版本跳过和故障恢复流程见 [维护与恢复指南](maintenance.md)。
