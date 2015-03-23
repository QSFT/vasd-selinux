#!/bin/sh -e

PROJECT_NAME="vasd"
DIRNAME=`dirname $0`
cd $DIRNAME
USAGE="$0 [ --update ][ clean ]"
if [ `id -u` != 0 ]; then
echo 'You must be root to run this script'
exit 1
fi

MAKEFILE="/usr/share/selinux/devel/Makefile"

if [ $# -eq 1 ]; then
        if [ "$1" = "--update" ] ; then
                time=`ls -l --time-style="+%x %X" $PROJECT_NAME.te | awk '{ printf "%s %s", $6, $7 }'`
                rules=`ausearch --start $time -m avc --raw -se $PROJECT_NAME`
                if [ x"$rules" != "x" ] ; then
                        echo "Found avc's to update policy with"
                        echo -e "$rules" | audit2allow -R
                        echo "Do you want these changes added to policy [y/n]?"
                        read ANS
                        if [ "$ANS" = "y" -o "$ANS" = "Y" ] ; then
                                echo "Updating policy"
                                echo -e "$rules" | audit2allow -R >> $PROJECT_NAME.te
                                # Fall though and rebuild policy
                        else
                                exit 0
                        fi
                else
                        echo "No new avcs found"
                        exit 0
                fi
    elif [ "$1" = "clean" ]; then
        echo "Cleaning $PROJECT_NAME Policy"
        set -x
        make -f "$MAKEFILE" clean || exit
        exit 0
    elif [ "$1" = "make" ]; then
        echo "Making $PROJECT_NAME Policy"
        set -x
        make -f "$MAKEFILE" || exit
        exit 0
    elif [ "$1" = "remove" ]; then
        echo "Removing $PROJECT_NAME Policy"
        set -x
        semanage fcontext -m -t var_auth_t "/var/opt/quest/vas/vasd(/.*)?"
        semodule -r vasd
        exit 0
    else
        echo -e $USAGE
        exit 1
    fi
elif [ $# -ge 2 ] ; then
    echo -e $USAGE
    exit 1
fi

echo "Building and Loading Policy"
set -x
make -f "$MAKEFILE" || exit

/usr/sbin/semodule -i $PROJECT_NAME.pp

# Fixing the file context on /etc/rc\.d/init\.d/vasd
/sbin/restorecon -F -R -v /etc/rc\.d/init\.d/vasd
/sbin/restorecon -F -R -v /etc/init\.d/vasd

/sbin/restorecon -F -R -v /opt/quest/
/sbin/restorecon -F -R -v /etc/opt/quest/
/sbin/restorecon -F -R -v /var/opt/quest/

# Restart the vasd daemon so it picks up the new policy.
service vasd restart
