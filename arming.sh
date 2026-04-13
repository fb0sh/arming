#!/bin/sh

# arming.sh - 自动化 Git 仓库管理工具
# 功能：一键导出、并行克隆(逻辑预留)、全量更新
# 优化：针对浅色背景，支持进度预告与原生 Git 输出

set -u

# 颜色配置：改为检测 stderr (-t 2) 是否为终端
# 这样即便你使用 > git.list 重定向了 stdout，屏幕上的 [INFO] 依然有颜色
if command -v tput >/dev/null 2>&1 && [ -t 2 ]; then
    cyan="$(tput setaf 6)"; green="$(tput setaf 2)"; yellow="$(tput setaf 3)"; red="$(tput setaf 1)"; reset="$(tput sgr0)"
else
    cyan=""; green=""; yellow=""; red=""; reset=""
fi

log_info() { printf "%s[INFO]%s %s\n" "$cyan" "$reset" "$*" 1>&2; }
log_warn() { printf "%s[WARN]%s %s\n" "$yellow" "$reset" "$*" 1>&2; }
log_error() { printf "%s[ERROR]%s %s\n" "$red" "$reset" "$*" 1>&2; }
log_header() { printf "\n%s>>> %s <<<%s\n" "$cyan" "$*" "$reset" 1>&2; }

usage() {
    cat <<'EOF'
使用说明:
  ./arming.sh <目标目录>              # 更新模式 (执行 git pull)
  ./arming.sh <目标目录> > git.list   # 导出模式 (记录远程仓库地址)
  ./arming.sh <目标目录> < git.list   # 克隆模式 (根据列表克隆)

模式自动识别逻辑:
  - 标准输入被占用 (来自管道/文件) -> 克隆模式
  - 标准输出被占用 (重定向到文件) -> 导出模式
  - 否则                       -> 更新模式
EOF
    exit 1
}

ensure_git() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "未找到 git，请先安装。"
        exit 1
    fi
}

ensure_dir() {
    if [ ! -d "$1" ]; then
        if ! mkdir -p "$1"; then
            log_error "无法创建目录: $1"
            exit 1
        fi
    fi
}

derive_name() {
    url=$1
    trimmed=${url%.git}
    repo=${trimmed##*/}
    parent=${trimmed%/*}
    case $parent in
        *://*) user=${parent##*/} ;;
        *:*) user=${parent##*:} ;;
        *) user=$parent ;;
    esac
    [ -n "$repo" ] || repo="repo"
    [ -n "$user" ] || user="user"
    printf "%s_%s" "$repo" "$user"
}

# --- 模式 1: 导出 ---
export_mode() {
    dir=$1
    count=0
    # 这里的 log_info 会显示颜色，因为我们检测的是 stderr
    log_info "正在扫描目录 $dir 中的 Git 仓库..."
    
    for repo_dir in "$dir"/*; do
        [ -d "$repo_dir/.git" ] || continue
        remote=$(git -C "$repo_dir" config --get remote.origin.url 2>/dev/null || true)
        [ -n "$remote" ] || continue
        name=$(derive_name "$remote")
        
        # 核心数据输出到 stdout (即重定向到文件的地方)，不带颜色代码
        printf "%s %s\n" "$remote" "$name"
        count=$((count + 1))
    done
    
    if [ $count -eq 0 ]; then
        log_warn "在 $dir 中未找到任何 Git 仓库。"
    else
        log_info "成功导出 $count 条远程地址。"
    fi
}

# --- 模式 2: 克隆 ---
clone_mode() {
    dir=$1
    ensure_dir "$dir"
    ok=0; skip=0; fail=0; total=0
    
    # 预读输入流到临时文件，以便统计总数
    tmp=$(mktemp "${TMPDIR:-/tmp}/arming.XXXXXX") || exit 1
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] || continue
        printf "%s\n" "$line" >> "$tmp"
        total=$((total + 1))
    done
    
    if [ "$total" -eq 0 ]; then
        log_warn "输入列表为空，无克隆任务。"
        rm -f "$tmp"
        return
    fi

    # 【新增】开始前的总数预告
    log_info "准备就绪！即将开始克隆任务，共计 $total 个仓库。"
    log_info "目标目录: $dir"
    
    while IFS= read -r line || [ -n "$line" ]; do
        set -- $line
        [ $# -ge 1 ] || continue
        remote=$1
        shift
        if [ $# -ge 1 ]; then
            name=$1
        else
            name=$(derive_name "$remote")
        fi
        
        idx=$((ok + skip + fail + 1))
        prefix="[$idx/$total]"
        
        if [ -d "$dir/$name/.git" ]; then
            log_info "$prefix [跳过] $name (目录已存在)"
            skip=$((skip + 1))
            continue
        fi
        
        # 视觉隔离：打印原生输出的头部
        log_header "$prefix 正在克隆 $name"
        
        if (cd "$dir" && git clone --depth 1 "$remote" "$name"); then
            log_info "$prefix [成功] $name"
            ok=$((ok + 1))
        else
            log_error "$prefix [失败] $name"
            fail=$((fail + 1))
        fi
    done < "$tmp"
    
    rm -f "$tmp"
    log_info "克隆完成! 成功: $ok, 跳过: $skip, 失败: $fail (总计: $total)"
}

# --- 模式 3: 更新 ---
update_mode() {
    dir=$1
    ok=0; fail=0; total=0; idx=0
    
    for repo_dir in "$dir"/*; do
        [ -d "$repo_dir/.git" ] && total=$((total + 1))
    done

    if [ "$total" -eq 0 ]; then
        log_warn "目录 $dir 中未发现 Git 仓库。"
        return
    fi

    log_info "发现 $total 个仓库，准备开始批量更新 (git pull)..."

    for repo_dir in "$dir"/*; do
        [ -d "$repo_dir/.git" ] || continue
        idx=$((idx + 1))
        name=$(basename "$repo_dir")
        prefix="[$idx/$total]"
        
        log_header "$prefix 正在更新 $name"
        
        if (cd "$repo_dir" && git pull --ff-only); then
            log_info "$prefix [成功] $name"
            ok=$((ok + 1))
        else
            log_error "$prefix [失败] $name"
            fail=$((fail + 1))
        fi
    done
    
    log_info "更新完成! 成功: $ok, 失败: $fail (总计: $total)"
}

main() {
    [ "$#" -eq 1 ] || usage
    target_dir=$1
    ensure_git

    # 逻辑判定
    if [ ! -t 0 ]; then
        # stdin 不是终端 -> 管道输入模式 (Clone)
        clone_mode "$target_dir"
    elif [ ! -t 1 ]; then
        # stdout 不是终端 -> 重定向输出模式 (Export)
        export_mode "$target_dir"
    else
        # 均为终端 -> 普通交互模式 (Update)
        update_mode "$target_dir"
    fi
}

main "$@"
