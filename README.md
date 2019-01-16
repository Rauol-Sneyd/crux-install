## crux-install

Interactive installation script for CRUX[1].  It is completely text based and
assumes sane defaults.  It speeds up CRUX installation by automating manual
steps and also allows customization.

## install

```
(1) Boot from ISO

(2) Initialize network

    # dhcpcd

(3) Download install script

    # wget --no-ch https://raw.githubusercontent.com/akosela/crux-install/master/install

(4) Run it

    # sh install
```

## help

The install script will ask you several questions.  The default answers (in [])
are sane and are designed to install a base CRUX system with a minimum of your
intervention.

```
Welcome to the CRUX 3.4 installation program.

(I)nstall, (U)pgrade, or (S)hell? [i]
```

Choosing the default answer [install] will perform a typical fresh
installation.

These are the questions you will be asked.

```
System hostname? [crux]
Which network interface do you wish to configure? (or (N)one) [eth0]
IPv4 address for eth0? [dhcp]
What timezone are you in? [UTC]
(A)uto-partition or (F)disk? [a]
Which filesystem you want to use? ('?' for list) [ext4]
Size of the swap partition? (in MB) [1024]
Core packages only? [y]
Creating password for root account.
New password:
Please create a local account. [user]
New password:
Build your own kernel? [n]
Copy kernel image from? (ssh) [user@example.org]
(L)ilo or (G)rub? [l]

Your CRUX system is ready.  Please reboot.
Exit to (S)hell, (H)alt, or (R)eboot? [r]
```

[1] http://crux.nu/
