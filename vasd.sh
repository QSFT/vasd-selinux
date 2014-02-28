#!/bin/sh -e

DIRNAME=`dirname $0`
cd $DIRNAME
USAGE="$0 [ --update ][ clean ]"
if [ `id -u` != 0 ]; then
echo 'You must be root to run this script'
exit 1
fi

get_platform()
{
	case `uname -s` in
		Linux)
			PLATFORM=`lsb_release -a | grep Distributor | awk '{print $3}'`
			;;
		*)
			echo "Platform is not supported"
			;;
	esac
}

set_Makefile()
{
    get_platform

	case "$PLATFORM" in
		Ubuntu)
			MAKEFILE="/usr/share/selinux/default/include/Makefile"
			;;
		RedHatEnterpriseServer)
			MAKEFILE="/usr/share/selinux/devel/Makefile"
			;;
		*)
            MAKEFILE="/usr/share/selinux/devel/Makefile"
            ;;
	esac
}

set_Makefile

if [ $# -eq 1 ]; then
	if [ "$1" = "--update" ] ; then
		time=`ls -l --time-style="+%x %X" vasd.te | awk '{ printf "%s %s", $6, $7 }'`
		rules=`ausearch --start $time -m avc --raw -se vasd`
		if [ x"$rules" != "x" ] ; then
			echo "Found avc's to update policy with"
			echo -e "$rules" | audit2allow -R
			echo "Do you want these changes added to policy [y/n]?"
			read ANS
			if [ "$ANS" = "y" -o "$ANS" = "Y" ] ; then
				echo "Updating policy"
				echo -e "$rules" | audit2allow -R >> vasd.te
				# Fall though and rebuild policy
			else
				exit 0
			fi
		else
			echo "No new avcs found"
			exit 0
		fi
        elif [ "$1" = "clean" ]; then
                echo "Cleaning Policy"
                set -x
        	make -f "$MAKEFILE" clean || exit
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
/usr/sbin/semodule -i vasd.pp

#semanage fcontext -l | grep "/var/opt/quest/vas/vasd(/.*)?" && semanage fcontext -m -t vasd_var_auth_t "/var/opt/quest/vas/vasd(/.*)?"

# Fixing the file context on /opt/quest/sbin/.vasd
/sbin/restorecon -F -R -v /opt/quest/sbin/.vasd
# Fixing the file context on /etc/rc\.d/init\.d/vasd
/sbin/restorecon -F -R -v /etc/rc\.d/init\.d/vasd

/sbin/restorecon -F -R -v /opt/quest/
/sbin/restorecon -F -R -v /etc/opt/quest/
/sbin/restorecon -F -R -v /var/opt/quest/
