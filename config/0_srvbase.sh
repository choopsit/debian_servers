#!/usr/bin/env bash

description="Deploy server base configuration"
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

STABLE=bookworm

# whiptail colors
export NEWT_COLORS="
root=,blue
window=,black
shadow=,blue
border=blue,black
title=white,black
textbox=white,black
radiolist=black,blue
label=black,blue
checkbox=black,white
compactbutton=black,lightgray
button=white,red"


usage() {
    local errcode="$1"

    [[ ${errcode} == 0 ]] && echo -e "${CYN}${description}${DEF}"

    echo -e "${CYN}Usage${DEF}:"
    echo -e "  ./$(basename "$0") [OPTION]"
    echo -e "  ${WRN} Must be run as 'root' or using 'sudo'"
    echo -e "${CYN}Options${DEF}:"
    echo -e "  -h,--help: Print this help"
    echo

    exit "${errcode}"
}

test_ip() {
    local ipchk=$1
    local IFS=.; local -a a=($ipchk)

    if ! [[ ${ipchk} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${ERR} Invalid ip/gateway address '${ipchk}'" && exit 1
    fi

    for quad in {0..3}; do
        if [[ "${a[$quad]}" -gt 255 ]]; then
            echo -e "${ERR} Invalid ip/gateway address '${ipchk}'" && exit 1
        fi
    done
}

fix_my_ip() {
    local my_ip
    local my_gw

    # TODO: whiptail TUI - text boxes
    read -p "ip address [default: ${ip}] ? " -r my_ip
    [[ ${my_ip} ]] && echo || my_ip="${ip}"
    test_ip "${my_ip}"

    read -p "gateway [default:${gw}] ? " -r my_gw
    [[ ${my_gw} ]] && echo || my_gw="${gw}"
    test_ip "${my_gw}"

    mod="static\n\taddress\t${my_ip}\n\tgateway\t${my_gw}"
    sed "s/${iface} inet dhcp/${iface} inet ${mod}/" -i /etc/network/interfaces

    if [[ ${my_ip} != ${ip} ]]; then
        ip link set "${iface}" down
        ip addr del "${ip}"/24 dev "${iface}"
        ip addr add "${my_ip}"/24 dev "${iface}"
        ip link set "${iface}" up
    fi

    [[ ${my_gw} != ${gw} ]] && ip route add default via "${my_gw}"
}

fix_ip() {
    iface=$(ip route | awk '/default/ {print$5}')
    gw=$(ip route | awk '/default/ {print$3}')
    ip="$(ip a sh "${iface}" | awk '/inet /{sub("/.*",""); print $2}')"

    # TODO: whiptail TUI - yes/no
    if grep -q "${iface} *dhcp" /etc/network/interfaces; then
        echo -e "${WRN} ip address is not fixed."
        read -p "Fix ip address [Y/n] ? " -rn1 fixip
        [[ ${fixip} ]] && echo || fixip=y
        [[ ${fixip,,} =~ ^(y|n)$ ]] || { echo -e "${ERR} Invalid answer '${fixip}'" && exit 1; }
        [[ ${fixip,,} == y ]] && fix_my_ip
    fi
}

stable_sources() {
    cat <<eof > /etc/apt/sources.list
# ${STABLE}
deb http://deb.debian.org/debian/ ${STABLE} main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian/ ${STABLE} main contrib non-free non-free-firmware
# ${STABLE} security
deb http://deb.debian.org/debian-security/ ${STABLE}-security/updates main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian-security/ ${STABLE}-security/updates main contrib non-free non-free-firmware
# ${STABLE} volatiles
deb http://deb.debian.org/debian/ ${STABLE}-updates main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian/ ${STABLE}-updates main contrib non-free non-free-firmware
# ${STABLE} backports
deb http://deb.debian.org/debian/ ${STABLE}-backports main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian/ ${STABLE}-backports main contrib non-free non-free-firmware
eof
}

clean_sources_menu() {
    clsrc_title="Clean sources.list"
    clsrc_text="Modify /etc/apt/sources.list to include properly all needed branches ?"
    (whiptail --title "${clsrc_title}" --yesno "${clsrc_text}" 8 78) && stable_sources
}

init_pkglists() {
    usefull=/tmp/usefull_pkgs
    pkg_lists="${SCRIPT_PATH}"/pkg

    rm -f "${usefull}"

    cp "${pkg_lists}"/base "${usefull}"
}

sys_update() {
    echo -e "${nfo} upgrading system..."
    apt update
    apt upgrade -y
    apt full-upgrade -y
}

install_packages() {
    init_pkglists

    sys_update

    echo -e "${nfo} installing new packages then removing useless ones..."

    xargs apt install -y < "${usefull}"

    apt autoremove --purge -y
}

copy_conf() {
    local src="$1"
    local dst="$2"

    if [[ -f "${src}" ]]; then
        cp "${src}" "${dst}"/."$(basename "${src}")"
    elif [[ -d "${src}" ]]; then
        mkdir -p  "${dst}"/."$(basename "${src}")"
        cp -r "${src}"/* "${dst}"/."$(basename "${src}")"/
    fi
}

system_config() {
    echo -e "${NFO} Applying custom system configuration..."

    my_conf=("profile" "vim" "bashrc")
    for conf in "${my_conf[@]}"; do
        copy_conf "${SCRIPT_PATH}/dotfiles/${conf}" /root
    done

    vimplug_url="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    curl -fLo /root/.vim/autoload/plug.vim --create-dirs "${vimplug_url}"
    vim +PlugInstall +qall

    my_git_url="https://github.com/choopsit/my_debian.git"
    my_debian=/tmp/my_debian
    rm -rf "${my_debian}"
    git clone "${my_giturl}" "${my_debian}"
    "${my_debian}"/deployment/deploy_systools.sh
}

finish() {
    echo -e "${NFO} base deployed.\nEnjoy ;)"
    . ${HOME}/.profile
}

# check arguments
[[ $2 ]] && echo -e "${ERR} Too many arguments" && usage 1
if [[ $1 =~ ^-(h|-help)$ ]]; then
    usage 0
elif [[ $1 ]]; then
    echo -e "${ERR} Bad argument" && usage 1
fi

# check relevance
[[ $(whoami) != root ]] && echo -e "${ERR} Need higher privileges" && exit 1

my_dist="$(awk -F= '/^ID=/{print $2}' /etc/os-release)"
[[ ${my_dist} != debian ]] &&
    echo -e "${ERR} $(basename "$0") works only on Debian" && exit 1

debian_version="$(lsb_release -sc)"
if [[ ${debian_version} != "${STABLE}" ]]; then
    echo -e "${ERR} '${debian_version}' not supported" && exit 1
fi

# deploy base
fix_ip
clean_sources_menu
install_packages
system_config
finish
