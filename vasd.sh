#!/bin/sh -e
# set -e and stop on all errors

#==============================================================================
# Copyright 2018 One Identity LLC. ALL RIGHTS RESERVED.
#
# Version: 4.1.5.23440
#
#==============================================================================

# Restore path for users /home dir
RESTORE_PATH="/home/"

PROJECT_NAME="vasd"
DIRNAME=$(dirname $0)

cd "$DIRNAME"

MAKEFILE="/usr/share/selinux/devel/Makefile"
test -f $MAKEFILE || ( echo "Missing $MAKEFILE, dependencies not met"; exit 1; )

SEMANAGE="$(which semanage)"
SEMODULE="$(which semodule)"
RESTORECON="$(which restorecon)"
AUDIT2ALLOW="$(which audit2allow)"
MATCHPATHCON="$(which matchpathcon)"

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

check_if_root()
{
        if [ `id -u` != 0 ]; then
                echo 'You must be root to run this command'
                return 1
        fi
}

adjust_fcontext()
{
        fcontext_from="$1"
        fcontext_to="$2"

        if [ -x "$SEMANAGE" ]; then
                $SEMANAGE fcontext -m -t $fcontext_from "$fcontext_to"
        fi
}

restore_fcontext()
{
        fcontext_filename="$1"
        $RESTORECON -F -R -v "$fcontext_filename"
}

do_usage()
{
        echo "$0 [ clean | make | add | remove | update | status ]"
}

do_clean()
{
        echo "Cleaning $PROJECT_NAME SELinux Policy"
        make -f "$MAKEFILE" clean || return 1
        return 0
}

do_make()
{
        echo "Building $PROJECT_NAME SELinux Policy"
        make -f "$MAKEFILE" || return 1
        return 0
}

do_add()
{
        # Check if we are running as root
        check_if_root
        # Clean the policy
        do_clean
        # Make the policy
        do_make
        echo -n "Adding $PROJECT_NAME SELinux Policy ... "
        $SEMODULE -i $PROJECT_NAME.pp && echo "OK" || echo "FAILED"

        # RHEL bug# 1141967 causes setting the fcontext of "/var/opt/quest/vas/vasd(/.*)?"
        # in the *.fc file to fail.
        # Always adjust the fcontext of "/var/opt/quest/vas/vasd(/.*)?" by hand in order to 
        # work around this bug. Reset to system default on removal.
        adjust_fcontext "vasd_var_auth_t" "/var/opt/quest/vas/vasd(/.*)?"

        restore_fcontext "/etc/rc.d/init.d/vasd"
        restore_fcontext "/etc/init.d/vasd"
        restore_fcontext "/opt/quest"
        restore_fcontext "/etc/opt/quest"
        restore_fcontext "/var/opt/quest"

        # Restart the vasd daemon if it is already running so it picks up the new policy.
        service vasd status >/dev/null && service vasd restart

        return 0
}

do_remove()
{
        # Check if we are running as root
        check_if_root
        echo -n "Removing $PROJECT_NAME SELinux Policy ... "
        adjust_fcontext "var_auth_t" "/var/opt/quest/vas/vasd(/.*)?"
        $SEMODULE -r $PROJECT_NAME && echo "OK" || echo "FAILED"

        # Restart the vasd daemon if it is already running so it picks up the new policy.
        service vasd status >/dev/null && service vasd restart

        return 0
}

do_update()
{
        # Check if we are running as root
        check_if_root
        echo "Updating $PROJECT_NAME SELinux policy"
        # Check to see if we are in an interactive shell
        if [[ -t 0 || -p /dev/stdin ]]; then
                time=`ls -l --time-style="+%x %X" $PROJECT_NAME.te | awk '{ printf "%s %s", $6, $7 }'`
                set +e
                rules=`ausearch --start $time -m avc --raw -se $PROJECT_NAME`
                if [ x"$rules" != "x" ] ; then
                        set -e
                        echo "Found avc's to update policy with"
                        echo -e "$rules" | $AUDIT2ALLOW -R
                        if yesorno "Do you want these changes added to $PROJECT_NAME policy?"; then
                                echo "Updating policy"
                                echo -e "$rules" | $AUDIT2ALLOW -R >> $PROJECT_NAME.te
                                # Rebuild policy
                                do_add
                        fi
                else
                        echo "No new avcs found"
                        set -e
                fi
        else
                echo "Update is not supported in a non-interactive shell"
                return 1
        fi

        return 0
}

do_restore()
{
		restore_path="${1:-"$RESTORE_PATH"}"
        # Check if we are running as root
        check_if_root
        if [ ! -d "$restore_path" ]; then
            echo "Invalid file path: "$restore_path""
            return 1
        fi
        echo "Restoring files(s) default SELinux security contexts for "$restore_path""
        set +ex
        # Check the $RESTORE_PATH (Which is /home/) to see if any of the labels are wrong
        output=`$RESTORECON -viRn "$restore_path" | /bin/awk '{print $3}'`
        match_output=`$MATCHPATHCON -V $output`

        ## If we have output here then print out the wrong lables and ask if we should restore them.
        if [ -n "$output" ]; then
                printf "The following files from your "$restore_path" have the incorrect SELinux contexts\n"
                echo "$match_output"
                if yesorno "Do you want to restore the default SELinux security contexts on the $restore_path directory?"; then
                        restore_fcontext "$restore_path"
                        # Restart the vasd daemon if it is already running so it picks up the new policy.
                        service vasd status >/dev/null && service vasd restart
                fi
        else
                echo "$restore_path SELinux security contexts look correct"
        fi
        set -e

        return 0
}

do_status()
{
        echo -n "Checking if $PROJECT_NAME SELinux policy is installed ... "
        $SEMODULE -l | grep -w ^"$PROJECT_NAME" >/dev/null && ( echo "Yes"; return 0) || ( echo "No"; return 1 )
}

if [ $# -ge 1 ]; then
        case "$1" in
                "clean")
                        do_clean
                ;;
                "make")
                        do_make
                ;;
                "add")
                        do_add
                ;;
                "remove")
                        do_remove
                ;;
                "update")
                        do_update
                ;;
                "status")
                        do_status
                ;;
                "restore")
                        do_restore "$2"
                ;;
                *)
                        do_usage
                ;;
        esac
else
        do_usage
fi
