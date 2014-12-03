# SELinux VAS Module

Jayson Hurst <jayson.hurst@software.dell.com>

# Description

A Red Hat Enterprise Linux SELinux policy for the Dell Authentication Services (a.k.a QAS or VAS)

INSTALLATION
------------
Requires:
 * Dell Authentication Services 4.1.0.20886 or newer.

Dependencies:
 * **RHEL 6 & equivalent** or higher 
 * policycoreutils-python (audit2allow)
 * policycoreutils (semodule, restorecon)

### Source

~~~bash
  $ git clone https://github.com/dell-oss/vasd-selinux.git
  $ cd vasd-selinux
  $ ./vasd.sh
~~~

#### Known Issues

When installing the vasd.pp SELinux policy the following error may occur (RHEL bug# 1141967)

~~~bash
 Multiple different specifications for /var/opt/quest/vas/vasd(/.*)?
~~~

On some versions of RHEL there is already a security context defined for the /var/opt/quest/vas/vasd directory.

**Workaround** 

1. Modify the file vasd.fc and comment out the following line:

~~~bash
# /var/opt/quest/vas/vasd(/.*)?   gen_context(system_u:object_r:vasd_var_auth_t,s0)
~~~

2. Modify the file vasd.sh and add the following line below:

~~~ bash
 make -f /usr/share/selinux/devel/Makefile || exit
 /usr/sbin/semodule -i qasd.pp <<<<< Add below this line
 
 semanage fcontext -m -t vasd_var_auth_t "/var/opt/quest/vas/vasd(/.*)?"
~~~
