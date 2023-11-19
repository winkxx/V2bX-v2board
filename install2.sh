#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_V2bX() {
    if [[ -e /usr/local/V2bX/ ]]; then
        rm -rf /usr/local/V2bX/
    fi

    mkdir /usr/local/V2bX/ -p
    cd /usr/local/V2bX/

    if  [ $# == 0 ] ;then
        last_version=v2.0.4
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}指定Tag名字错误${plain}"
            exit 1
        fi
        echo -e "检测到 V2bX 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/V2bX/V2bX-linux.zip https://github.com/Yuzuki616/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 V2bX 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Yuzuki616/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"
        echo -e "开始安装 V2bX v$1"
        wget -q -N --no-check-certificate -O /usr/local/V2bX/V2bX-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 V2bX v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip V2bX-linux.zip
    rm V2bX-linux.zip -f
    chmod +x V2bX
    mkdir /etc/V2bX/ -p
    rm /etc/systemd/system/V2bX.service -f
    file="https://raw.githubusercontent.com/winkxx/V2bX-v2board/master/V2bX.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/V2bX.service ${file}
    #cp -f V2bX.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop V2bX
    systemctl enable V2bX
    echo -e "${green}V2bX ${last_version}${plain} 安装完成，已设置开机自启"
    cp geoip.dat /etc/V2bX/
    cp geosite.dat /etc/V2bX/

    if [[ ! -f /etc/V2bX/config.yml ]]; then
        cp config.yml /etc/V2bX/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/Yuzuki616/V2bX，配置必要的内容"
    else
        systemctl start V2bX
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}V2bX 重启成功${plain}"
        else
            echo -e "${red}V2bX 可能启动失败，请稍后使用 V2bX log 查看日志信息，若无法启动，则可能更改了配置格式，请前往 wiki 查看：https://github.com/V2bX-project/V2bX/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/V2bX/dns.json ]]; then
        cp dns.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/route.json ]]; then
        cp route.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/rulelist ]]; then
        cp rulelist /etc/V2bX/
    fi
    curl -o /usr/bin/V2bX -Ls https://raw.githubusercontent.com/winkxx/V2bX-v2board/master/V2bX.sh
    chmod +x /usr/bin/V2bX
    mkdir /usr/bin/v2bx -p
    chmod +x /usr/bin/v2bx
    ln -s /usr/bin/V2bX /usr/bin/v2bx # 小写兼容
    cd $cur_dir
    rm -f install.sh 



         # 设置节点序号
    echo "设定节点序号"
    echo ""
    read -p "请输入V2Board中的节点序号:" node_id
    [ -z "${node_id}" ]
    echo "---------------------------"
    echo "您设定的节点序号为 ${node_id}"
    echo "---------------------------"
    echo ""

    # 选择协议
    echo "选择节点类型(默认V2ray)"
    echo ""
    read -p "请输入你使用的协议(V2ray, Shadowsocks, Trojan):" node_type
    [ -z "${node_type}" ]
    
    # 如果不输入默认为V2ray
    if [ ! $node_type ]; then 
    node_type="V2ray"
    fi

    echo "---------------------------"
    echo "您选择的协议为 ${node_type}"
    echo "---------------------------"
    echo ""

    # 输入域名（TLS）
    echo "输入你的域名"
    echo ""
    read -p "请输入你的域名(node.v2board.com)如没开启TLS请直接回车:" node_domain
    [ -z "${node_domain}" ]

    # 如果不输入默认为node1.v2board.com
    if [ ! $node_domain ]; then 
    node_domain="node.v2board.com"
    fi


    # 写入配置文件
    echo "正在尝试写入配置文件..."
    wget https://cdn.jsdelivr.net/gh/winkxx/alo-bot-all/config.yml -O /etc/V2bX/config.yml
    sed -i "s/NodeID:.*/NodeID: ${node_id}/g" /etc/V2bX/config.yml
    sed -i "s/NodeType:.*/NodeType: ${node_type}/g" /etc/V2bX/config.yml
    sed -i "s/CertDomain:.*/CertDomain: \"${node_domain}\"/g" /etc/V2bX/config.yml
    systemctl stop V2bX
    systemctl start V2bX
    echo ""
    echo "写入完成，正在尝试重启V2bX服务..."
    echo

    echo -e ""
    echo "V2bX 管理脚本使用方法(兼容使用V2X执行): "
    echo "------------------------------------------"
    echo "V2bX              - 显示管理菜单 (功能更多)"
    echo "V2bX start        - 启动 V2bX"
    echo "V2bX stop         - 停止 V2bX"
    echo "V2bX restart      - 重启 V2bX"
    echo "V2bX status       - 查看 V2bX 状态"
    echo "V2bX enable       - 设置 V2bX 开机自启"
    echo "V2bX disable      - 取消 V2bX 开机自启"
    echo "V2bX log          - 查看 V2bX 日志"
    echo "V2bX generate     - 生成 V2bX 配置文件"
    echo "V2bX update       - 更新 V2bX"
    echo "V2bX update x.x.x - 更新 V2bX 指定版本"
    echo "V2bX install      - 安装 V2bX"
    echo "V2bX uninstall    - 卸载 V2bX"
    echo "V2bX version      - 查看 V2bX 版本"
    echo "------------------------------------------"
}
    echo -e "${green}开始安装${plain}"
    install_base
    install_V2bX $1
