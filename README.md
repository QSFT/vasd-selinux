# SELinux VAS Module

## Description

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

### Reporting Bugs
To report an issue with the vasd-selinux module please use <a href="https://bugsrc.quest.com/buglist.cgi?component=vasd%20selinux%20policy&list_id=101&product=vasd-selinux">Bugzilla</a> to submit a bug report.
When creating a bug report please try to pinpoint the exact problem and provide detailed reproduction steps.

#### Known Issues

-- When installing the vasd.pp SELinux policy the following error may occur (RHEL bug# 1141967)

    Multiple different specifications for /var/opt/quest/vas/vasd(/.*)?

On some versions of RHEL there is already a security context defined for the /var/opt/quest/vas/vasd directory.

***Workaround*** 

1. Modify the file vasd.fc and comment out the following line:

        # /var/opt/quest/vas/vasd(/.*)?   gen_context(system_u:object_r:vasd_var_auth_t,s0)

2. Modify the file vasd.sh and add the **semanage** line below following section:

        make -f /usr/share/selinux/devel/Makefile || exit
        /usr/sbin/semodule -i vasd.pp <<<<< Add below this line
 
        semanage fcontext -m -t vasd_var_auth_t "/var/opt/quest/vas/vasd(/.*)?"

-- After installing the vasd-selinux policy user home directories that were created prior to the policy being installed might have the incorrect SELinux security context label.

***Workaround***

 It is suggested that the home directories should be restored to their default file contexts by running:

~~~bash
    sbin/restorecon -F -R -v /home
~~~
  Where */home* is the path to the users home directories that need the correct SElinux context label.
  
  
Jayson Hurst <jayson.hurst@software.dell.com>
