#!/bin/sh -e
## Restore path for users /home dirs
RESTORE_PATH="/home/"

PROJECT_NAME="vasd"
DIRNAME=`dirname $0`
cd $DIRNAME
USAGE="$0 [ --update ][ clean ]"
if [ `id -u` != 0 ]; then
echo 'You must be root to run this script'
exit 1
fi

#-- prompt user for information
#   usage: query prompt varname [default]
query () {
    eval $2=
    while eval "test ! -n \"\$$2\""; do
    if read xx?yy <$0 2>/dev/null; then
        eval "read \"$2?$1${3+ [$3]}: \"" || die "(end of file)"
    else
        eval "read -p \"$1${3+ [$3]}: \" $2" || die "(end of file)"
    fi
    eval : "\${$2:=\$3}"
    done
}

#-- prompt for a yes/no question
yesorno () {
    echo "";
    while :; do
    query "$1" YESORNO y
    case "$YESORNO" in
        Y*|y*) echo; return 0;;
        N*|n*) echo; return 1;;
        *) echo "Please enter 'y' or 'n'" >&2;;
    esac
    done
}

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
        if [ -x "/usr/sbin/semanage" ]; then
            semanage fcontext -m -t var_auth_t "/var/opt/quest/vas/vasd(/.*)?"
        fi
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

if [ -x "/usr/sbin/semanage" ]; then
    semanage fcontext -m -t vasd_var_auth_t "/var/opt/quest/vas/vasd(/.*)?"
fi

# Fixing the file context on /etc/rc\.d/init\.d/vasd
/sbin/restorecon -F -R -v /etc/rc\.d/init\.d/vasd
/sbin/restorecon -F -R -v /etc/init\.d/vasd

/sbin/restorecon -F -R -v /opt/quest/
/sbin/restorecon -F -R -v /etc/opt/quest/
/sbin/restorecon -F -R -v /var/opt/quest/

set +ex
## Check the $RESTORE_PATH (Which is /home/) to see if any of the labels are wrong
output=`/sbin/restorecon -viRn "$RESTORE_PATH" | /bin/awk '{print $3}'`
match_output=`/sbin/matchpathcon -V $output`

## If we have output here then print out the wrong lables and ask if we should restore them.
if [ -n "$output" ]; then
    printf "The following files from your "$RESTORE_PATH" have the incorrect SELinux contexts\n"
    echo "$match_output"
    if yesorno "Do you want to restore the default SELinux security contexts on the user's /home directory?"; then
        /sbin/restorecon -F -R -v "$RESTORE_PATH"
    fi
fi
set -e

# Restart the vasd daemon if it is already running so it picks up the new policy.
service vasd status && service vasd restart

