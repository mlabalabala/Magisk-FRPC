SKIPUNZIP=1

DATADIR="/sdcard/Android"

unzip -o "${ZIPFILE}" 'module.prop' -d "${TMPDIR}" >&2
[[ ! -f "${TMPDIR}/module.prop" ]] && abort "! 未找到module.prop文件，安装结束！"

MyPrint() 
{
	ui_print "$@"
	sleep 0.03
}

file="META-INF/com/google/android/update-binary"
file_path="${TMPDIR}/$file"
hash_path="$file_path.sha256sum"
unzip -o "$ZIPFILE" "META-INF/com/google/android/*" -d "${TMPDIR}" >&2
[ -f "$file_path" ] || abort "! $file 不存在！"
if [ -f "$hash_path" ]; then
  (echo "$(cat "$hash_path")  $file_path" | sha256sum -c -s -) || abort "！$file 校验失败！"
  MyPrint "- 校验：$file" >&1
else
  abort "！缺少校验文件！"
fi

# extract <zip> <file> <target dir> <junk paths>
extract() {
  zip=$1
  file=$2
  dir=$3
  junk_paths=$4
  [ -z "$junk_paths" ] && junk_paths=false
  opts="-o"
  [ $junk_paths = true ] && opts="-oj"

  file_path=""
  hash_path=""
  if [ $junk_paths = true ]; then
    file_path="$dir/$(basename "$file")"
    hash_path="${TMPDIR}/$(basename "$file").sha256sum"
  else
    file_path="$dir/$file"
    hash_path="${TMPDIR}/$file.sha256sum"
  fi

  unzip $opts "$zip" "$file" -d "$dir" >&2
  [ -f "$file_path" ] || abort "! $file 不存在！"

  unzip $opts "$zip" "$file.sha256sum" -d "${TMPDIR}" >&2
  [ -f "$hash_path" ] || abort "! $file.sha256sum 不存在！"

  (echo "$(cat "$hash_path")  $file_path" | sha256sum -c -s -) || abort "! $file 校验错误！"
  MyPrint "- 校验：$file" >&1
}

author="`grep_prop author $TMPDIR/module.prop`"
name="`grep_prop name $TMPDIR/module.prop`"

mkdir -p "${MODPATH}/files/bin"

get_choose()
{
	local choose
	local branch
	while :; do
		choose="$(getevent -qlc 1 | awk '{ print $3 }')"
		case "$choose" in
			KEY_VOLUMEUP)
				branch="0"
			;;
			KEY_VOLUMEDOWN)
				branch="1"
			;;
			*)
				continue
			;;
		esac
		echo "$branch"
		break
	done
}

#Check whether the directory is readable and writable
Sdcard_RW()
{
	local test_file="${DATADIR}/.A_TEST_FILE"
	touch $test_file
	rm $test_file
}

#Check architecture
Check_ARCH(){
	case $ARCH in
	arm64)
		F_ARCH=$ARCH
	;;
	arm)
		F_ARCH=$ARCH
	;;
	x64)
		F_ARCH=x86_64
	;;
	x86)
		F_ARCH=$ARCH
	;;
	*)
		MyPrint "- 不支持的架构: $ARCH"
		MyPrint " "
		abort "! 安装结束！"
	;;
	esac
}

Check_Crond(){
	Busybox_file="${MODPATH}/files/bin/busybox_${F_ARCH}"
	if [[ -f "${Busybox_file}" ]] && [[ -x "${Busybox_file}" ]]; then
		MyPrint "- 已优先使用模块的定时任务方式检测运行状态！"
		sed -i "/^RUNNING_METHOD=/c RUNNING_METHOD=定时任务（模块提供）" "${MODPATH}/files/status.conf"
	elif [[ "$(which crond)" ]]; then
		MyPrint "- 设备重启后将以定时任务方式检测运行状态！"
		sed -i "/^RUNNING_METHOD=/c RUNNING_METHOD=定时任务" "${MODPATH}/files/status.conf"
	else
		MyPrint "- 设备重启后将以默认方式检测运行状态！"
		sed -i "/^RUNNING_METHOD=/c RUNNING_METHOD=默认" "${MODPATH}/files/status.conf"
	fi
}


MyPrint " "
MyPrint "(#) 设备信息： "
MyPrint "- 品牌: `getprop ro.product.brand`"
MyPrint "- 代号: `getprop ro.product.device`"
MyPrint "- 模型: `getprop ro.product.model`"
MyPrint "- 安卓版本: `getprop ro.build.version.release`"
[[ "`getprop ro.miui.ui.version.name`" != "" ]] && MyPrint "- MIUI版本: MIUI `getprop ro.miui.ui.version.name` - `getprop ro.build.version.incremental`"
MyPrint "- 内核版本: `uname -osr`"
MyPrint "- 运存大小: `free -m | grep -E "^Mem|^内存" | awk '{printf("总量：%s MB，已用：%s MB，剩余：%s MB，使用率：%.2f%%",$2,$3,($2-$3),($3/$2*100))}'`"
MyPrint "- Swap大小: `free -m | grep -E "^Swap|^交换" | awk '{printf("总量：%s MB，已用：%s MB，剩余：%s MB，使用率：%.2f%%",$2,$3,$4,($3/$2*100))}'`"
MyPrint " "
MyPrint "(@) 模块信息："
MyPrint "- 名称: $name"
MyPrint "- 作者：$author"
MyPrint " "
Sdcard_RW
[[ $? -ne 0 ]] && abort "! ${DATADIR} 目录读写测试失败，安装结束！"
Check_ARCH
MyPrint "- 设备架构：$ARCH"
MyPrint " "
MyPrint "(?) 确认安装吗？(请选择)"
MyPrint "- 按音量键＋: 安装 √"
MyPrint "- 按音量键－: 退出 ×"
if [[ $(get_choose) -eq 0 ]]; then
	MyPrint "- 已选择安装"
	MyPrint " "
	MyPrint "- 正在释放文件并校验文件"
	extract "${ZIPFILE}" "files/bin/frpc-${F_ARCH}" "${MODPATH}/files/bin" true
	extract "${ZIPFILE}" "files/bin/busybox_${F_ARCH}" "${MODPATH}/files/bin" true
	extract "${ZIPFILE}" "service.sh" "${MODPATH}"
	extract "${ZIPFILE}" "module.prop" "${MODPATH}"
	extract "${ZIPFILE}" "uninstall.sh" "${MODPATH}"
	extract "${ZIPFILE}" "Run_FRPC.sh" "${MODPATH}"
	extract "${ZIPFILE}" "Check_FRPC.sh" "${MODPATH}"
	extract "${ZIPFILE}" "update_log.md" "${MODPATH}"
	extract "${ZIPFILE}" "files/status.conf" "${MODPATH}/files" true
	extract "${ZIPFILE}" "files/frpc.ini" "${MODPATH}/files" true
	extract "${ZIPFILE}" "files/frpc_full.ini" "${MODPATH}/files" true
	MyPrint "- 文件释放完成！正在设置权限"
	set_perm_recursive $MODPATH 0 0 0755 0644
	set_perm_recursive  $MODPATH/files/bin 0 0 0755 0700
	MyPrint "- 权限设置完成！"
	MyPrint " "
	Check_Crond
	sed -i "/^F_ARCH=/c F_ARCH=${F_ARCH}" "${MODPATH}/files/status.conf"
	MyPrint " "
	if [[ -f $DATADIR/frpc/frpc.ini ]]; then
		cp -af $MODPATH/update_log.md $DATADIR/frpc/
		MyPrint "- 存在旧配置文件 是否保留原配置文件？(请选择)"
		MyPrint "- 按音量键＋: 保留"
		MyPrint "- 按音量键－: 替换"
		if [[ $(get_choose) -eq 1 ]]; then
			MyPrint "- 已选择替换备份原配置文件"
			now_date=$(date "+%Y%m%d%H%M%S")
			mv $DATADIR/frpc/frpc.ini $DATADIR/frpc/backup_${now_date}-frpc.ini
			MyPrint "- 已备份保存为 Android/frpc/backup_${now_date}-frpc.ini"
			cp -af $MODPATH/files/frpc.ini $DATADIR/frpc/
			MyPrint "- 创建新文件"
			MyPrint " "
		else
			MyPrint "- 已选择保留原配置文件"
			MyPrint " "
		fi
	else
		if [[ ! -d $DATADIR/frpc ]]; then
			mkdir -p $DATADIR/frpc
			MyPrint "- 创建配置文件目录 Android/frpc 完成"
			MyPrint " "
		elif [[ ! -d $DATADIR/frpc/logs ]]; then
			mkdir $DATADIR/frpc/logs
			MyPrint "- 创建日志目录 Android/frpc/logs 完成"
			MyPrint " "
		fi
		cp -af $MODPATH/files/frpc*.ini $MODPATH/update_log.md $DATADIR/frpc/
		MyPrint "- 已创建配置文件！"
		MyPrint "- 请前往 Android/frpc目录查看frpc.ini文件内使用说明并配置文件！"
		MyPrint "- 然后进行设备重启即可！"
	fi
else
	abort "! 已选择退出"
fi