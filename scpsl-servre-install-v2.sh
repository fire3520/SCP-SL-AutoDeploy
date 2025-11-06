#!/bin/bash

# SCP:SL 服务端一键部署脚本 / SCP:SL Server One-Click Deployment Script
# 适用于 Ubuntu 22.04+ 和 Debian 12+ / Compatible with Ubuntu 22.04+ and Debian 12+
# 作者 / Author: 开朗的火山河123 / kldhsh123
# V1.2 / GPL-3.0 license

set -euo pipefail  # 遇到错误时退出，并在未定义变量和管道失败时退出

# 导出非交互模式以便自动化 apt 操作
export DEBIAN_FRONTEND=noninteractive

# 颜色定义 / Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 语言检测和设置 / Language detection and settings
detect_language() {
    # 检测系统语言或允许用户选择 / Detect system language or allow user choice
    if [[ "${LANG:-}" =~ ^zh ]]; then
        SCRIPT_LANG="zh"
        echo "自动检测到中文环境" "Chinese environment detected automatically"
    elif [[ "${LANG:-}" =~ ^en ]]; then
        SCRIPT_LANG="en"
        echo "English environment detected automatically" "English environment detected automatically"
    else
        # 默认根据地区设置选择语言 / Default language based on locale
        echo "请选择语言 / Please select language:"
        echo "1) 中文 (Chinese)"
        echo "2) English"
        read -p "选择 / Choice (1-2): " lang_choice
        case $lang_choice in
            1) 
                SCRIPT_LANG="zh"
                echo "已选择中文界面" "Chinese interface selected"
                ;;
            2) 
                SCRIPT_LANG="en"
                echo "English interface selected" "English interface selected"
                ;;
            *) 
                SCRIPT_LANG="zh"
                echo "无效选择，默认使用中文界面" "Invalid choice, using Chinese interface by default"
                ;;
        esac
    fi
    export SCRIPT_LANG
}

# 显示作者信息 / Show author information
show_author_info() {
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo -e "${BLUE}[作者]${NC} 开朗的火山河123"
    else
        echo -e "${BLUE}[Author]${NC} kldhsh123"
    fi
}

# 双语文本配置 / Bilingual text configuration
declare -A TEXTS
TEXTS["info_zh"]="信息"
TEXTS["info_en"]="INFO"
TEXTS["success_zh"]="成功"
TEXTS["success_en"]="SUCCESS"
TEXTS["warning_zh"]="警告"
TEXTS["warning_en"]="WARNING"
TEXTS["error_zh"]="错误"
TEXTS["error_en"]="ERROR"

# 双语日志函数 / Bilingual logging functions
log_info() {
    local msg_zh="$1"
    local msg_en="${2:-$1}"
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo -e "${BLUE}[${TEXTS["info_zh"]}]${NC} $msg_zh"
    else
        echo -e "${BLUE}[${TEXTS["info_en"]}]${NC} $msg_en"
    fi
}

log_success() {
    local msg_zh="$1"
    local msg_en="${2:-$1}"
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo -e "${GREEN}[${TEXTS["success_zh"]}]${NC} $msg_zh"
    else
        echo -e "${GREEN}[${TEXTS["success_en"]}]${NC} $msg_en"
    fi
}

log_warning() {
    local msg_zh="$1"
    local msg_en="${2:-$1}"
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo -e "${YELLOW}[${TEXTS["warning_zh"]}]${NC} $msg_zh"
    else
        echo -e "${YELLOW}[${TEXTS["warning_en"]}]${NC} $msg_en"
    fi
}

log_error() {
    local msg_zh="$1"
    local msg_en="${2:-$1}"
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo -e "${RED}[${TEXTS["error_zh"]}]${NC} $msg_zh"
    else
        echo -e "${RED}[${TEXTS["error_en"]}]${NC} $msg_en"
    fi
}

# 检查是否为root用户 / Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 sudo 权限运行此脚本" "Please run this script with sudo privileges"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    log_info "正在检查系统版本..." "Checking system version..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        CODENAME="${VERSION_CODENAME:-}"
    else
        log_error "无法检测系统版本" "Cannot detect system version"
        exit 1
    fi
    
    # 使用 dpkg --compare-versions 代替 bc 比较，避免依赖未安装的工具
    if [[ $OS == "Ubuntu" ]]; then
        if dpkg --compare-versions "$VER" ge "22.04"; then
            log_success "系统版本检查通过: $OS $VER" "System version check passed: $OS $VER"
        else
            log_error "需要 Ubuntu 22.04 或更高版本，当前版本: $VER" "Ubuntu 22.04 or higher is required, current version: $VER"
            exit 1
        fi
    elif [[ $OS == "Debian GNU/Linux" ]]; then
        if dpkg --compare-versions "$VER" ge "12"; then
            log_success "系统版本检查通过: $OS $VER" "System version check passed: $OS $VER"
        else
            log_error "需要 Debian 12 或更高版本，当前版本: $VER" "Debian 12 or higher is required, current version: $VER"
            exit 1
        fi
    else
        log_error "不支持的操作系统: $OS" "Unsupported operating system: $OS"
        log_error "仅支持 Ubuntu 22.04+ 和 Debian 12+" "Only Ubuntu 22.04+ and Debian 12+ are supported"
        exit 1
    fi
}

# 检查系统架构
check_architecture() {
    log_info "正在检查系统架构..." "Checking system architecture..."
    
    ARCH=$(dpkg --print-architecture)
    if [[ $ARCH == "arm64" || $ARCH == "armhf" ]]; then
        log_error "不支持 ARM 架构 ($ARCH)" "ARM architecture ($ARCH) is not supported"
        log_error "SCP:SL 服务端只支持 x86_64 架构" "SCP:SL server only supports x86_64 architecture"
        exit 1
    fi
    
    log_success "架构检查通过: $ARCH" "Architecture check passed: $ARCH"
}

# 检查系统资源
check_resources() {
    log_info "正在检查系统资源..." "Checking system resources..."
    
    # 检查内存（更稳健地使用 /proc/meminfo）
    TOTAL_MEM=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    TOTAL_SWAP=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    TOTAL_AVAILABLE=$((TOTAL_MEM + TOTAL_SWAP))
    
    log_info "物理内存: ${TOTAL_MEM}MB" "Physical memory: ${TOTAL_MEM}MB"
    log_info "虚拟内存: ${TOTAL_SWAP}MB" "Virtual memory: ${TOTAL_SWAP}MB"
    log_info "总可用内存: ${TOTAL_AVAILABLE}MB" "Total available memory: ${TOTAL_AVAILABLE}MB"
    
    if [ "$TOTAL_MEM" -lt 3072 ]; then
        log_warning "物理内存不足3GB，可能影响服务器性能" "Physical memory less than 3GB, may affect server performance"
        log_warning "当前物理内存: ${TOTAL_MEM}MB，建议: 3GB+" "Current physical memory: ${TOTAL_MEM}MB, recommended: 3GB+"
        
        if [ "$TOTAL_AVAILABLE" -lt 3072 ]; then
            log_warning "总可用内存(物理+虚拟)也不足3GB" "Total available memory (physical+virtual) also less than 3GB"
            log_warning "建议设置虚拟内存来提高性能" "It's recommended to set up virtual memory for better performance"
            NEED_SWAP_SETUP=true
        else
            log_info "总可用内存足够，但建议增加物理内存" "Total available memory is enough, but it's recommended to increase physical memory"
        fi
    else
        log_success "内存检查通过: ${TOTAL_MEM}MB" "Memory check passed: ${TOTAL_MEM}MB"
    fi
    
    # 检查CPU核心数
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -lt 2 ]; then
        log_warning "CPU核心数不足2个，可能影响服务器性能" "CPU cores less than 2, may affect server performance"
        log_warning "当前核心数: $CPU_CORES，建议: 2+" "Current cores: $CPU_CORES, recommended: 2+"
    else
        log_success "CPU检查通过: ${CPU_CORES}核" "CPU check passed: ${CPU_CORES} cores"
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_SPACE" -lt 4 ]; then
        log_warning "磁盘空间不足4GB，可能影响安装" "Disk space less than 4GB, may affect installation"
        log_warning "当前可用空间: ${DISK_SPACE}GB，建议: 4GB+" "Current available space: ${DISK_SPACE}GB, recommended: 4GB+"
    else
        log_success "磁盘空间检查通过: ${DISK_SPACE}GB" "Disk space check passed: ${DISK_SPACE}GB"
    fi
}

# 设置虚拟内存
setup_swap() {
    log_info "正在设置虚拟内存..." "Setting up swap..."
    
    # 检查是否已有swap（更稳健）
    CURRENT_SWAP=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    if [ "${CURRENT_SWAP:-0}" -gt 0 ]; then
        log_info "当前虚拟内存: ${CURRENT_SWAP}MB" "Current virtual memory: ${CURRENT_SWAP}MB"
        
        # 询问是否要增加更多swap
        echo ""
        echo "当前系统已有 ${CURRENT_SWAP}MB 虚拟内存" "Current system has ${CURRENT_SWAP}MB virtual memory"
        echo "是否要增加更多虚拟内存？" "Do you want to add more virtual memory?"
        echo "1) 是，增加虚拟内存" "1) Yes, add virtual memory"
        echo "2) 否，保持当前设置" "2) No, keep current setting"
        echo "3) 重新配置虚拟内存" "3) Reconfigure virtual memory"
        echo ""
        read -p "请选择 (1-3): " swap_choice
        
        case $swap_choice in
            1)
                log_info "将增加额外的虚拟内存" "Additional virtual memory will be added"
                ;;
            2)
                log_info "保持当前虚拟内存设置" "Keeping current virtual memory setting"
                return
                ;;
            3)
                log_info "将重新配置虚拟内存" "Reconfiguring virtual memory"
                # 关闭现有swap
                swapoff -a || true
                # 删除现有swap文件（谨慎）
                if [ -f /swapfile ]; then
                    rm -f /swapfile || true
                fi
                ;;
            *)
                log_info "无效选择，保持现有设置" "Invalid choice, keeping current setting"
                return
                ;;
        esac
    fi
    
    # 计算推荐的swap大小
    PHYSICAL_MEM=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    
    if [ "$PHYSICAL_MEM" -lt 2048 ]; then
        RECOMMENDED_SWAP=2048  # 2GB
    elif [ "$PHYSICAL_MEM" -lt 4096 ]; then
        RECOMMENDED_SWAP=4096  # 4GB
    elif [ "$PHYSICAL_MEM" -lt 8192 ]; then
        RECOMMENDED_SWAP=4096  # 4GB
    else
        RECOMMENDED_SWAP=2048  # 2GB
    fi
    
    echo ""
    echo "虚拟内存大小建议：" "Virtual memory size recommendation:"
    echo "当前物理内存: ${PHYSICAL_MEM}MB" "Current physical memory: ${PHYSICAL_MEM}MB"
    echo "推荐虚拟内存: ${RECOMMENDED_SWAP}MB" "Recommended virtual memory: ${RECOMMENDED_SWAP}MB"
    echo ""
    echo "请选择虚拟内存大小：" "Please select virtual memory size:"
    echo "1) 1GB (1024MB)" "1) 1GB (1024MB)"
    echo "2) 2GB (2048MB) - 推荐用于低内存服务器" "2) 2GB (2048MB) - Recommended for low memory server"
    echo "3) 4GB (4096MB) - 推荐用于中等内存服务器" "3) 4GB (4096MB) - Recommended for medium memory server"
    echo "4) 自定义大小" "4) Custom size"
    echo "5) 跳过虚拟内存设置" "5) Skip virtual memory setup"
    echo ""
    read -p "请选择 (1-5): " size_choice
    
    case $size_choice in
        1)
            SWAP_SIZE=1024
            ;;
        2)
            SWAP_SIZE=2048
            ;;
        3)
            SWAP_SIZE=4096
            ;;
        4)
            echo ""
            read -p "请输入虚拟内存大小 (MB): " SWAP_SIZE
            if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] || [ "$SWAP_SIZE" -lt 512 ]; then
                log_error "无效的大小，最小为512MB" "Invalid size, minimum 512MB"
                return
            fi
            ;;
        5)
            log_info "跳过虚拟内存设置" "Skipping virtual memory setup"
            return
            ;;
        *)
            log_warning "无效选择，使用推荐大小: ${RECOMMENDED_SWAP}MB" "Invalid choice, using recommended size: ${RECOMMENDED_SWAP}MB"
            SWAP_SIZE=$RECOMMENDED_SWAP
            ;;
    esac
    
    # 检查磁盘空间是否足够
    AVAILABLE_SPACE=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//' || echo 0)
    REQUIRED_SPACE=$((SWAP_SIZE + 1024))  # 额外1GB缓冲
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_error "磁盘空间不足！" "Disk space insufficient!"
        log_error "需要: ${REQUIRED_SPACE}MB，可用: ${AVAILABLE_SPACE}MB" "Required: ${REQUIRED_SPACE}MB, available: ${AVAILABLE_SPACE}MB"
        return
    fi
    
    log_info "正在创建 ${SWAP_SIZE}MB 的虚拟内存文件..." "Creating ${SWAP_SIZE}MB virtual memory file..."
    
    # 创建swap文件名（如果已存在swap，使用不同名称）
    SWAP_FILE="/swapfile"
    if [ -f "$SWAP_FILE" ]; then
        SWAP_FILE="/swapfile_$(date +%s)"
    fi
    
    # 创建swap文件
    dd if=/dev/zero of=$SWAP_FILE bs=1M count=$SWAP_SIZE status=progress || {
        log_error "创建 swap 文件失败" "Failed to create swap file"
        return
    }
    
    # 设置正确的权限
    chmod 600 "$SWAP_FILE"
    
    # 设置为swap
    mkswap "$SWAP_FILE"
    
    # 启用swap
    swapon "$SWAP_FILE"
    
    # 添加到fstab以便开机自动挂载
    if grep -qF "$SWAP_FILE" /etc/fstab 2>/dev/null; then
        log_info "虚拟内存已在 fstab 中配置" "Virtual memory already configured in fstab"
    else
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        log_info "已添加虚拟内存到 fstab" "Virtual memory added to fstab"
    fi
    
    # 配置swap使用策略（略，保留原有交互）
    echo ""
    echo "虚拟内存设置完成！" "Virtual memory setup completed!"
    echo ""
    free -h
}

install_prerequisites() {
    log_info "正在安装必要的软件包..." "Installing necessary packages..."

    # 更新软件包列表 / Update package list
    apt update

    # 安装基础软件包 / Install basic packages
    apt install -y software-properties-common bc apt-transport-https ca-certificates

    # 添加multiverse仓库 / Add multiverse repository (如果存在 add-apt-repository)
    if command -v add-apt-repository &>/dev/null; then
        add-apt-repository multiverse -y || true
    fi

    # 添加i386架构支持 / Add i386 architecture support
    dpkg --add-architecture i386 || true

    # 再次更新软件包列表 / Update package list again
    apt update

    # 安装必要的软件包 / Install required packages
    apt install -y lib32gcc-s1 steamcmd tmux curl wget gnupg jq

    # 验证steamcmd安装 / Verify steamcmd installation
    log_info "正在验证 SteamCMD 安装..." "Verifying SteamCMD installation..."

    # 检查steamcmd是否可用 / Check if steamcmd is available
    if ! command -v steamcmd &> /dev/null; then
        # 尝试使用绝对路径 / Try using absolute path
        if [ -f "/usr/games/steamcmd" ]; then
            log_info "SteamCMD 找到，位于 /usr/games/steamcmd" "SteamCMD found at /usr/games/steamcmd"
            ln -sf /usr/games/steamcmd /usr/local/bin/steamcmd
        else
            log_error "SteamCMD 安装失败，请检查网络连接或包源" "SteamCMD installation failed, please check network connection or repositories"
            exit 1
        fi
    fi

    # 最终验证 / Final verification
    if command -v steamcmd &> /dev/null || [ -f "/usr/games/steamcmd" ]; then
        log_success "SteamCMD 验证成功" "SteamCMD verification successful"
    else
        log_error "SteamCMD 验证失败" "SteamCMD verification failed"
        exit 1
    fi

    log_success "基础软件包安装完成" "Basic packages installation completed"
}

# 安装Mono（优先使用系统仓库，失败再提示）
install_mono() {
    log_info "正在安装 Mono (优先使用系统仓库)..." "Installing Mono (prefer system repository)..."
    
    apt update
    if apt install -y mono-complete; then
        log_success "Mono 已通过系统仓库安装" "Mono installed via system repository"
        return 0
    fi

    log_warning "通过系统仓库安装 Mono 失败，跳过自动添加第三方仓库，请手动根据系统版本添加 Mono 仓库" "Installing Mono via system repo failed; skipping automatic third-party repo addition. Please add Mono repo manually if needed."

    return 1
}

# 创建Steam用户
create_steam_user() {
    log_info "正在创建 Steam 用户..." "Creating Steam user..."
    
    # 检查steam用户是否已存在
    if id "steam" &>/dev/null; then
        log_warning "Steam 用户已存在，跳过创建" "Steam user already exists, skipping creation"
        return
    fi
    
    # 创建steam用户（指定shell）
    useradd -m -s /bin/bash steam || {
        log_error "创建 steam 用户失败" "Failed to create steam user"
        exit 1
    }

    # 非交互环境：如果提供了环境变量 STEAM_PASSWORD 则设置，否则提示手动设置
    if [ -n "${STEAM_PASSWORD:-}" ]; then
        echo "steam:${STEAM_PASSWORD}" | chpasswd
        log_info "已为 steam 用户设置提供的密码" "Set provided password for steam user"
    else
        log_warning "未设置 steam 密码，请在安装后执行: sudo passwd steam 来设置密码" "No steam password set. Please run 'sudo passwd steam' after installation to set a password"
    fi

    log_success "Steam 用户创建完成" "Steam user creation completed"
}

# 设置Steam用户环境 / Setup Steam user environment
setup_steam_environment() {
    log_info "正在设置 Steam 用户环境..." "Setting up Steam user environment..."

    # 切换到steam用户并设置环境 / Switch to steam user and setup environment
    sudo -u steam bash << 'EOF'
# 设置PATH环境变量 / Set PATH environment variable
if ! grep -q "/usr/games" ~/.bashrc; then
    echo 'export PATH="/usr/games:/usr/local/bin:$PATH"' >> ~/.bashrc
fi

# 设置SteamCMD相关环境变量 / Set SteamCMD related environment variables
if ! grep -q "STEAMCMD_PATH" ~/.bashrc; then
    echo 'export STEAMCMD_PATH="/usr/games/steamcmd"' >> ~/.bashrc
fi

source ~/.bashrc

# 创建必要的目录 / Create necessary directories
mkdir -p ~/steamcmd
mkdir -p ~/steamcmd/scpsl
mkdir -p ~/.config
EOF

    # 验证环境设置 / Verify environment setup
    sudo -u steam bash -c 'source ~/.bashrc && command -v steamcmd' &> /dev/null || \
    sudo -u steam bash -c 'source ~/.bashrc && [ -f "/usr/games/steamcmd" ]' || {
        log_error "Steam 用户环境设置失败" "Steam user environment setup failed"
        exit 1
    }

    log_success "Steam 用户环境设置完成" "Steam user environment setup completed"
}

# 安装SCP:SL服务端 / Install SCP:SL server
install_scpsl_server() {
    log_info "正在安装 SCP:SL 服务端..." "Installing SCP:SL server..."

    # 切换到steam用户并安装服务端 / Switch to steam user and install server
    sudo -u steam bash << 'EOF'
cd ~
source ~/.bashrc

# 检查steamcmd可用性 / Check steamcmd availability
STEAMCMD_CMD=""
if command -v steamcmd &> /dev/null; then
    STEAMCMD_CMD="steamcmd"
elif [ -f "/usr/games/steamcmd" ]; then
    STEAMCMD_CMD="/usr/games/steamcmd"
elif [ -f "/usr/local/bin/steamcmd" ]; then
    STEAMCMD_CMD="/usr/local/bin/steamcmd"
else
    echo "错误: 找不到 steamcmd 命令" "Error: steamcmd command not found"
    exit 1
fi

echo "使用 SteamCMD: $STEAMCMD_CMD" "Using SteamCMD: $STEAMCMD_CMD"

# 初始化SteamCMD并安装SCP:SL服务端 / Initialize SteamCMD and install SCP:SL server
$STEAMCMD_CMD +force_install_dir /home/steam/steamcmd/scpsl +login anonymous +app_update 996560 validate +quit

# 验证安装 / Verify installation
if [ ! -f "/home/steam/steamcmd/scpsl/LocalAdmin" ]; then
    echo "错误: SCP:SL 服务端安装失败" "Error: SCP:SL server installation failed"
    exit 1
fi
EOF

    if [ $? -eq 0 ]; then
        log_success "SCP:SL 服务端安装完成" "SCP:SL server installation completed"
    else
        log_error "SCP:SL 服务端安装失败" "SCP:SL server installation failed"
        exit 1
    fi
}

# 检测防火墙状态 / Detect firewall status
detect_firewall() {
    local firewall_type=""
    local firewall_active=false

    # 检测 ufw / Check ufw
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            firewall_type="ufw"
            firewall_active=true
        fi
    fi

    # 检测 firewalld / Check firewalld
    if [ "$firewall_active" = false ] && command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall_type="firewalld"
            firewall_active=true
        fi
    fi

    # 检测 iptables / Check iptables
    if [ "$firewall_active" = false ] && command -v iptables &> /dev/null; then
        if iptables -L | grep -q "Chain INPUT"; then
            # 简单检测是否有规则 / Simple check for rules
            local rule_count=$(iptables -L INPUT | wc -l)
            if [ "$rule_count" -gt 3 ]; then
                firewall_type="iptables"
                firewall_active=true
            fi
        fi
    fi

    echo "$firewall_type:$firewall_active"
}

# 配置防火墙端口 / Configure firewall ports
configure_firewall_ports() {
    local firewall_info
    firewall_info=$(detect_firewall)
    local firewall_type
    firewall_type=$(echo "$firewall_info" | cut -d: -f1)
    local firewall_active
    firewall_active=$(echo "$firewall_info" | cut -d: -f2)

    if [ "$firewall_active" = "false" ]; then
        log_info "未检测到活动的防火墙，跳过端口配置" "No active firewall detected, skipping port configuration"
        return
    fi

    log_info "检测到活动的防火墙: $firewall_type" "Active firewall detected: $firewall_type"

    # 默认SCP:SL端口 / Default SCP:SL ports
    local default_ports="7777"

    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo ""
        echo "SCP:SL 服务端需要开放以下端口：" "SCP:SL server requires the following ports to be open:"
        echo "- 7777 (默认游戏端口)" "- 7777 (default game port)"
        echo "- 其他自定义端口（如果有）" "Other custom ports (if any)"
        echo ""
        read -p "请输入要开放的端口 (用空格分隔，默认: $default_ports): " user_ports
    else
        echo ""
        echo "SCP:SL server requires the following ports to be open:" "SCP:SL server requires the following ports to be open:"
        echo "- 7777 (default game port)" "- 7777 (default game port)"
        echo "- Other custom ports (if any)" "Other custom ports (if any)"
        echo ""
        read -p "Enter ports to open (space separated, default: $default_ports): " user_ports
    fi

    # 使用用户输入的端口或默认端口 / Use user input or default ports
    local ports_to_open="${user_ports:-$default_ports}"

    # 根据防火墙类型配置端口 / Configure ports based on firewall type
    case "$firewall_type" in
        "ufw")
            for port in $ports_to_open; do
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    ufw allow "$port"/tcp
                    ufw allow "$port"/udp
                    log_success "已开放端口 $port (TCP/UDP)" "Opened port $port (TCP/UDP)"
                fi
            done
            ;;
        "firewalld")
            for port in $ports_to_open; do
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    firewall-cmd --permanent --add-port="$port"/tcp
                    firewall-cmd --permanent --add-port="$port"/udp
                    log_success "已开放端口 $port (TCP/UDP)" "Opened port $port (TCP/UDP)"
                fi
            done
            firewall-cmd --reload
            ;;
        "iptables")
            for port in $ports_to_open; do
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                    iptables -A INPUT -p udp --dport "$port" -j ACCEPT
                    log_success "已开放端口 $port (TCP/UDP)" "Opened port $port (TCP/UDP)"
                fi
            done
            # 保存iptables规则 / Save iptables rules
            if command -v iptables-save &> /dev/null; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            fi
            ;;
    esac

    log_success "防火墙端口配置完成" "Firewall port configuration completed"
}

# 版本比较函数 / Version comparison function
compare_versions() {
    local version1="$1"
    local version2="$2"

    # 移除v前缀 / Remove v prefix
    version1=${version1#v}
    version2=${version2#v}

    # 使用sort进行版本比较 / Use sort for version comparison
    local higher_version
    higher_version=$(printf '%s\n%s\n' "$version1" "$version2" | sort -V | tail -n1)

    if [ "$higher_version" = "$version1" ]; then
        echo "1"  # version1 >= version2
    else
        echo "2"  # version2 > version1
    fi
}

# GitHub加速镜像列表 / GitHub acceleration mirror list
GITHUB_MIRRORS=(
    "https://j.1lin.dpdns.org/"
    "https://jiashu.1win.eu.org/"
    "https://j.1win.ggff.net/"
)

# 测试GitHub连接并选择最佳镜像 / Test GitHub connection and select best mirror
select_github_mirror() {
    local api_path="api.github.com/repos/ExSLMod-Team/EXILED/releases/latest"

    # 首先尝试直连 / First try direct connection
    if curl -s --connect-timeout 5 --max-time 10 "https://$api_path" >/dev/null 2>&1; then
        echo ""  # 返回空字符串表示直连可用 / Return empty string for direct connection
        return 0
    fi

    log_info "GitHub 直连失败，尝试使用加速镜像..." "GitHub direct connection failed, trying acceleration mirrors..."

    # 测试加速镜像 / Test acceleration mirrors
    for mirror in "${GITHUB_MIRRORS[@]}"; do
        # 确保拼接时不要重复 scheme
        local test_mirror_url="${mirror%/}/$api_path"
        if curl -s --connect-timeout 5 --max-time 10 "$test_mirror_url" >/dev/null 2>&1; then
            log_info "找到可用镜像: $mirror" "Found available mirror: $mirror"
            echo "$mirror"
            return 0
        fi
    done

    log_warning "所有 GitHub 镜像都无法连接，将使用直连重试" "All GitHub mirrors failed, will retry with direct connection"
    echo ""
}

# 获取最新EXILED版本 / Get latest EXILED version
get_latest_exiled_version() {
    log_info "正在检查 EXILED 最新版本..." "Checking latest EXILED version..."

    # 选择最佳GitHub镜像 / Select best GitHub mirror
    local github_mirror
    github_mirror=$(select_github_mirror)

    # API 相对路径
    local base_api1="api.github.com/repos/ExSLMod-Team/EXILED/releases/latest"
    local base_api2="api.github.com/repos/ExMod-Team/EXILED/releases/latest"

    # 构建 API URL（避免重复 scheme）
    local repo1_api
    local repo2_api
    if [ -n "$github_mirror" ]; then
        repo1_api="${github_mirror%/}/$base_api1"
        repo2_api="${github_mirror%/}/$base_api2"
    else
        repo1_api="https://$base_api1"
        repo2_api="https://$base_api2"
    fi

    # 获取两个仓库的最新版本信息 / Get latest version info from both repositories
    local repo1_data
    local repo2_data
    repo1_data=$(curl -s --connect-timeout 10 --max-time 30 "$repo1_api" 2>/dev/null || true)
    repo2_data=$(curl -s --connect-timeout 10 --max-time 30 "$repo2_api" 2>/dev/null || true)

    # 检查API调用是否成功 / Check if API calls were successful
    if [ -z "$repo1_data" ] && [ -z "$repo2_data" ]; then
        log_error "无法连接到 GitHub API" "Unable to connect to GitHub API"
        return 1
    fi

    # 提取版本号 / Extract version numbers
    local repo1_version=""
    local repo2_version=""
    local repo1_download_url=""
    local repo2_download_url=""

    if [ -n "$repo1_data" ] && echo "$repo1_data" | jq -e . >/dev/null 2>&1; then
        repo1_version=$(echo "$repo1_data" | jq -r '.tag_name // empty')
        local raw_url1
        raw_url1=$(echo "$repo1_data" | jq -r '.assets[] | select(.name == "Exiled.tar.gz") | .browser_download_url // empty' || echo "")
        if [ -n "$raw_url1" ]; then
            if [ -n "$github_mirror" ]; then
                repo1_download_url="${github_mirror%/}/${raw_url1#https://}"
            else
                repo1_download_url="$raw_url1"
            fi
        fi
    fi

    if [ -n "$repo2_data" ] && echo "$repo2_data" | jq -e . >/dev/null 2>&1; then
        repo2_version=$(echo "$repo2_data" | jq -r '.tag_name // empty')
        local raw_url2
        raw_url2=$(echo "$repo2_data" | jq -r '.assets[] | select(.name == "Exiled.tar.gz") | .browser_download_url // empty' || echo "")
        if [ -n "$raw_url2" ]; then
            if [ -n "$github_mirror" ]; then
                repo2_download_url="${github_mirror%/}/${raw_url2#https://}"
            else
                repo2_download_url="$raw_url2"
            fi
        fi
    fi

    # 比较版本并选择最新的 / Compare versions and select the latest
    local selected_version=""
    local selected_url=""
    local selected_repo=""

    if [ -n "$repo1_version" ] && [ -n "$repo2_version" ]; then
        local comparison
        comparison=$(compare_versions "$repo1_version" "$repo2_version")
        if [ "$comparison" = "1" ]; then
            selected_version="$repo1_version"
            selected_url="$repo1_download_url"
            selected_repo="ExSLMod-Team"
        else
            selected_version="$repo2_version"
            selected_url="$repo2_download_url"
            selected_repo="ExMod-Team"
        fi
    elif [ -n "$repo1_version" ]; then
        selected_version="$repo1_version"
        selected_url="$repo1_download_url"
        selected_repo="ExSLMod-Team"
    elif [ -n "$repo2_version" ]; then
        selected_version="$repo2_version"
        selected_url="$repo2_download_url"
        selected_repo="ExMod-Team"
    else
        log_error "无法获取 EXILED 版本信息" "Unable to get EXILED version information"
        return 1
    fi

    if [ -z "$selected_url" ]; then
        log_error "未找到 Exiled.tar.gz 下载链接" "Exiled.tar.gz download link not found"
        return 1
    fi

    log_info "找到最新版本: $selected_version (来源: $selected_repo)" "Found latest version: $selected_version (from: $selected_repo)"

    # 返回版本信息 / Return version information
    echo "$selected_version|$selected_url|$selected_repo"
}

# 安装EXILED / Install EXILED
install_exiled() {
    log_info "开始安装 EXILED..." "Starting EXILED installation..."

    # 获取最新版本信息 / Get latest version information
    local version_info
    version_info=$(get_latest_exiled_version) || {
        log_error "获取 EXILED 版本信息失败" "Failed to get EXILED version information"
        return 1
    }

    local version
    version=$(printf '%s' "$version_info" | cut -d'|' -f1)
    local download_url
    download_url=$(printf '%s' "$version_info" | cut -d'|' -f2)
    local repo_name
    repo_name=$(printf '%s' "$version_info" | cut -d'|' -f3)

    log_info "准备下载 EXILED $version..." "Preparing to download EXILED $version..."

    # 切换到steam用户进行安装 / Switch to steam user for installation
    sudo -u steam bash << EOF
cd ~

# 创建临时目录 / Create temporary directory
mkdir -p ~/temp_exiled
cd ~/temp_exiled

# 下载 Exiled.tar.gz / Download Exiled.tar.gz
echo "正在下载 EXILED $version..." "Downloading EXILED $version..."
if ! curl -L -o Exiled.tar.gz "$download_url"; then
    echo "下载失败" "Download failed"
    exit 1
fi

# 解压文件 / Extract files
echo "正在解压 EXILED..." "Extracting EXILED..."
if ! tar -xzf Exiled.tar.gz; then
    echo "解压失败" "Extraction failed"
    exit 1
fi

# 确保 ~/.config 目录存在 / Ensure ~/.config directory exists
mkdir -p ~/.config

# 移动 EXILED 文件夹到 ~/.config / Move EXILED folder to ~/.config
if [ -d "EXILED" ]; then
    if [ -d ~/.config/EXILED ]; then
        echo "备份现有 EXILED 配置..." "Backing up existing EXILED configuration..."
        mv ~/.config/EXILED ~/.config/EXILED_backup_\$(date +%Y%m%d_%H%M%S)
    fi
    mv EXILED ~/.config/
    echo "EXILED 文件夹已移动到 ~/.config/" "EXILED folder moved to ~/.config/"
else
    echo "错误: 未找到 EXILED 文件夹" "Error: EXILED folder not found"
    exit 1
fi

# 移动 SCP Secret Laboratory 文件夹到 ~/.config / Move SCP Secret Laboratory folder to ~/.config
if [ -d "SCP Secret Laboratory" ]; then
    if [ -d ~/.config/"SCP Secret Laboratory" ]; then
        echo "备份现有 SCP Secret Laboratory 配置..." "Backing up existing SCP Secret Laboratory configuration..."
        mv ~/.config/"SCP Secret Laboratory" ~/.config/"SCP Secret Laboratory_backup_\$(date +%Y%m%d_%H%M%S)"
    fi
    mv "SCP Secret Laboratory" ~/.config/
    echo "SCP Secret Laboratory 文件夹已移动到 ~/.config/" "SCP Secret Laboratory folder moved to ~/.config/"
fi

# 清理临时文件 / Clean up temporary files
cd ~
rm -rf ~/temp_exiled

echo "EXILED $version 安装完成！" "EXILED $version installation completed!"
EOF

    if [ $? -eq 0 ]; then
        log_success "EXILED $version 安装成功" "EXILED $version installation successful"
        log_info "EXILED 已安装到: /home/steam/.config/EXILED" "EXILED installed to: /home/steam/.config/EXILED"
    else
        log_error "EXILED 安装失败" "EXILED installation failed"
        return 1
    fi
}

# 创建启动脚本 / Create startup script
create_startup_script() {
    log_info "正在创建启动脚本..." "Creating startup script..."
    
    # 创建启动脚本
    sudo -u steam tee /home/steam/start_scpsl.sh << 'EOF'
#!/bin/bash

# SCP:SL 服务端启动脚本

# 获取服务端ID
SERVER_ID="${1:-scpsl}"

# 获取tmux会话名
if [ "$SERVER_ID" == "scpsl" ]; then
    SESSION_NAME="scpsl"
else
    SESSION_NAME="scpsl_$SERVER_ID"
fi

cd ~/steamcmd/scpsl

# 检查服务端文件是否存在
if [ ! -f "./LocalAdmin" ]; then
    echo "错误: LocalAdmin 文件不存在" "Error: LocalAdmin file not found"
    echo "请检查服务端安装是否成功" "Please check if server installation is successful"
    exit 1
fi

# 检查会话是否已存在
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "错误: $SESSION_NAME 会话已存在" "Error: $SESSION_NAME session already exists"
    echo "请使用 'tmux attach-session -t $SESSION_NAME' 连接到现有会话" "Please use 'tmux attach-session -t $SESSION_NAME' to connect to existing session"
    exit 1
fi

# 创建新的tmux会话并启动服务端
echo "正在启动 SCP:SL 服务端 (ID: $SERVER_ID)..." "Starting SCP:SL server (ID: $SERVER_ID)..."
echo "使用以下命令连接到服务端控制台:" "Using the following command to connect to server console:"
echo "  sudo -u steam tmux attach-session -t $SESSION_NAME" "  sudo -u steam tmux attach-session -t $SESSION_NAME"
echo ""
echo "使用以下命令分离tmux会话 (保持服务端运行):" "Using the following command to detach tmux session (keep server running):"
echo "  Ctrl+B 然后按 D" "  Ctrl+B then press D"
echo ""

tmux new-session -d -s $SESSION_NAME './LocalAdmin'
echo "SCP:SL 服务端已在后台启动" "SCP:SL server started in background"
echo "tmux 会话名称: $SESSION_NAME" "tmux session name: $SESSION_NAME"
EOF
    
    # 设置脚本权限
    chmod +x /home/steam/start_scpsl.sh
    
    log_success "启动脚本创建完成" "Startup script created successfully"
}

# 创建管理脚本
create_management_scripts() {
    log_info "正在创建管理脚本..." "Creating management script..."
    
    # 创建服务端管理脚本
    tee /usr/local/bin/scpsl-manager << 'EOF'
#!/bin/bash

# SCP:SL 服务端管理脚本

# 获取服务器ID参数，默认为scpsl
get_server_id() {
    local id="${1:-scpsl}"
    echo "$id"
}

# 获取tmux会话名
get_session_name() {
    local id="$1"
    if [ "$id" == "scpsl" ]; then
        echo "scpsl"
    else
        echo "scpsl_$id"
    fi
}

case "$1" in
    start)
        SERVER_ID=$(get_server_id "$2")
        SESSION_NAME=$(get_session_name "$SERVER_ID")
        echo "启动 SCP:SL 服务端 (ID: $SERVER_ID)..." "Starting SCP:SL server (ID: $SERVER_ID)..."
        
        # 检查是否已经运行
        if sudo -u steam tmux has-session -t $SESSION_NAME 2>/dev/null; then
            echo "服务端 $SERVER_ID 已在运行中" "Server $SERVER_ID is already running"
            exit 0
        fi
        
        # 启动服务端
        sudo -u steam bash -c "cd ~/steamcmd/scpsl && tmux new-session -d -s $SESSION_NAME './LocalAdmin'"
        echo "SCP:SL 服务端 $SERVER_ID 已在后台启动" "SCP:SL server $SERVER_ID started in background"
        echo "tmux 会话名称: $SESSION_NAME" "tmux session name: $SESSION_NAME"
        ;;
    stop)
        SERVER_ID=$(get_server_id "$2")
        SESSION_NAME=$(get_session_name "$SERVER_ID")
        echo "停止 SCP:SL 服务端 (ID: $SERVER_ID)..." "Stopping SCP:SL server (ID: $SERVER_ID)..."
        sudo -u steam tmux kill-session -t $SESSION_NAME 2>/dev/null || echo "服务端 $SERVER_ID 未运行" "Server $SERVER_ID not running"
        ;;
    restart)
        SERVER_ID=$(get_server_id "$2")
        SESSION_NAME=$(get_session_name "$SERVER_ID")
        echo "重启 SCP:SL 服务端 (ID: $SERVER_ID)..." "Restarting SCP:SL server (ID: $SERVER_ID)..."
        sudo -u steam tmux kill-session -t $SESSION_NAME 2>/dev/null || true
        sleep 2
        sudo -u steam bash -c "cd ~/steamcmd/scpsl && tmux new-session -d -s $SESSION_NAME './LocalAdmin'"
        echo "SCP:SL 服务端 $SERVER_ID 已重启" "SCP:SL server $SERVER_ID restarted"
        ;;
    status)
        if [ -z "$2" ]; then
            # 列出所有SCP:SL服务端
            echo "SCP:SL 服务端状态列表：" "SCP:SL servers status list:"
            sessions=$(sudo -u steam tmux ls 2>/dev/null | grep "^scpsl" || echo "")
            if [ -z "$sessions" ]; then
                echo "没有正在运行的SCP:SL服务端实例" "No SCP:SL server instances running"
            else
                echo "$sessions"
                echo ""
                echo "使用 'scpsl-manager status <id>' 查看特定服务端详情" "Use 'scpsl-manager status <id>' to view specific server details"
            fi
        else
            SERVER_ID=$(get_server_id "$2")
            SESSION_NAME=$(get_session_name "$SERVER_ID")
            if sudo -u steam tmux has-session -t $SESSION_NAME 2>/dev/null; then
                echo "SCP:SL 服务端 $SERVER_ID 正在运行" "SCP:SL server $SERVER_ID is running"
                echo "会话名称: $SESSION_NAME" "Session name: $SESSION_NAME"
            else
                echo "SCP:SL 服务端 $SERVER_ID 未运行" "SCP:SL server $SERVER_ID not running"
            fi
        fi
        ;;
    console)
        SERVER_ID=$(get_server_id "$2")
        SESSION_NAME=$(get_session_name "$SERVER_ID")
        echo "连接到 SCP:SL 服务端控制台 (ID: $SERVER_ID)..." "Connecting to SCP:SL server console (ID: $SERVER_ID)..."
        echo "使用 Ctrl+B 然后按 D 来分离会话" "Using Ctrl+B then D to detach session"
        
        if ! sudo -u steam tmux has-session -t $SESSION_NAME 2>/dev/null; then
            echo "错误: 服务端 $SERVER_ID 未运行" "Error: Server $SERVER_ID not running"
            exit 1
        fi
        
        sudo -u steam tmux attach-session -t $SESSION_NAME
        ;;
    update)
        echo "更新 SCP:SL 服务端..." "Updating SCP:SL server..."
        # 停止所有服务端实例
        sessions=$(sudo -u steam tmux ls 2>/dev/null | grep "^scpsl" | cut -d ':' -f1 || echo "")
        if [ -n "$sessions" ]; then
            echo "停止所有运行中的服务端实例..." "Stopping all running server instances..."
            for session in $sessions; do
                sudo -u steam tmux kill-session -t $session 2>/dev/null || true
                echo "已停止会话: $session" "Stopped session: $session"
            done
        fi
        
        sudo -u steam bash -c "cd ~ && steamcmd +force_install_dir /home/steam/steamcmd/scpsl +login anonymous +app_update 996560 validate +quit"
        echo "更新完成" "Update completed"
        ;;
    swap)
        echo "虚拟内存管理..." "Virtual memory management..."
        echo "当前内存状态：" "Current memory status:"
        free -h
        echo ""
        echo "虚拟内存文件：" "Virtual memory file:"
        swapon --show
        ;;
    setup-swap)
        echo "设置虚拟内存..." "Setting up virtual memory..."
        # 重新定义函数以供独立调用（保持简化版本）
        setup_swap() {
            CURRENT_SWAP=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
            if [ "$CURRENT_SWAP" -gt 0 ]; then
                echo "当前虚拟内存: ${CURRENT_SWAP}MB"
                read -p "是否要重新配置虚拟内存？(y/N): " reconfig
                if [[ ! $reconfig =~ ^[Yy] ]]; then
                    return
                fi
            fi
            
            read -p "请输入虚拟内存大小(MB，推荐2048): " SWAP_SIZE
            SWAP_SIZE=${SWAP_SIZE:-2048}
            
            if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] || [ "$SWAP_SIZE" -lt 512 ]; then
                echo "无效的大小，最小为512MB"
                return
            fi
            
            SWAP_FILE="/swapfile_$(date +%s)"
            echo "正在创建 ${SWAP_SIZE}MB 的虚拟内存文件..."
            dd if=/dev/zero of=$SWAP_FILE bs=1M count=$SWAP_SIZE status=progress
            chmod 600 $SWAP_FILE
            mkswap $SWAP_FILE
            swapon $SWAP_FILE
            
            if ! grep -qF "$SWAP_FILE" /etc/fstab; then
                echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
            fi
            
            echo "虚拟内存设置完成！"
            free -h
        }
        setup_swap
        ;;
    firewall)
        echo "防火墙管理 / Firewall Management" "Firewall management"
        echo "当前防火墙状态 / Current firewall status:" "Current firewall status:"

        # 检测防火墙
        if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
            echo "UFW: 活动 / Active" "UFW: Active"
            ufw status
        elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
            echo "Firewalld: 活动 / Active" "Firewalld: Active"
            firewall-cmd --list-ports
        elif command -v iptables &> /dev/null; then
            echo "Iptables: 检测到规则 / Rules detected" "Iptables: Rules detected"
            iptables -L INPUT | grep -E "(tcp|udp)" | head -10
        else
            echo "未检测到活动防火墙 / No active firewall detected" "No active firewall detected"
        fi
        ;;
    exiled)
        case "$2" in
            install)
                echo "安装 EXILED / Installing EXILED" "Installing EXILED"
                # 简化的独立安装逻辑（保持原有脚本兼容）
                sudo -u steam bash -c 'bash -s' <<'INSTALL_EXILED'
cd ~
mkdir -p ~/temp_exiled
cd ~/temp_exiled

# 测试网络连接并下载（使用脚本顶部镜像选择逻辑更好）
TEST_URL="https://api.github.com/repos/ExSLMod-Team/EXILED/releases/latest"
if ! curl -s --connect-timeout 5 --max-time 10 "$TEST_URL" >/dev/null 2>&1; then
    echo "GitHub 直连失败，尝试镜像（若可用）..."
fi

# 这里省略复杂镜像拼接，使用手动提供的下载URL 更可靠
echo "请使用 scpsl-manager exiled install 时确保网络可用或提前手动安装 EXILED"
INSTALL_EXILED
                ;;
            status)
                echo "EXILED 状态 / EXILED Status:" "EXILED status:"
                if sudo -u steam [ -d "/home/steam/.config/EXILED" ]; then
                    echo "EXILED: 已安装 / Installed" "EXILED: Installed"
                    if sudo -u steam [ -f "/home/steam/.config/EXILED/Exiled.dll" ]; then
                        echo "核心文件: 存在 / Core files: Present" "Core files: Present"
                    else
                        echo "核心文件: 缺失 / Core files: Missing" "Core files: Missing"
                    fi
                else
                    echo "EXILED: 未安装 / Not installed" "EXILED: Not installed"
                fi
                ;;
            *)
                echo "EXILED 管理 / EXILED Management" "EXILED management"
                echo "用法 / Usage: $0 exiled {install|status}" "Usage: $0 exiled {install|status}"
                ;;
        esac
        ;;
    *)
        echo "SCP:SL 服务端管理工具 / SCP:SL Server Management Tool" "SCP:SL Server Management Tool"
        exit 1
        ;;
esac
EOF
    
    # 设置管理脚本权限
    chmod +x /usr/local/bin/scpsl-manager
    
    log_success "管理脚本创建完成" "Management script created successfully"
}

# 显示完成信息 / Show completion information
show_completion_info() {
    echo ""
    echo "======================================" "======================================"
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        log_success "SCP:SL 服务端安装完成!" "SCP:SL server installation completed!"
        echo "======================================" "======================================"
        echo ""
        show_author_info
        echo ""
        echo "使用以下命令管理服务端:" "Use the following commands to manage the server:"
        echo "  scpsl-manager start [id]     # 启动服务端 (可选ID)" "  scpsl-manager start [id]     # Start server (optional ID)"
        echo "  scpsl-manager stop [id]      # 停止服务端 (可选ID)" "  scpsl-manager stop [id]      # Stop server (optional ID)"
        echo ""
    else
        log_success "SCP:SL server installation completed!" "SCP:SL server installation completed!"
        echo "======================================" "======================================"
        echo ""
        show_author_info
        echo ""
    fi
    echo ""
}

# 显示语言设置调试信息
debug_language_settings() {
    echo "当前语言设置: $SCRIPT_LANG" "Current language setting: $SCRIPT_LANG"
}

# 主函数 / Main function
main() {
    # 初始化语言设置 / Initialize language settings
    detect_language
    
    # 添加调试输出
    debug_language_settings

    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo "======================================" "======================================"
        echo "SCP:SL 服务端一键部署脚本" "SCP:SL server One-Click Deployment Script"
        echo "======================================" "======================================"
    else
        echo "======================================" "======================================"
        echo "SCP:SL Server One-Click Deployment Script" "SCP:SL Server One-Click Deployment Script"
        echo "======================================" "======================================"
    fi
    echo ""

    # 显示作者信息 / Show author information
    show_author_info
    echo ""

    # 执行检查 / Perform checks
    check_root
    check_system
    check_architecture
    check_resources
    
    # 询问是否设置虚拟内存
    if [ "${NEED_SWAP_SETUP:-false}" = true ]; then
        echo ""
        if [[ "$SCRIPT_LANG" == "zh" ]]; then
            log_warning "检测到内存不足，强烈建议设置虚拟内存" "Memory less than 3GB, it's strongly recommended to set up virtual memory"
            read -p "是否现在设置虚拟内存？(Y/n): " setup_swap_choice
        else
            log_warning "Memory less than 3GB, it's strongly recommended to set up virtual memory" "Memory less than 3GB, it's strongly recommended to set up virtual memory"
            read -p "Set up virtual memory now? (Y/n): " setup_swap_choice
        fi
        case $setup_swap_choice in
            [Nn]*)
                log_info "跳过虚拟内存设置" "Skipping virtual memory setup"
                ;;
            *)
                setup_swap
                ;;
        esac
    else
        echo ""
        if [[ "$SCRIPT_LANG" == "zh" ]]; then
            read -p "是否要设置/优化虚拟内存？(y/N): " setup_swap_choice
        else
            read -p "Setup/optimize virtual memory? (y/N): " setup_swap_choice
        fi
        case $setup_swap_choice in
            [Yy]*)
                setup_swap
                ;;
            *)
                log_info "跳过虚拟内存设置" "Skipping virtual memory setup"
                ;;
        esac
    fi
    
    echo ""
    # 网络连接测试 / Network connection test
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        log_info "正在测试网络连接..." "Testing network connection..."
    else
        log_info "Testing network connection..." "Testing network connection..."
    fi

    # 测试GitHub连接
    if ! curl -s --connect-timeout 5 --max-time 10 "https://api.github.com" >/dev/null 2>&1; then
        if [[ "$SCRIPT_LANG" == "zh" ]]; then
            log_warning "GitHub 直连失败，将在需要时自动使用加速镜像" "GitHub direct connection failed, will use acceleration mirrors when needed"
            log_info "可用镜像: j.1lin.dpdns.org, jiashu.1win.eu.org, j.1win.ggff.net" "Available mirrors: j.1lin.dpdns.org, jiashu.1win.eu.org, j.1win.ggff.net"
        else
            log_warning "GitHub direct connection failed, will use acceleration mirrors when needed" "GitHub direct connection failed, will use acceleration mirrors when needed"
            log_info "Available mirrors: j.1lin.dpdns.org, jiashu.1win.eu.org, j.1win.ggff.net" "Available mirrors: j.1lin.dpdns.org, jiashu.1win.eu.org, j.1win.ggff.net"
        fi
    else
        log_success "GitHub 连接正常" "GitHub connection is normal"
    fi

    echo ""
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        log_info "准备开始安装..." "Ready to start installation..."
        read -p "按 Enter 键继续，或 Ctrl+C 取消安装" 
    else
        log_info "Ready to start installation..." "Ready to start installation..."
        read -p "Press Enter to continue, or Ctrl+C to cancel installation" 
    fi
    
    # 执行安装步骤 / Execute installation steps
    install_prerequisites || {
        log_error "安装必要软件包时出现问题，已中止" "Failed installing prerequisites, aborting"
        exit 1
    }
    install_mono || log_warning "Mono 安装步骤未成功完成，若需要请手动安装" "Mono installation step did not complete successfully; install manually if needed"
    create_steam_user
    setup_steam_environment
    install_scpsl_server
    create_startup_script
    create_management_scripts

    # 防火墙配置 / Firewall configuration
    echo ""
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        read -p "是否要配置防火墙端口？(Y/n): " firewall_choice
    else
        read -p "Configure firewall ports? (Y/n): " firewall_choice
    fi

    case $firewall_choice in
        [Nn]*)
            log_info "跳过防火墙配置" "Skipping firewall configuration"
            ;;
        *)
            configure_firewall_ports
            ;;
    esac

    # EXILED安装选项 / EXILED installation option
    echo ""
    if [[ "$SCRIPT_LANG" == "zh" ]]; then
        echo "EXILED 是一个流行的 SCP:SL 服务端插件框架" 
        read -p "是否要安装 EXILED？(y/N): " exiled_choice
    else
        echo "EXILED is a popular SCP:SL server plugin framework" 
        read -p "Install EXILED? (y/N): " exiled_choice
    fi

    case $exiled_choice in
        [Yy]*)
            install_exiled || log_warning "EXILED 安装失败或中断" "EXILED installation failed or aborted"
            ;;
        *)
            log_info "跳过 EXILED 安装" "Skipping EXILED installation"
            ;;
    esac

    # 显示完成信息 / Show completion information
    show_completion_info
}

# 运行主函数
main "$@"