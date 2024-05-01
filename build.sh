#!/bin/bash
######################## Script Info #########################
# 
# author：Yang2635
# blog：https://www.isisy.com
# github: https://github.com/Yang2635
# module name: Magisk-FRPC
#
############## 脚本限 Magisk-FRPC 模块测试使用！###############
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" &&  Font_color_suffix="\033[0m"
SHELL_DIR=$(dirname $(readlink -f "$0"))

# Check sha256sum\zip\unzip binary
# Use the user's default PATH environment
sha256sum_bin=$(which sha256sum 2>/dev/null)
zip_bin=$(which zip 2>/dev/null)
unzip_bin=$(which unzip 2>/dev/null)
[[ -z "$sha256sum_bin" ]] && echo -e "${Red_font_prefix}The sha256sum binary file was not found !${Font_color_suffix}\n" >&2 && exit 1
[[ -z "$zip_bin" ]] && echo -e "${Red_font_prefix}The zip binary file was not found !${Font_color_suffix}\n" >&2 && exit 1
[[ -z "$unzip_bin" ]] && echo -e "${Red_font_prefix}The unzip binary file was not found !${Font_color_suffix}\n" >&2

# Check file sha256sum
Check_File_sha256(){
    dir_path=$(realpath $1)
    echo -e "\nThe file sha256 information is as follows:\n"
    [[ ! $(ls -A $dir_path 2>/dev/null) ]] && echo -e "${Red_font_prefix}Folder ${dir_path} is empty !${Font_color_suffix}\n" >&2 && exit 1
    find $(realpath $dir_path) -type f -exec $sha256sum_bin {} \;
}

# Clear sha256sum file
Clear_sha256sum_file(){
    echo -e "\nStart clearing sha256sum files:"
    find $1 -type f -name "*.sha256sum" -exec rm {} \;
    if [[ $? -eq 0 ]]; then
        echo -e "${Green_font_prefix}The sha256sum file was cleaned successfully ! ${Font_color_suffix}\n"
    else
        echo -e "${Red_font_prefix}Failed to clean sha256sum file ! ${Font_color_suffix}\n" >&2
        exit 1
    fi
}

# Calculate sha256sum
Calc_file_sha256sum(){
    echo -e "\nStart calculating sha256:"
    [[ ! -d $1 ]] && echo -e "${Red_font_prefix}The parameter specified is not a directory !${Font_color_suffix}\n" >&2 && exit 1
    [[ ! $(ls -A $1 2>/dev/null) ]] && echo -e "${Red_font_prefix}Folder $1 is empty !${Font_color_suffix}\n" >&2 && exit 1
    if [[ -f "${SHELL_DIR}/$(basename $1).zip" ]];then
        echo -e "${Red_font_prefix}There are old compressed files, please delete the files first ! \nFile Path: ${SHELL_DIR}/$(basename ${1}).zip ${Font_color_suffix}\n" >&2
        exit 1
    fi
    find $1 -path $1/.git -prune -o -type f -exec $sha256sum_bin {} \; | sort > ./sha256sum_result.lst
    if [[ $? -eq 0 ]]; then
        echo -e "${Green_font_prefix}sha256 calculation succeeded !${Font_color_suffix}\n"
    else
        echo -e "${Red_font_prefix}sha256 calculation failed !${Font_color_suffix}\n" >&2
        [[ -f ./sha256sum_result.lst ]] && rm -f ./sha256sum_result.lst
        exit 1
    fi
}

# Start compressed file
Start_Comp(){
    echo -e "\nStart compressing files:"
    if [[ ! -d $1 ]];then
        echo -e "${Red_font_prefix}The parameter specified is not a directory !${Font_color_suffix}\n" >&2
        Clear_sha256sum_file ${1%/*}
        exit 1
    fi
    cd $1
    # Hidden files or directories are not compressed. e.g. .git
    $zip_bin -rq $(basename $1).zip ./* 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${Green_font_prefix}The zip file is generated successfully ! ${Font_color_suffix}"
    else
        echo -e "${Red_font_prefix}The zip file is generated failed ! ${Font_color_suffix}" >&2
        [[ -f "$(basename $1).zip" ]] && rm -f "$(basename $1).zip"
        Clear_sha256sum_file $1
        exit 1
    fi
    mv -f $(basename $1).zip ${SHELL_DIR}
    if [[ $? -eq 0 ]];then
        echo -e "${Green_font_prefix}The compressed file path is ${SHELL_DIR}/$(basename ${1}).zip${Font_color_suffix}"
    fi
}

# Generate file
Generate_file(){
dir_path=$(realpath $1)
Calc_file_sha256sum $dir_path
echo -e "\nStart writing sha256sum file:"
while read line
do
    sha256_sum=$(echo "$line" | awk '{print $1}')
    file_name=$(echo "$line" | awk '{print $2}')
    echo "$sha256_sum" > ${file_name}.sha256sum
    if [[ $? -eq 0 ]]; then
        echo -e "${Green_font_prefix}sha256:$sha256_sum write file: ${file_name}.sha256sum success !${Font_color_suffix}"
    else
        echo -e "${Red_font_prefix}sha256:$sha256_sum write file: ${file_name}.sha256sum failed !${Font_color_suffix}" >&2
        Clear_sha256sum_file $dir_path
        exit 1
    fi
done < ./sha256sum_result.lst
rm -f ./sha256sum_result.lst

Start_Comp $dir_path
Clear_sha256sum_file $dir_path
}

Help_Info(){
        cat<<-EOF

Usage: $0  [-cCgGhH]  <file/dir>

      -[?|h|H]             Give this help list.
      
      -[c|C] <file/dir>    Calculate the sha256 value of the file and print it to the terminal.

      -[g|G] <dir>         Generate verification file and generate compressed file.

EOF
}

if [ ! "$1" ];then
    echo -e "\n${Red_font_prefix}The specified parameter is empty! Please see the help below !${Font_color_suffix}" >&2
    Help_Info
    exit 1
fi

while getopts ":c:C:g:G:hH" opt
do
    case $opt in
        c|C)
        Check_File_sha256 $OPTARG
        ;;
        g|G)
        Generate_file $OPTARG
        ;;
        h|H|?)
        Help_Info
        exit 1
        ;;
    esac
done

