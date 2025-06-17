#!/bin/bash
if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
    auto_install=true
    for i in "$@"; do
        case $i in
            --path=*|--root=*)
            file_path="${i#*=}"
            ;;
            --port=*)
            port="${i#*=}"
            ;;
            --user=*)
            admin_user="${i#*=}"
            ;;
            --password=*)
            admin_password="${i#*=}"
            ;;
            --concurrent=*|--conn=*)
            concurrent="${i#*=}"
            ;;
            --help|-h)
            echo "FileBrowser自动安装模式用法:"
            echo "  $0 --auto [选项]"
            echo ""
            echo "选项:"
            echo "  --path=PATH      指定文件存储路径 (默认: /home/files)"
            echo "  --port=PORT      指定端口 (默认: 8080)"
            echo "  --user=USER      指定管理员用户名 (默认: admin)"
            echo "  --password=PASS  指定管理员密码 (默认: admin)"
            echo "  --concurrent=NUM 并发连接数 (默认: 10)"
            echo "  --help, -h       显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 --auto --path=/data/files --port=8888 --user=admin --password=secure123 --concurrent=20"
            exit 0
            ;;
        esac
    done
    file_path=${file_path:-/home/files}
    port=${port:-8080}
    admin_user=${admin_user:-admin}
    admin_password=${admin_password:-admin}
    concurrent=${concurrent:-10}
    install_filebrowser_silent
    exit 0
fi
show_menu() {
    clear
    echo "===== FileBrowser 管理脚本 ====="
    echo "1. 安装 FileBrowser"
    echo "2. 卸载 FileBrowser"
    echo "3. 重置管理员密码"
    echo "4. 静默安装(自动)"
    echo "5. 优化传输性能"
    echo "6. 退出"
    echo "================================="
    echo -n "请输入选项 [1-6]: "
    read -r choice
    case $choice in
        1) install_filebrowser ;;
        2) uninstall_filebrowser ;;
        3) reset_admin_password ;;
        4) 
            echo "请输入文件存储路径 (默认: /home/files):"
            read -r file_path
            file_path=${file_path:-/home/files}
            
            echo "请输入端口 (默认: 8080):"
            read -r port
            port=${port:-8080}
            
            echo "请输入管理员用户名 (默认: admin):"
            read -r admin_user
            admin_user=${admin_user:-admin}
            
            echo "请输入管理员密码 (默认: admin):"
            read -r admin_password
            admin_password=${admin_password:-admin}
            
            echo "请输入并发连接数 (默认: 10):"
            read -r concurrent
            concurrent=${concurrent:-10}
            
            install_filebrowser_silent
            ;;
        5) optimize_performance ;;
        6) exit 0 ;;
        *) echo "无效选项，请重新选择"; sleep 2; show_menu ;;
    esac
}
get_db_path() {
    if [ -f "/etc/systemd/system/filebrowser.service" ]; then
        DB_PATH=$(grep -o "\-\-database [^ ]*" /etc/systemd/system/filebrowser.service | cut -d' ' -f2 | tr -d '"')
        if [ -z "$DB_PATH" ]; then
            DB_PATH=$(grep -o "\-d [^ ]*" /etc/systemd/system/filebrowser.service | cut -d' ' -f2 | tr -d '"')
        fi
        if [ -z "$DB_PATH" ]; then
            DB_PATH="$HOME/.config/filebrowser/filebrowser.db"
        fi
    else
        DB_PATH="$HOME/.config/filebrowser/filebrowser.db"
    fi
    echo "$DB_PATH"
}
optimize_performance() {
    echo "开始优化FileBrowser传输性能..."
    DB_PATH=$(get_db_path)
    if [ ! -f "$DB_PATH" ]; then
        echo "错误: 未找到FileBrowser数据库文件，请先安装FileBrowser"
        echo ""
        echo "按任意键返回主菜单..."
        read -n 1
        show_menu
        return
    fi
    echo "当前数据库路径: $DB_PATH"
    echo "请输入最大并发连接数 (默认: 10):"
    read -r concurrent
    concurrent=${concurrent:-10}
    echo "正在修改FileBrowser配置..."
    filebrowser config set --branding.name "高速文件浏览器" --database "$DB_PATH"
    filebrowser config set --enableThumbnails --enableExec --database "$DB_PATH"
    if [ -f "/etc/systemd/system/filebrowser.service" ]; then
        sudo cp /etc/systemd/system/filebrowser.service /etc/systemd/system/filebrowser.service.bak
        PORT=$(grep -o "\--port [^ ]*" /etc/systemd/system/filebrowser.service | cut -d' ' -f2 || echo "8080")
        ROOT=$(grep -o "\--root [^ ]*" /etc/systemd/system/filebrowser.service | cut -d' ' -f2 || echo "/home/files")
        cat > filebrowser.service << EOL
[Unit]
Description=FileBrowser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser --address 0.0.0.0 --port $PORT --root $ROOT --database "$DB_PATH" --concurrent $concurrent --socket-perm 0666 --enable-thumbnail-gzip --enable-exec --cache-dir /tmp/filebrowser_cache
Restart=on-failure
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOL
        echo "更新systemd服务..."
        sudo mv filebrowser.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl restart filebrowser
        mkdir -p /tmp/filebrowser_cache
        chmod 777 /tmp/filebrowser_cache
        echo "性能优化完成！已应用以下设置:"
        echo "- 并发连接数: $concurrent"
        echo "- 启用Gzip压缩和缩略图"
        echo "- 增加文件描述符限制"
        echo "- 添加缓存目录"
        echo ""
        echo "建议的系统优化:"
        echo "1. 添加以下内容到 /etc/sysctl.conf 文件以优化网络性能:"
        echo "   net.core.rmem_max=16777216"
        echo "   net.core.wmem_max=16777216"
        echo "   net.ipv4.tcp_rmem=4096 87380 16777216"
        echo "   net.ipv4.tcp_wmem=4096 65536 16777216"
        echo "   net.ipv4.tcp_window_scaling=1"
        echo "   net.ipv4.tcp_timestamps=1"
        echo "   net.ipv4.tcp_sack=1"
        echo "   net.core.netdev_max_backlog=5000"
        echo ""
        echo "   应用命令: sudo sysctl -p"
    else
        echo "未找到FileBrowser服务文件，无法优化"
    fi
    echo ""
    echo "按任意键返回主菜单..."
    read -n 1
    show_menu
}
install_filebrowser_silent() {
    echo "开始静默安装FileBrowser..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        echo "检测到系统: $OS"
    else
        echo "无法检测系统类型，将尝试使用通用安装方法"
        OS="Unknown"
    fi
    if ! command -v curl &> /dev/null; then
        echo "安装curl..."
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            sudo apt-get update -qq
            sudo apt-get install -y curl -qq
        elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
            sudo yum install -y curl -q
        else
            echo "请手动安装curl后再运行此脚本"
            exit 1
        fi
    fi
    echo "下载并安装FileBrowser..."
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
    echo "创建配置目录..."
    mkdir -p ~/.config/filebrowser
    mkdir -p "$file_path"
    DB_PATH="$HOME/.config/filebrowser/filebrowser.db"
    echo "初始化FileBrowser配置..."
    filebrowser config init --address 0.0.0.0 --port "$port" --root "$file_path" --database "$DB_PATH"
    filebrowser config set --enableThumbnails --enableExec --database "$DB_PATH"
    echo "创建管理员用户..."
    filebrowser users add "$admin_user" "$admin_password" --perm.admin --database "$DB_PATH" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "创建用户失败，尝试删除已存在的用户后重新创建..."
        filebrowser users rm "$admin_user" --database "$DB_PATH" 2>/dev/null
        filebrowser users add "$admin_user" "$admin_password" --perm.admin --database "$DB_PATH"
    fi
    mkdir -p /tmp/filebrowser_cache
    chmod 777 /tmp/filebrowser_cache
    echo "创建systemd服务..."
    cat > filebrowser.service << EOL
[Unit]
Description=FileBrowser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser --address 0.0.0.0 --port $port --root "$file_path" --database "$DB_PATH" --concurrent $concurrent --socket-perm 0666 --enable-thumbnail-gzip --enable-exec --cache-dir /tmp/filebrowser_cache
Restart=on-failure
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOL
    echo "安装systemd服务..."
    sudo mv filebrowser.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable filebrowser
    sudo systemctl start filebrowser
    sleep 2
    if systemctl is-active --quiet filebrowser; then
        echo "FileBrowser服务启动成功！"
    else
        echo "警告: FileBrowser服务可能未成功启动，请检查状态: sudo systemctl status filebrowser"
    fi
    SERVER_IP=$(curl -s ifconfig.me || wget -qO- ifconfig.co || hostname -I | awk '{print $1}')
    echo "============================================================"
    echo "FileBrowser安装完成！"
    echo "============================================================"
    echo "管理员用户名: $admin_user"
    echo "管理员密码: $admin_password"
    echo "访问地址: http://$SERVER_IP:$port"
    echo "文件存储位置: $file_path"
    echo "数据库位置: $DB_PATH"
    echo "并发连接数: $concurrent"
    echo "============================================================"
    echo "管理命令:"
    echo "启动服务: sudo systemctl start filebrowser"
    echo "停止服务: sudo systemctl stop filebrowser"
    echo "重启服务: sudo systemctl restart filebrowser"
    echo "查看状态: sudo systemctl status filebrowser"
    echo "============================================================"
    if [ "$auto_install" != "true" ]; then
        echo ""
        echo "按任意键返回主菜单..."
        read -n 1
        show_menu
    fi
}
install_filebrowser() {
    echo "开始安装FileBrowser..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        echo "检测到系统: $OS"
    else
        echo "无法检测系统类型，将尝试使用通用安装方法"
        OS="Unknown"
    fi
    if ! command -v curl &> /dev/null; then
        echo "安装curl..."
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            sudo apt-get update
            sudo apt-get install -y curl
        elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
            sudo yum install -y curl
        else
            echo "请手动安装curl后再运行此脚本"
            exit 1
        fi
    fi
    echo "下载并安装FileBrowser..."
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
    echo "创建配置目录..."
    mkdir -p ~/.config/filebrowser
    echo "请输入文件存储路径 (默认: /home/files):"
    read -r file_path
    file_path=${file_path:-/home/files}
    mkdir -p "$file_path"
    echo "请输入端口 (默认: 8080):"
    read -r port
    port=${port:-8080}
    echo "请输入并发连接数 (默认: 10):"
    read -r concurrent
    concurrent=${concurrent:-10}
    DB_PATH="$HOME/.config/filebrowser/filebrowser.db"
    echo "初始化FileBrowser配置..."
    filebrowser config init --address 0.0.0.0 --port "$port" --root "$file_path" --database "$DB_PATH"
    filebrowser config set --enableThumbnails --enableExec --database "$DB_PATH"
    echo "请设置管理员用户名 (默认: admin):"
    read -r admin_user
    admin_user=${admin_user:-admin}
    echo "请设置管理员密码 (默认: admin):"
    read -r admin_password
    admin_password=${admin_password:-admin}
    echo "创建管理员用户..."
    filebrowser users add "$admin_user" "$admin_password" --perm.admin --database "$DB_PATH"
    if [ $? -ne 0 ]; then
        echo "创建用户失败，尝试删除已存在的用户后重新创建..."
        filebrowser users rm "$admin_user" --database "$DB_PATH"
        filebrowser users add "$admin_user" "$admin_password" --perm.admin --database "$DB_PATH"
    fi
    mkdir -p /tmp/filebrowser_cache
    chmod 777 /tmp/filebrowser_cache
    echo "创建systemd服务..."
    cat > filebrowser.service << EOL
[Unit]
Description=FileBrowser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser --address 0.0.0.0 --port $port --root "$file_path" --database "$DB_PATH" --concurrent $concurrent --socket-perm 0666 --enable-thumbnail-gzip --enable-exec --cache-dir /tmp/filebrowser_cache
Restart=on-failure
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOL
    echo "安装systemd服务..."
    sudo mv filebrowser.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable filebrowser
    sudo systemctl start filebrowser
    sleep 2
    if systemctl is-active --quiet filebrowser; then
        echo "FileBrowser服务启动成功！"
    else
        echo "警告: FileBrowser服务可能未成功启动，请检查状态: sudo systemctl status filebrowser"
    fi
    SERVER_IP=$(curl -s ifconfig.me || wget -qO- ifconfig.co || hostname -I | awk '{print $1}')
    echo "FileBrowser安装完成！"
    echo "管理员用户名: $admin_user"
    echo "管理员密码: $admin_password"
    echo "请访问 http://$SERVER_IP:$port 来使用FileBrowser"
    echo "请务必登录后立即修改默认密码！"
    echo ""
    echo "文件存储位置: $file_path"
    echo "数据库位置: $DB_PATH"
    echo "并发连接数: $concurrent"
    echo ""
    echo "管理命令:"
    echo "启动服务: sudo systemctl start filebrowser"
    echo "停止服务: sudo systemctl stop filebrowser"
    echo "重启服务: sudo systemctl restart filebrowser"
    echo "查看状态: sudo systemctl status filebrowser"
    echo ""
    echo "按任意键返回主菜单..."
    read -n 1
    show_menu
}
reset_admin_password() {
    echo "重置FileBrowser管理员密码..."
    DB_PATH=$(get_db_path)
    if [ ! -f "$DB_PATH" ]; then
        echo "错误: 未找到FileBrowser数据库文件，请先安装FileBrowser"
        echo "数据库路径: $DB_PATH"
        echo ""
        echo "按任意键返回主菜单..."
        read -n 1
        show_menu
        return
    fi
    echo "当前数据库路径: $DB_PATH"
    echo "当前用户列表:"
    filebrowser users ls --database "$DB_PATH"
    echo "请输入要重置的用户名 (默认: admin):"
    read -r reset_user
    reset_user=${reset_user:-admin}
    echo "请输入新密码 (默认: admin):"
    read -r new_password
    new_password=${new_password:-admin}
    echo "重置用户 $reset_user 的密码..."
    filebrowser users update "$reset_user" --password "$new_password" --database "$DB_PATH"
    if [ $? -eq 0 ]; then
        echo "密码重置成功！"
        echo "用户名: $reset_user"
        echo "新密码: $new_password"
        echo "重启FileBrowser服务..."
        sudo systemctl restart filebrowser
    else
        echo "密码重置失败，可能是用户不存在"
        echo "尝试创建新的管理员用户..."
        filebrowser users add "$reset_user" "$new_password" --perm.admin --database "$DB_PATH"
        if [ $? -eq 0 ]; then
            echo "已创建新的管理员用户"
            echo "重启FileBrowser服务..."
            sudo systemctl restart filebrowser
        else
            echo "用户创建也失败，请检查FileBrowser安装状态"
        fi
    fi
    echo ""
    echo "按任意键返回主菜单..."
    read -n 1
    show_menu
}
uninstall_filebrowser() {
    echo "开始卸载FileBrowser..."
    echo "停止FileBrowser服务..."
    sudo systemctl stop filebrowser
    sudo systemctl disable filebrowser
    echo "删除服务文件..."
    sudo rm -f /etc/systemd/system/filebrowser.service
    sudo systemctl daemon-reload
    echo "删除FileBrowser程序..."
    sudo rm -f /usr/local/bin/filebrowser
    echo "删除配置文件..."
    read -p "是否删除配置文件和数据库? (y/n): " confirm
    if [[ "$confirm" == [yY] ]]; then
        rm -rf ~/.config/filebrowser
        echo "配置文件和数据库已删除"
    else
        echo "保留配置文件和数据库"
    fi
    echo "FileBrowser卸载完成！"
    echo ""
    echo "按任意键返回主菜单..."
    read -n 1
    show_menu
}
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "FileBrowser一键安装脚本"
    echo "用法:"
    echo "  $0                     交互式安装(显示菜单)"
    echo "  $0 --auto [选项]       自动安装(无交互)"
    echo ""
    echo "自动安装选项:"
    echo "  --path=PATH      指定文件存储路径 (默认: /home/files)"
    echo "  --port=PORT      指定端口 (默认: 8080)"
    echo "  --user=USER      指定管理员用户名 (默认: admin)"
    echo "  --password=PASS  指定管理员密码 (默认: admin)"
    echo "  --concurrent=NUM 并发连接数 (默认: 10)"
    echo "  --help, -h       显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --auto --path=/data/files --port=8888 --user=admin --password=secure123 --concurrent=20"
    exit 0
fi
if [ "$auto_install" != "true" ]; then
    show_menu
fi