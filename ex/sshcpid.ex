#!/usr/bin/env expect
#
# Script to install your ssh public key on a remote machine.  This is an
# enhanced version of /usr/bin/ssh-copy-id, it utilizes expect(1) to input
# password automatically.  Run me without argument to get usage information.
#
# $Id$

if {$argc < 3} {
    puts ""
    puts "Usage: sshcpid.ex <hostname> <password> <pubkey> \[ssh_options...]"
    puts ""
    puts "E.g. : sshcpid.ex 12.34.56.78 'ChangeMe' identity.pub -l root"
    puts ""
    puts "Ssh_options are extra ssh options, most used options are"
    puts ""
    puts "    -l login_name"
    puts "    -p port"
    puts "    -o UserKnownHostsFile=/path/to/file"
    puts "    -o CheckHostIP=yes|no"
    puts "    -o StrictHostKeyChecking=yes|no"
    puts ""
    puts "See ssh(1) and ssh_config(5) for details."
    puts ""
    exit 1
}

set hostname        [lindex $argv 0]
set password        [lindex $argv 1]
set pubkey          [lindex $argv 2]

# Form ssh options
set sshoptions  "-o PreferredAuthentications=keyboard-interactive,password -o VerifyHostKeyDNS=no"
for {set i 3} {$i < $argc} {incr i 1} {
    set sshoptions "$sshoptions [lindex $argv $i]"
}

# Read pubkey and save into $publickey
set pubkey_fd       [open $pubkey]
set publickey       [read $pubkey_fd]
close $pubkey_fd
set publickey       [string trimright "$publickey" "\n"]

set new_ps1         "\n(sshcpid.ex)# "
set sshd_cfg        "/etc/ssh/sshd_config"

set timeout 120
eval spawn ssh -F /dev/null $sshoptions $hostname
expect {
    "continue connecting (yes/no)\? " {
        send "yes\r"
        expect "assword: "
        sleep 1
        send "$password\r"
    }
    "assword: " {
        send "$password\r"
    }
    -re "\\\$|#|>" {
        send "\r"
    }
    "Connection refused" {
        puts "*** sshd not running?"
        exit 1
    }
    "Host key verification failed" {
        puts "*** Offending host key, system reinstalled?"
        exit 1
    }
    timeout {
        puts "*** Timed out."
        exit 1
    }
}

# First command: set PS1 and disable command "clear" by making an empty alias
# for it to keep output on the screen after ssh session ended (works for Redhat)
#
expect {
    -re "\\\$|#|>" {
        send "PS1='$new_ps1'; alias clear=''\r"
    }
    "assword:" {
        puts "*** Wrong password?"
        exit 1
    } timeout {
        puts "*** Timed out."
        exit 1
    }
}

# Other commands
#

# Create dirs
expect {
    -re "Connection to .* closed." {
        exit 1
    }
    "$new_ps1" {
        send "mkdir -p ~/.ssh || exit 1\r"
    }
}

# Shouldn't overwrite authorized_keys, append instead
expect {
    -re "Connection to .* closed." {
        exit 1
    }
    "$new_ps1" {
        send "AKEY=~/.ssh/authorized_keys\r"
        send "PUBKEY='$publickey'\r"
        send "grep -q \"^\$PUBKEY\" \$AKEY 2>/dev/null || "
        send "/bin/echo \"\$PUBKEY\" >> \$AKEY || exit 1\r"
    }
}

# file/dir permissions
expect {
    -re "Connection to .* closed." {
        exit 1
    }
    "$new_ps1" {
        send "chmod go-w ~ \$AKEY || exit 1\r"
    }
}
expect {
    -re "Connection to .* closed." {
        exit 1
    }
    "$new_ps1" {
        send "chmod 700 ~/.ssh || exit 1\r"
    }
}

# Turn off sshd hostname backward DNS resolving if we have enough permission
expect {
    -re "Connection to .* closed." {
        exit 1
    }
    "$new_ps1" {
        send "test -w $sshd_cfg || exit 0\r"
        send "if test -x /etc/init.d/sshd; then SSHD=/etc/init.d/sshd\r"
        send "elif test -x /etc/init.d/ssh; then SSHD=/etc/init.d/ssh\r"
        send "else exit 1; fi\r"
        send "grep -iqE '^\[\[:blank:]]*UseDNS\[\[:blank:]]+no'"
        send " $sshd_cfg || {\r"
        send "  sed -i '/UseDNS /d; \$a\\\nUseDNS no' $sshd_cfg || exit 1\r"
        send "  \$SSHD restart || exit 1\r"
        send "}\r"
    }
}

# Last command: exit 0
#
expect "$new_ps1"
send "exit 0\r"

set timeout 30
expect eof
exit 0

# vim:set tw=80 et sts=4 ts=8 sw=4:
