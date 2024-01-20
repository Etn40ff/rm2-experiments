#!/bin/sh

# The version of xochitl we will use to run our server
FIXED_VERSION="2.15.1.1189"

# get current os version
CURRENT_VERSION=`grep ^REMARKABLE_RELEASE_VERSION /usr/share/remarkable/update.conf | awk -F= '{print $2}'`

# setup dirs
WORKDIR=`mktemp -d`
cd $WORKDIR
mkdir bin
mkdir distfiles
mkdir mnt
mkdir lib-${CURRENT_VERSION}
mkdir lib-${FIXED_VERSION}

# Get a wget supporting SSL
wget -q http://toltec-dev.org/thirdparty/bin/wget-v1.21.1-1 --output-document bin/wget
chmod a+x bin/wget

# Get rm2fb
# TODO: add some logic here to download a client built for Qt5 or Qt6 depending
# on ${CURRENT_VERSION}
bin/wget -q https://github.com/ddvk/remarkable2-framebuffer/releases/download/v0.0.32/librm2fb_server.so.1.0.1 --output-document lib-${FIXED_VERSION}/librm2fb_server.so.1.0.1
bin/wget -q https://github.com/ddvk/remarkable2-framebuffer/releases/download/v0.0.32/librm2fb_client.so.1.0.1 --output-document lib-${CURRENT_VERSION}/librm2fb_client.so.1.0.1

# Get codexctl to download images
bin/wget -q http://people.disim.univaq.it/~salvatore.stella/tmp/codexctl --output-document bin/codexctl
chmod a+x bin/codexctl

# Get a copy of xochitl with the same version as the os but compiled for rm1
bin/codexctl --rm1 download --out distfiles/ ${CURRENT_VERSION}
bin/codexctl extract --out distfiles/${CURRENT_VERSION}.img distfiles/${CURRENT_VERSION}_reMarkable*.signed
mount -o loop distfiles/${CURRENT_VERSION}.img mnt
cp mnt/usr/bin/xochitl bin/xochitl-rm1-${CURRENT_VERSION}
umount mnt/
rm distfiles/${CURRENT_VERSION}.img distfiles/${CURRENT_VERSION}_reMarkable*.signed

# Get the version of xochit to use as server and all its dependencies not
# available on the system
bin/codexctl download --out distfiles/ ${FIXED_VERSION}
bin/codexctl extract --out distfiles/${FIXED_VERSION}.img distfiles/${FIXED_VERSION}_reMarkable2*.signed
mount -o loop distfiles/${FIXED_VERSION}.img mnt
cp mnt/usr/bin/xochitl bin/xochitl-rm2-${FIXED_VERSION}
for LIB in libdatachannel.so.0.17.1 libprotobuf.so.22 libqt-rappor.so.1 libQt5WebSockets.so.5 \
	libQt5DBus.so.5 libKF5Archive.so.5 libQt5Svg.so.5 libQt5Xml.so.5 libQt5Quick.so.5 \
	libQt5Qml.so.5 libQt5Network.so.5 libQt5Gui.so.5 libQt5Core.so.5 libssl.so.1.1 \
	libcrypto.so.1.1 libQt5QmlModels.so.5; do
	if [[ ! -f /usr/lib/${LIB} ]]; then
		cp mnt/usr/lib/${LIB} lib-${FIXED_VERSION}/${LIB}
	fi
done
umount mnt/
rm distfiles/${FIXED_VERSION}.img distfiles/${FIXED_VERSION}_reMarkable*.signed

# Convince rm2fb that we can run on this os version
cat > rm2fb.conf << EOF
!`cat /etc/version`
version str 2.15.1.1189
update addr 0x4e48fc
updateType str QRect
create addr 0x4e7520
shutdown addr 0x4e74b8
wait addr 0x4e64c0
getInstance addr 0x4db484
notify addr 0x4d98a4
EOF

# Stop the system's xochitl and launch ours
systemctl stop xochitl
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:lib-${FIXED_VERSION} LD_PRELOAD=lib-${FIXED_VERSION}/librm2fb_server.so.1.0.1 bin/xochitl-rm2-${FIXED_VERSION} &
# TODO: here we load also the libraries from ${FIXED_VERSION} because the client
# was compiled with Qt5. Remove this once we recompile it with Qt6
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:lib-${FIXED_VERSION} LD_PRELOAD=lib-${CURRENT_VERSION}/librm2fb_client.so.1.0.1 bin/xochitl-rm1-${CURRENT_VERSION}
