Name:		usbip-kernel-modules
Version:	%{ver_os}
Release:	1.jolla
Summary:	USB/IP kernel modules for Sailfish OS %{version}
License:	GPLv2+
Group:		System Environment/Kernel
Source0:	%{krn}%{krn_ext}
%if %{defined mdl}
Source1:	Module.symvers.tar
%endif
Prefix:		/lib/modules/%{ver_maj}%{ver_loc}
Provides:	kmod(usbip-core.ko)
Provides:	kmod(usbip-host.ko)
Provides:	kmod(vhci-hcd.ko)

%description
USB/IP Project aims to develop a general USB device sharing system over IP
network. To share USB devices between computers with their full functionality,
USB/IP encapsulates "USB I/O messages" into TCP/IP payloads and transmits them
between computers.

This package contains only USB/IP kernel modules. You'll need to install
userspace applications separately.

%define debug_package %{nil}
%define _unpackaged_files_terminate_build 0 

%prep
%if %{defined mdl}
%setup -q -n %{krn} -a 1
%else
%setup -q -n %{krn}
%endif

%build
make sbj_defconfig
echo CONFIG_USBIP_CORE=m >> .config
echo CONFIG_USBIP_VHCI_HCD=m >> .config
echo CONFIG_USBIP_HOST=m >> .config
echo CONFIG_USBIP_DEBUG=n >> .config
sed -i s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"%{ver_loc}\"/g .config
%if %{defined mdl}
make modules_prepare
%else
make vmlinux
%endif
make M=drivers/staging/usbip

%install
make M=drivers/staging/usbip modules_install INSTALL_MOD_PATH=%{buildroot}
chmod u+x %{buildroot}/lib/modules/*/extra/*

%files
%defattr(644,root,root,755)
/lib/modules/*/extra/*

%post -p /sbin/depmod
%postun -p /sbin/depmod
