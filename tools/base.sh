#!/usr/bin/env bash
#
# Bootstrap script to install kubernetes env.
#
# This script is intended to be used for install kubernetes env.

# author: shujiangle

# 本机ip
LOCALIP="${LOCALIP:-localhost}"

# 镜像版本
IMAGETAG="1.23.17"

# 拉取的用户名和密码
USER="ptx9sk7vk7ow:003a1d6132741b195f332b815e8f98c39ecbcc1a"

# 拉取的URL
URL="https://pixiupkg-generic.pkg.coding.net"

# 拉取CostumURL
CostumURL="http://10.50.2.250:18080"

# 当前路径, $pwd 可以更改路径
PKGPWD=$(cd `dirname $0`; pwd)

# 判断LOCALIP是否修改
printChangeIp() {
	if [ "$LOCALIP" = "localhost" ]; then
		echo "你的ip未修改,请修改成你部署机ip"
		exit 1
	fi
}

printHelp() {
	printf "[WARN] 请输入你要选择的操作.\n\n"
	echo "Available Commands:"
	printf "  %-25s\t %s\t \n" "download" "下载离线包"
	printf "  %-25s\t %s\t \n" "install" "安装前置服务"
	printf "  %-25s\t %s\t \n" "push" "推送k8s镜像和rpm包"
	printf "  %-25s\t %s\t \n" "kubezansible" "安装kubez-ansible"
}

printDownloadHelp() {
	printf "[WARN] 请输入你要下载的离线包.\n\n"
	echo "Available Commands:"
	printf "  %-25s\t %s\t \n" "all" "下载所有离线包"
	printf "  %-25s\t %s\t \n" "nexus" "下载nexus"
	printf "  %-25s\t %s\t \n" "rpm" "下载rpm离线包"
	printf "  %-25s\t %s\t \n" "image" "下载镜像包"
	printf "  %-25s\t %s\t \n" "kubez" "下载kubez-ansible 离线包"
}

Download() {
	case $1 in
	"all")
		downloadNexus
		downloadRpm
		downloadImage
		downloadKubez
		;;
	"nexus")
		downloadNexus
		;;
	"rpm")
		downloadRpm
		;;
	"image")
		downloadImage
		;;
	"kubez")
		downloadKubez
		;;
	*)
		printDownloadHelp
		;;
	esac
}

downloadNexus() {
	# 准备 nexus 离线包
	if [ ! -f "nexus.tar.gz" ]; then
		echo "正在下载nexus"
		curl -fL $CostumURL/kubez-ansible/nexus.tar.gz -o nexus.tar.gz
	fi
}

downloadRpm() {
	# 准备 rpm 离线包
	if [ ! -f "k8s-v${IMAGETAG}-rpm.tar.gz" ]; then
		echo "正在下载k8s-v${IMAGETAG}-rpm.tar.gz"
		curl -fL $CostumURL/kubez-ansible/k8s-v$IMAGETAG-rpm.tar.gz -o k8s-v${IMAGETAG}-rpm.tar.gz
	fi
}

downloadImage() {
	# 准备镜像离线包
	if [ ! -f "k8s-centos7-v${IMAGETAG}_images.tar.gz" ]; then
		echo "正在下载k8s-centos7-v${IMAGETAG}_images.tar.gz"
		curl -fL $CostumURL/kubez-ansible/k8s-centos7-v${IMAGETAG}_images.tar.gz -o k8s-centos7-v${IMAGETAG}_images.tar.gz
	fi

}

downloadKubez() {
	# 准备镜像离线包
	if [ ! -f "kubez-ansible-offline-master.zip" ]; then
		echo "正在下载kubez-ansible-offline-master.zip"
		curl -fL $CostumURL/kubez-ansible/kubez-ansible-offline-master.zip -o kubez-ansible-offline-master.zip
	fi
}

check_nexus_status() {
	curl $LOCALIP:58000 >/dev/null 2>&1
	if [ $? == 0 ]; then
		echo -e "服务已经启动成功"
		sleep 1
		exit 0
	fi
}
# 安装nexus
installNexus() {
	## Open nexus防火墙
	[ "`systemctl is-active firewalld`" == "active" ] && firewall-cmd --add-port=58000-58001/tcp --permanent && firewall-cmd --reload

	##Custom Nexus Server Check
	curl $LOCALIP:58000 >/dev/null 2>&1
	[ $? == 0 ] && return 0
	##
	#check_nexus_status
	cd $PKGPWD
	if [ ! -f "nexus.tar.gz" ]; then
		echo "nexus安装包不存在，请下载"
		exit 1
	fi
	tar zxvf nexus.tar.gz
	cd nexus_local/

	# 启动服务
	sh nexus.sh start
	
}

printPushHelp() {
	printf "[WARN] 请输入你要上传的物料.\n\n"
	echo "Available Commands:"
	printf "  %-25s\t %s\t \n" "all" "上传所有k8s镜像和所有rpm包"
	printf "  %-25s\t %s\t \n" "image" "上传所有k8s镜像"
	printf "  %-25s\t %s\t \n" "rpm" "上传所有rpm包"
}

pushImage() {
	printChangeIp
	cd $PKGPWD
	[ ! -d allimagedownload ] && tar zxvf k8s-centos7-v${IMAGETAG}_images.tar.gz
	cd allimagedownload
	sh load_image.sh $LOCALIP
}

pushRpm() {
	printChangeIp
	cd $PKGPWD
	[ ! -d localrepo ] && tar zxvf k8s-v${IMAGETAG}-rpm.tar.gz
	cd localrepo
	sh push_rpm.sh $LOCALIP
}

Push() {
	case $1 in
	"all")
		pushRpm
		sleep 10
		pushImage
		;;
	"image")
		pushImage
		;;
	"rpm")
		pushRpm
		;;
	*)
		printPushHelp
		;;
	esac
}

printKubezHelp() {
	printf "[WARN] 设置nexus repo和安装kubez-ansible.\n\n"
	echo "Available Commands:"
	printf "  %-25s\t %s\t \n" "all" "设置nexus repo和安装kubez-ansible"
	printf "  %-25s\t %s\t \n" "repo" "设置nexus repo"
	printf "  %-25s\t %s\t \n" "install" "安装kubez-ansible"
}

kubezansible() {
	case $1 in
	"all")
		kubezansibleRepo
		kubezansibleInstall
		;;
	"repo")
		kubezansibleRepo
		;;
	"install")
		kubezansibleInstall
		;;
	*)
		printKubezHelp
		;;
	esac
}

kubezansibleRepo() {
	printChangeIp

	[ -d "/etc/yum.repos.d.bak" ] && echo "/etc/yum.repos.d.bak  备份目录存在，无需备份" || cp -a /etc/yum.repos.d /etc/yum.repos.d.bak
	rm -rf /etc/yum.repos.d/*
	if [ ! -f "/etc/yum.repos.d/offline.repo" ];then
		cat >/etc/yum.repos.d/offline.repo <<EOF
[basenexus]
name=Pixiuio Repository
baseurl=http://${LOCALIP}:58000/repository/pixiuio-centos/
enabled=1
gpgcheck=0
EOF
	fi
	yum clean all && yum makecache
	sleep 3
}

kubezansibleInstall() {
	# 判断ip是否修改
	printChangeIp

	if command -v "kubez-ansible" >/dev/null; then
		echo "kubez-ansible 命令已经安装"
		return 0
	else
		cd $PKGPWD

		# 安装依赖包
		yum makecache
		yum -y install audit policycoreutils bash-completion
		yum -y install ansible unzip python2-pip expect

		# 解压 kubez-ansible 包
		[ ! -d "kubez-ansible-offline-master" ] && unzip kubez-ansible-offline-master.zip
		cd kubez-ansible-offline-master

		# 修改配置文件
		updateConfig

		# 安装依赖
		pip install pip/pbr-5.11.1-py2.py3-none-any.whl

		cp tools/git /usr/local/bin && git init

		# 执行安装
		python setup.py install

		cp -r etc/kubez/ /etc/
		cp ansible/inventory/multinode ~
		cd ~
	fi
}

sshPubkeyCreate(){
	/usr/bin/expect <<EOF
set timeout 30
spawn ssh-keygen
expect "Enter file in which to save the key (/root/.ssh/id_rsa):"
send "\n"
expect {
    "Overwrite " { send "n\n" }
    "Enter passphrase (empty for no passphrase):" {
        send "\n"
        expect "Enter same passphrase again:"
        send "\n" }
}
expect eof
EOF
}

updateConfig() {
	sed -ri 's#192.168.16.210#'${LOCALIP}'#g' etc/kubez/globals.yml
}

function main() {
	Download all
	installNexus
	Push all
	kubezansible all
	sshPubkeyCreate
}

main

# case $1 in
# "download")
# 	Download $2
# 	;;
# "install")
# 	installNexus
# 	;;
# "push")
# 	Push $2
# 	;;
# "kubezansible")
# 	kubezansible $2
# 	;;
# *)
# 	printHelp
# 	;;
# esac


