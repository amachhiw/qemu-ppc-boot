#!/bin/bash
#
# Run a test doing a basic boot with network and poweroff for each PPC
# machines supported in QEMU using a builroot image
#
# Copyright (c) 2021, IBM Corporation.
#
# This work is licensed under the terms of the GNU GPL version 2. See
# the COPYING file in the top-level directory.

me=${0##*/}

qemu_prefix=/usr
buildroot_dir=./buildroot
quiet=

# ref405ep is broken, mac99+7450 also
machines32="bamboo sam460ex g3beige mac99 e500mc" 

# lack support for powernv10
machines64="e5500 g5-32 g5-64 pseries pseriesle powernv8 powernv9" 

machines="$machines32 $machines64"

usage()
{
    cat <<EOF
$me 1.0

Usage: $me [OPTION] <board ...>

Known values for OPTION are:

    -h|--help			display this help and exit
    -q|--quiet			all outputs are redirected to a logfile per machine
    -p|--prefix	<DIR>		install prefix of QEMU binaries
				Defaults to "$qemu_prefix".
    -b|--buildroot <DIR>	directory where to find builroot images. 
				Defaults to "$buildroot_dir".

Possible machines are:

    $machines

EOF
    exit 1;
}

options=`getopt -o hqp:b: -l help,quiet,prefix:,buildroot: -- "$@"`
if [ $? -ne 0 ]
then
        usage
fi
eval set -- "$options"

while true
do
    case "$1" in
	-h|--help)	usage ;;
	-q|--quiet)	quiet=1; shift 1;;
	-p|--prefix)	qemu_prefix="$2"; shift 2;;
	-b|--buildroot)	buildroot_dir="$2"; shift 2;;
	--)		shift 1; break ;;
	*)		break ;;
    esac
done

qemu="$qemu_prefix/bin/qemu-system-ppc"

spawn_qemu()
{
    machine=$1
    logfile=${machine}.log

    timeout=20

    case "$machine" in
	ref405ep)
	    buildroot_images=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-M $machine -bios $buildroot_images/ppc405_rom.bin -serial null"
	    kernel_args="-kernel $buildroot_images/cuImage.hotfoot"
	    initrd_args="-initrd $buildroot_images/rootfs.cpio.uboot"
	    ;;

	bamboo)
	    buildroot_images=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-M $machine"
	    kernel_args="-kernel $buildroot_images/vmlinux"
	    net_args="-net nic,model=virtio-net-pci -net user"
	    ;;

	sam460ex)
	    buildroot_images=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-M $machine"
	    kernel_args="-kernel $buildroot_images/vmlinux"
	    net_args="-device virtio-net-pci,netdev=net0 -netdev user,id=net0"
	    ;;

	g3beige)
	    buildroot_images=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-m 1G -M $machine -cpu g3"
	    kernel_args="-kernel $buildroot_images/vmlinux -append \"root=/dev/sda\""
	    net_args="-net nic,model=rtl8139 -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,format=raw"
	    ;;
	
	e500mc)
	    buildroot_images=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-m 1G -M ppce500 -cpu e500mc"
	    kernel_args="-kernel $buildroot_images/uImage -append \"root=/dev/vda\""
	    net_args="-net nic,model=virtio-net-pci -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,if=virtio,format=raw"
	    ;;
	
	e5500)
	    qemu64=64
	    buildroot_images=$buildroot_dir/qemu_ppc64_${machine}-latest
	    
	    machine_args="-m 1G -M ppce500 -cpu e5500"
	    kernel_args="-kernel $buildroot_images/uImage -append \"root=/dev/vda\""
	    net_args="-net nic,model=virtio-net-pci -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,if=virtio,format=raw"
	    ;;

	mac99)
	    buildroot_images=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-m 1G -M ${machine},via=pmu -cpu g4"
	    kernel_args="-kernel $buildroot_images/vmlinux -append \"root=/dev/sda\""
	    net_args="-net nic,model=sungem -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,format=raw"
	    ;;
	
	g5-32)
	    qemu64=64
	    machine=mac99
	    buildroot_images64=$buildroot_dir/qemu_ppc64_${machine}-latest
	    buildroot_images32=$buildroot_dir/qemu_ppc_${machine}-latest
	    
	    machine_args="-m 1G -M ${machine},via=pmu -cpu 970"
	    kernel_args="-kernel $buildroot_images64/vmlinux -append \"root=/dev/sda\""
	    net_args="-net nic,model=sungem -net user"
	    hd_args="-drive file=$buildroot_images32/rootfs.ext2,format=raw"
	    ;;
	
	g5-64)
	    qemu64=64
	    machine=mac99
	    buildroot_images=$buildroot_dir/qemu_ppc64_${machine}-latest
	    
	    machine_args="-m 1G -M ${machine},via=pmu -cpu 970"
	    kernel_args="-kernel $buildroot_images/vmlinux -append \"root=/dev/sda\""
	    net_args="-net nic,model=sungem -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,format=raw"
	    ;;
	
	pseries)
	    timeout=30
	    qemu64=64
	    buildroot_images=$buildroot_dir/qemu_ppc64_${machine}-latest
	    poweroff_expect="Power down"

	    machine_args="-m 1G -M $machine -cpu POWER7"
	    kernel_args="-kernel $buildroot_images/vmlinux -append \"root=/dev/sda\""
	    net_args="-net nic -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,if=scsi,format=raw"
	    ;;
	
	pseriesle)
	    timeout=30
	    qemu64=64
	    machine=pseries
	    buildroot_images=$buildroot_dir/qemu_ppc64le_${machine}-latest
	    
	    machine_args="-m 1G -M $machine -cpu POWER8"
	    kernel_args="-kernel $buildroot_images/vmlinux -append \"root=/dev/sda\""
	    net_args="-net nic -net user"
	    hd_args="-drive file=$buildroot_images/rootfs.ext2,if=scsi,format=raw"
	    ;;
	
	powernv*)
	    timeout=30
	    qemu64=64
	    buildroot_images=$buildroot_dir/qemu_ppc64le_powernv-latest
	    
	    machine_args="-m 1G -M $machine -device ipmi-bmc-sim,id=bmc0 -device isa-ipmi-bt,bmc=bmc0,irq=10"
	    kernel_args="-kernel $buildroot_images/vmlinux -append \"root=/dev/nvme0n1\""
	    net_args="-device e1000e,bus=pcie.1,addr=0x0,netdev=net0 -netdev user,id=net0"
	    hd_args="-device nvme,bus=pcie.2,addr=0x0,drive=drive0,serial=1234 \
 -drive file=$buildroot_images/rootfs.ext2,if=none,id=drive0,format=raw,cache=none"
	    ;;
	*)
 	    echo "invalid machine \"$machine\"";
	    exit 1;
    esac 

    qemu_cmd="$qemu$qemu64 $machine_args $kernel_args $initrd_args $hd_args $net_args"
    qemu_cmd="$qemu_cmd -serial stdio -nodefaults -nographic"

    if [ -n "$quiet" ]; then
	exec 1>$logfile 2>&1
    fi

    #
    # TODO : 
    #  - Exit faster
    #  - Catch more error
    #    . SIGILL for unimplemented instructions 
    #    . SIGSEGV
    #
    expect \
	-c "spawn $qemu_cmd" \
	-c "set timeout $timeout" \
	-c 'expect timeout { exit 1 } "buildroot login:"' \
	-c 'send "root\r"' \
	-c 'expect timeout { exit 1 } "#"' \
	-c 'send "poweroff\r"' \
	-c 'expect timeout { exit 1 } "halted"' \
	-c "expect -i $spawn_id eof"
}

tests_machines=${*:-"$machines"}

exec 3>&1

for m in $tests_machines; do
    echo -n "$m : " >&3
    spawn_qemu $m && pass=OK || pass=FAILED
    echo "$pass" >&3
done