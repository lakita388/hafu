#!/bin/bash
# 获取本机公网 IP 地址
IP=$(curl -s "https://ipinfo.io/ip" | tr -d '\n')
echo "当前 IP 是：$IP"
# 检查当前 IP 是否正确
read -p "请确认 IP 是否正确(y/n)：" confirm

while [[ ! "$confirm" =~ ^(y|Y|n|N)$ ]]; do
    read -p "请确认 IP 是否正确(y/n)：" confirm
done

if [[ "$confirm" =~ ^(y|Y|)$ ]]; then
    echo "IP 验证成功，继续下一步。"
else
    # 手动输入 IP
    read -p "请输入正确的 IP 地址：" IP

    while [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do
        echo "请输入正确的 IP 地址！"
        read -p "请输入正确的 IP 地址：" IP
    done

    echo "IP 验证成功，继续下一步。"
fi

# 默认的工程文件下载地址
abf_url="https://gitee.com/cg_5_0/aaaa/raw/master/gongcheng.apk"
hy_url=""

echo "###############################################################################"

echo "1、搭建安波福工程模式"
echo "2、搭建华阳工程模式"
echo "3、自定义软件"
read -p "请输入您的选择：" confirm

# 如果选择自定义下载地址
case $confirm in
	1) 
		echo "您选择的是安波福工程模式"
		apk_url=$abf_url
		type_name="安波福工程模式"
		;;
	2)
		echo "您选择的是华阳工程模式"
		apk_url=$hy_url
		type_name="华阳工程模式"
		;;
	3)
		read -p "请输入自定义的下载地址：" apk_url
		;;
	*)
		echo "输入无效，别瞎选，你要上天啊"
		exit 1 
		;;
esac

# 判断系统发行版本
if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d" ]; then
	PM="yum"
elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
	PM="apt-get"
fi

# 安装 dnsmasq
systemctl stop systemd-resolved > /dev/null 2>&1
echo "开始安装dnsmasq"

netstat -tuln | grep ":53 " > /dev/null
if [ $? -eq 0 ]; then
    echo "端口 53 已被占用，dnsmasq安装或启动可能失败6"
fi

if [[ $(systemctl is-active dnsmasq) != "active" ]]; then
    echo "正在安装 dnsmasq ..."
    $PM -y install dnsmasq > /dev/null 2>&1
    systemctl start dnsmasq

    if [[ $(systemctl is-active dnsmasq) != "active" ]]; then
        echo "安装 dnsmasq 失败，请检查网络和配置。"
        exit 1
    fi

    systemctl enable dnsmasq > /dev/null 2>&1
    echo "dnsmasq 安装成功。"
else
    echo "dnsmasq 已经安装，跳过安装步骤。"
fi

# 安装 nginx
if [[ $(systemctl is-active nginx) != "active" ]]; then
    echo "正在安装 nginx ..."
	$PM -y install epel-release > /dev/null 2>&1
    $PM -y install nginx > /dev/null 2>&1
    mkdir /etc/nginx/cert

    systemctl start nginx

    if [[ $(systemctl is-active nginx) != "active" ]]; then
        echo "安装 nginx 失败，请检查网络和配置。"
        exit 1
    fi

    systemctl enable nginx > /dev/null 2>&1
    echo "nginx 已经安装并启动成功。"
else
    echo "nginx 已经安装，跳过安装步骤。"
fi


# 生成 SSL 证书
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=MyOrg/OU=MyUnit/CN=$IP" \
  -keyout /etc/nginx/cert/server.key -out /etc/nginx/cert/server.crt > /dev/null 2>&1

# 配置 hosts
# echo "解析地址hosts"
cat << EOF > /etc/hosts
$IP dzsms.gwm.com.cn
EOF
addr=$(ip route | awk '/default/ {print $5}')

# echo "解析地址"
cat << EOF > /etc/dnsmasq.conf
address=/qq.com/$IP
address=/gwm.com.cn/$IP
listen-address=$IP
# resolv-file=/etc/dnsmasq.resolv.conf
# addn-hosts=/etc/dnsmasq.hosts
interface=$addr
log-queries
EOF

# if [ $? -eq 0 ]; then
# 	echo "host写入成功"
# else
# 	echo "host写入失败，请手动写入"
# fi
systemctl restart dnsmasq

# 配置 nginx
cat << EOF > /etc/nginx/nginx.conf
worker_processes 1;
events {
  worker_connections 1024;
}
http {
	include mime.types;
	default_type application/octet-stream;
	sendfile on;
	keepalive_timeout 65;
	server {
		listen 443 ssl;
		listen 80;
		server_name $IP;  # 替换为你的域名(或 IP 地址)
		ssl_certificate /etc/nginx/cert/server.crt;
		ssl_certificate_key /etc/nginx/cert/server.key;
		ssl_session_timeout 5m;
		ssl_ciphers HIGH:!aNULL:!MD5;
		ssl_prefer_server_ciphers on;
	 
		location / {
			root /usr/share/nginx/html/;
			index index.html index.htm;
		}

		location /apiv2/car_apk_update {
			default_type application/json;
			return 200 '{
				"code": 200,
				"message": "\u67e5\u8be2\u6210\u529f",
				"data": {
					"apk_version": "99999",
					"apk_url": "https://$IP/gongcheng.apk",
					"apk_msg": "恭喜成功，如果点击升级进度条不动那么说明apk链接有问题",
					"isUpdate": "Yes",
					"apk_forceUpdate": "Yes",
					"notice": {
						"vin_notice": [
							"VIN\u7801\u53ef\u4ee5\u5728\u4eea\u8868\u677f\u5de6\u4e0a\u65b9\uff08\u524d\u98ce\u6321\u73bb\u7483\u540e\u9762\uff09\u548c\u8f66\u8f86\u94ed\u724c\u4e0a\u83b7\u5f97\u3002",
                    "\u672c\u5e94\u7528\u9002\u7528\u4e8e2019\u5e74\u53ca\u4e4b\u540e\u751f\u4ea7\u7684\u8f66\u578b\u3002",
												],
						"add_notice": [
							"\u5236\u9020\u5e74\u6708\u53ef\u901a\u8fc7\u8f66\u8f86\u94ed\u724c\u83b7\u5f97\u3002",
                    "\u672c\u5e94\u7528\u9002\u7528\u4e8e2019\u5e74\u53ca\u4e4b\u540e\u751f\u4ea7\u7684\u8f66\u578b\u3002",

						]
					},
					"notice_en": {
						"vin_notice": [

						],
						"add_notice": [
							"The date can be obtained from the certification label."
						]
					}
				}
			}';
		}

	}
}
EOF

if [ $? -eq 0 ]; then
	echo "nginx配置写入成功"
else
	echo "nginx配置写入失败，请手动写入"
fi

systemctl restart nginx

if [ $? -eq 0 ]; then
	echo ""
	echo "nginx启动成功，DNS搭建成功，你的DNS是$IP,你搭建的是$type_name"
	echo -e "\e[31m防火墙中放行 53、80、443 端口\e[0m"
else
	echo -e "\e[31mnginx启动失败，请检查配置文件\e[0m"
fi