#!/bin/bash

#set -e

# Command
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}

user_name=tamas

# Check password
pass_check() {

    echo "RUN PASS CHECK FUNCTION"

    user_name=$1
    userpass1=$2
    userpass2=$3
    rootpass1=$4
    rootpass2=$5
    
    if [ "$userpass1" != "$userpass2" ]
    then
        yad --image=error --title="$TITLE"  --buttons-layout=center --text="$ERR_USER_PASS"
        echo "Not same user password"
        user_root_set
    elif [ "$rootpass1" != "$rootpass2" ]
    then
        yad --image=error --title="$TITLE" --buttons-layout=center --text="$ERR_ROOT_PASS"
        echo "Not same root password"
        user_root_set
    fi
}
    
    
echo "# $INS002"
    touch .passwd
    echo -e "$rootpass1\n$rootpass2" > .passwd
    arch_chroot "passwd root" < .passwd >/dev/null
    rm .passwd
    
echo "# $INS003"
    #arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
    touch .passwd
    echo -e "$userpass1\n$userpass2" > .passwd
    arch_chroot "passwd $user_name" < .passwd >/dev/null
    rm .passwd
