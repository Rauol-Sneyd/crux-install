#!/bin/sh
# Copyright 2019 Andy Kosela.  All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

version=3.5

main() {
	echo "Welcome to the CRUX $version installation program."
	echo "" 
	echo -n "(I)nstall, (U)pgrade, or (S)hell? [i] "
	read resp
	case $resp in
	[Ii])
		install
		;;
	[Uu])
		upgrade
		;;
	[Ss])
		shell
		;;
	*)
		install
		;;
	esac
}

shell() {
	exit
}

upgrade() {
	disk
	diskn
	echo -n "Which partition is the root? [${rdisk}2] "
	read rdiskr
	rdiskr=${rdiskr:-${rdisk}2}
	mount /dev/$rdiskr /mnt
	/usr/bin/setup
	chroot
	upgrade_kernel
	end
}

install() {
	hostname
	network
	timezone
	disk
	diskn
	echo -n "Which partition is the root? [${rdisk}2] "
	read rdiskr
	rdiskr=${rdiskr:-${rdisk}2}
	mount /dev/$rdiskr /mnt
	setup
	chroot
	password
	user
	etc
	kernel
	end
}

hostname() {
	echo -n "System hostname? [crux] "
	read hostn
	hostn=${hostn:-crux}
}

network() {
	nic=`ifconfig -a | grep HWaddr | cut -d' ' -f1 | paste -sd ' '`
	nic1=`echo $nic | cut -d' ' -f1`
	echo ""
	echo "Available network interfaces are: $nic"
	echo -n "Which network interface do you wish to configure? (or (N)one) [$nic1] "
	read nic_conf
	case $nic_conf in
	[NnOoNnEe]*)
		nic_conf=''
		;;
	*)
		nic_conf=${nic_conf:-$nic1}
		ipv4
		;;
	esac
}

ipv4() {
	echo -n "IPv4 address for $nic_conf? [dhcp] "
	read ip
	case $ip in
	[0-9]*)
		echo -n "Subnet mask for $nic_conf? [24] "
		read subnet_mask
		subnet_mask=${subnet_mask:-24}

		gw=`echo $ip | sed 's/\([0-9]*.[0-9]*.[0-9]*.\)[0-9]*/\11/'`
		echo -n "Gateway for $nic_conf? [$gw] "
		read gw2
		gw2=${gw2:-$gw}
		echo -n "Primary DNS server? [$gw2] "
		read ns1
		ns1=${ns1:-$gw2}
		echo -n "Secondary DNS server? [none] "
		read ns2
		;;
	*)
		ip=dhcp
		;;
	esac
}

timezone() {
	echo -n "What timezone are you in? [UTC] "
	read tzone
	tzone=${tzone:-UTC}
}

disk() {
	disks=`lsblk | grep disk | cut -d' ' -f1 | paste -sd ' '`
	disk1=`echo $disks | cut -d' ' -f1`
	echo ""
	echo "Available disks are: $disks"
}

diskn() {
	echo -n "Which disk is the root disk? ('?' for details) [$disk1] "
	read rdisk
	case $rdisk in
	?)
		lsblk | grep -e NAME -e disk
		diskn
		;;
	*)
		rdisk=${rdisk:-$disk1}
		;;
	esac
 
setup() {
	echo "Your CRUX root partition has been mounted at /mnt."
	echo ""
	echo -n "Core packages only? [y] "
	read resp
	case $resp in
	[Nn])
		k=1
		/usr/bin/setup
		;;
	*)
		k=0
		install_pkg
		;;
	esac
}

install_pkg() {
	crux=/media/crux
	src=/mnt/usr/src

	if [ ! -d /mnt/var/lib/pkg ]; then
		mkdir -p /mnt/var/lib/pkg
		touch /mnt/var/lib/pkg/db
	fi
	if [ -d /mnt/var/lib/pkg/rejected ]; then
		rm -rf /mnt/var/lib/pkg/rejected
	fi
	if [ ! -d $src ]; then
		mkdir -p $src
	fi
	if [ ! -d /mnt/root ]; then
		mkdir -p /mnt/root
	fi

	echo -n "Installing packages... "
	for pkg in `ls -1 $crux/core`; do
		pkgadd -r /mnt $crux/core/$pkg >/dev/null 2>&1
	done
}

chroot() {
	mount --bind /dev /mnt/dev
	mount --bind /tmp /mnt/tmp
	mount --bind /run /mnt/run
	mount -t proc proc /mnt/proc
	mount -t sysfs none /mnt/sys
	mount -t devpts -o noexec,nosuid,gid=tty,mode=0620 devpts /mnt/dev/pts

	if grep -qs /sys/firmware/efi/efivars /proc/mounts; then
		mount --bind /sys/firmware/efi/efivars \
			/mnt/sys/firmware/efi/efivars
	fi
	chr="/usr/bin/chroot /mnt"
}

password() {
	sed -i -e '/PASS_ALWAYS_WARN/s/yes/no/' \
		-e '/USERGROUPS_ENAB/s/no/yes/' /mnt/etc/login.defs \
		>/dev/null 2>&1
	echo ""
	echo "Creating password for root account."
	$chr passwd -q
}

user() {
	echo -n "Please create a local account. [user] "
	read RESP
	RESP=${RESP:-user}
	export RESP
	$chr useradd -m -c $RESP -s /bin/bash $RESP
	$chr passwd -q $RESP
}

etc() {
	cat >/mnt/etc/fstab <<EOF
/dev/$rdiskr / $fs defaults 0 1
devpts /dev/pts devpts noexec,nosuid,gid=tty,mode=0620 0 0
shm /dev/shm tmpfs defaults 0 0
EOF

	cat >/mnt/etc/hosts <<EOF
127.0.0.1	localhost
EOF
	if [ ! $ns1 = '' ]; then
		if [ ! $ns2 = '' ]; then
			cat >/mnt/etc/resolv.conf <<EOF
nameserver $ns1
nameserver $ns2
EOF
		else
			cat >/mnt/etc/resolv.conf <<EOF
nameserver $ns1
EOF
		fi
	fi

	cat >/mnt/etc/rc.conf <<EOF
#
# /etc/rc.conf: system configuration
#

FONT=default
KEYMAP=us
TIMEZONE=$tzone
HOSTNAME=$hostn
SYSLOG=sysklogd
SERVICES=(lo net crond sshd)

# End of file
EOF

	if [ ! $gw2 = '' ]; then
		sed -i -e 's/="DHCP"/="static"/'		\
			-e "s/DEV=.*/DEV=$nic_conf/"		\
			-e "s/ADDR=.*/ADDR=$ip/" 		\
			-e "s/MASK=.*/MASK=$subnet_mask/"	\
			-e "s/GW=.*/GW=$gw2/" /mnt/etc/rc.d/net
	fi
}

upgrade_kernel() {
	merge
	echo -n "Upgrade kernel? [n] "
	read resp 
	case $resp in
	[Yy])
		kernel
		;;
	*)
		resp=n
		;;
	esac
}

kernel() {
	echo ""
	echo "Configuring kernel."
	echo -n "Build your own kernel? [y] "
	read resp
	case $resp in
	[Yy])
		build_kernel
		;;
	[Nn])
		download_kernel
		;;
	*)
		build_kernel
		;;
	esac
}
 
backup_kernel() {
	if [ -f /mnt/boot/vmlinuz ]; then
		cp /mnt/boot/vmlinuz /mnt/boot/vmlinuz.old
		cp /mnt/boot/System.map /mnt/boot/System.map.old
	fi
}

untar_kernel() {
	echo -n "Copying and uncompressing kernel tarball... "
	tar -C $src -xJf $kernel
	cp -f $crux/kernel/linux-$kernel_version.defconfig \
		$src/linux-$kernel_version/.config
	chown -R root.root $src/linux-$kernel_version
	chmod -R go-w $src/linux-$kernel_version
	if [ -f $crux/kernel/*patch ]; then
		for patch in $crux/kernel/*patch; do
			patch -sd $src/linux-$kernel_version -p1 < $patch
			cp $patch $src
		done
	fi
	if [ ! -d /mnt/lib/modules/$kernel_version ]; then
		mkdir -p /mnt/lib/modules/$kernel_version
		depmod -b /mnt -a $kernel_version >/dev/null 2>&1
	fi
}

build_kernel() {
	export DIR=usr/src/linux-*
	kernel=$crux/kernel/linux-*.tar.xz
	kernel_version=`basename $kernel .tar.xz | sed "s/linux-//"`

	if [ $k = 0 ]; then
		untar_kernel
	fi

	echo ""
	echo -n "Download custom .config? [n] " 
	read resp
	case $resp in
	[Yy])
		echo -n "Location of .config?  ('http://example.org/.config' "
		echo -n "or (ssh) 'user@example.org:/tmp/.config') "
		read config
		case $config in
		[http]*)
			wget --no-ch -q $config
			cp .config $src/linux-$kernel_version
			;;
		[ftp]*)
			wget --no-ch -q $config
			cp .config $src/linux-$kernel_version
			;;
		*)
			scp $config $src/linux-$kernel_version
			;;
		esac
		;;
	*)
		resp=n
		;;
	esac

	cpus=$((`nproc`+1))
	$chr /bin/bash -c "cd /$DIR && make menuconfig"
	$chr /bin/bash -c "cd /$DIR && make -j $cpus all"
	$chr /bin/bash -c "cd /$DIR && make modules_install"

merge() {
	$chr rejmerge
}

end() {
	echo ""
	echo "Your CRUX system is ready.  Please reboot."
	echo -n "Exit to (S)hell, (H)alt, or (R)eboot? [r] "
	read resp
	case $resp in
	[Ss])
		echo "Your root is mounted at /mnt."
		exit
		;;
	[Hh])
		/sbin/shutdown -Ph now
		;;
	*)
		/sbin/reboot
		;;
	esac
}

main
