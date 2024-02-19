#!/usr/bin/env bash

description="Install FOG Project"
# version: 12.1
# author: Choops <choopsbd@gmail.com>

#set -ex    # debug

DEF="\e[0m"
RED="\e[31m"
GRN="\e[32m"
YLO="\e[33m"
CYN="\e[36m"

ERR="${RED}ERR${DEF}:"
OK="${GRN}OK${DEF}:"
WRN="${YLO}WRN${DEF}:"
NFO="${CYN}NFO${DEF}:"

SCRIPT_PATH="$(dirname "$(realpath "$0")")"


usage(){
    errcode="$1"

    [[ ${errcode} == 0 ]] && echo -e "${CYN}${description}${DEF}"

    echo -e "${CYN}Usage${DEF}:"
    echo -e "  ./$(basename "$0") [OPTION]"
    echo -e "  ${WRN} Must be run as 'root' or using 'sudo'"
    echo -e "${CYN}Options${DEF}:"
    echo -e "  -h,--help: Print this help"
    echo

    exit "${errcode}"
}

install_fogproject() {
    # prerequisites
    src_dir="/usr/local/share/src"

    mkdir -p "${src_dir}"

    (dpkg -l | grep "^ii  git ") || apt install -y git

    # make sources available and updated
    fog_dir="${src_dir}/fogproject"

    if [[ -d "${fog_dir}/.git" ]]; then
        pushd "${fog_dir}" >/dev/null
        git pull
        popd >/dev/null
    else
        git clone https://github.com/FOGProject/fogproject.git "${fog_dir}"
    fi

    # install FOG
    pushd "${fog_dir}/bin" >/dev/null
    ./installfog.sh
    popd >/dev/null
}

# check arguments
[[ $2 ]] && echo -e "${ERR} Too many arguments\n" && usage 1
if [[ $1 =~ ^-(h|-help)$ ]]; then
    usage 0
elif [[ $1 ]]; then
    echo -e "${ERR} Bad argument\n" && usage 1
fi

# check Permissions
[[ $(whoami) != root ]] && echo -e "${ERR} Need higher privileges\n" && exit 1

install_fogproject
