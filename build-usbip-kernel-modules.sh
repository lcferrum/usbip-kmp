#!/bin/sh

if [ "$#" -lt 3 ]
then
	echo "Usage:"
	echo -e "\t$0 KERNEL_SOURCE SAILFISH_OS_VERSION ACTUAL_JOLLA_KERNEL_VERSION [MODULE_SYMVERS]"
	echo
	echo "Example:"
	echo -e "\t$0 sailfishos_kernel_jolla_msm8930-1.1.1.27.tar.gz 1.1.1.27 3.4.98.20141031.3"
	echo
	echo "Use 'uname -r' to find out actual kernel version for currently installed Sailfish OS version"
	echo "Sailfish OS version is shown in terminal MOTD and in Settings->System->About product"
	echo "Make sure that kernel sources match Sailfish OS version"
	echo "If you have Module.symvers file for the current OS version - specify it's path in the last parameter"
	exit 1
fi

if [ ! -f "usbip-kernel-modules.spec" ]
then
	echo "usbip-kernel-modules.spec not found! (should be in the same directory as this script)"
	exit 1
fi

VER_OS=$2
VER=$3
KRN_PTH=$1
MDL=$4

VER_ARR=( ${VER//./ } )
VER_CNT=${#VER_ARR[@]}

if [ $VER_CNT -le 3 ]
then
	echo "ACTUAL_JOLLA_KERNEL_VERSION should be in the form of AA.BB.CC.XX"
	echo "Use 'uname -r' to find out actual kernel version"
	exit 1
fi

VER_MAJ=$( printf ".%s" "${VER_ARR[@]:0:3}" )
VER_MAJ=${VER_MAJ:1}
VER_LOC=$( printf ".%s" "${VER_ARR[@]:3}" )

if [ ! -f "$KRN_PTH" ]
then
	echo "KERNEL_SOURCE not found: '$KRN_PTH'"
	exit 1
fi

if ! file -bz $KRN_PTH | grep -q "tar archive.*compressed data"
then
	echo "KERNEL_SOURCE should be compressed tar archive!"
	exit 1
fi

if ! KRN_EXT=$( echo $KRN_PTH | egrep -o "\.t(ar\.)?[^\.]+$" )
then
	echo "Unknown KERNEL_SOURCE extension!"
	exit 1
fi

KRN=$( basename $KRN_PTH $KRN_EXT )

echo "Kernel sources are in $KRN$KRN_EXT"

if [ -z "$MDL" ]
then
	echo "Module.symvers is not present: full kernel rebuild required"
else
	if [ ! -f "$MDL" ]
	then
		echo "MODULE_SYMVERS not found: '$MDL'"
		exit 1
	elif [ $( basename $MDL ) != "Module.symvers" ]
	then
		echo "MODULE_SYMVERS file should be named 'Module.symvers'"
		exit 1
	fi
	echo "Module.symvers is present: will build only required modules"
fi

echo "Checking kernel sources version..."

VER_KRN=$( tar -xf $KRN_PTH --no-wildcards-match-slash */Makefile -O 2>/dev/null | gawk '{if (match($0, /^VERSION[[:space:]]*=[[:space:]]*(.*)/, arr)) v1=arr[1]; else if (match($0, /^PATCHLEVEL[[:space:]]*=[[:space:]]*(.*)/, arr)) v2=arr[1]; else if (match($0, /^SUBLEVEL[[:space:]]*=[[:space:]]*(.*)/, arr)) v3=arr[1]}END{if (v1=="" || v2=="" || v3=="") print "?"; else print v1"."v2"."v3}' )

if [ "$VER_KRN" == "?" ]
then
	echo "$KRN$KRN_EXT doesn't contain valid Linux kernel sources!"
	exit 1
elif [ "$VER_KRN" != "$VER_MAJ" ]
then
	echo "ACTUAL_JOLLA_KERNEL_VERSION ($VER_MAJ) doesn't match kernel sources ($VER_KRN)"
	echo "Make sure that kernel sources match Sailfish OS version"
	exit 1
fi

echo "Kernel version is $VER_MAJ$VER_LOC"
echo "Building USB/IP kernel modules for Sailfish OS $VER_OS..."
echo "Creating directory structure for rpmbuild..."

for DIR in "SOURCES" "SRPMS" "RPMS" "BUILDROOT" "BUILD"
do
	[ ! -e $DIR ] && mkdir $DIR
done

if [ ! -f "SOURCES/$KRN$KRN_EXT" ]
then
	cp $KRN_PTH SOURCES
fi

if [ -z "$MDL" ]
then
	MDL="no_mdl"
else
	tar -cf SOURCES/Module.symvers.tar -C $( dirname $MDL ) Module.symvers
	MDL="mdl"
fi

echo "Running rpmbuild for target SailfishOS-armv7hl..."

sb2 -t SailfishOS-armv7hl -m sdk-build rpmbuild -D "_topdir $PWD" -D "$MDL 1" -D "ver_os $VER_OS" -D "ver_maj $VER_MAJ" -D "ver_loc $VER_LOC" -D "krn $KRN" -D "krn_ext $KRN_EXT" -bb usbip-kernel-modules.spec
