#!/bin/bash -x

if [[ -d "Postman" ]]; then
	echo "Removing old 'Postman/'"
	rm -rf "Postman/"
fi

postmanTarball=$(curl --head -s "https://dl.pstmn.io/download/latest/linux64" | grep -o "Postman.*.gz")

versionMaj=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $1 }')
versionMin=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $2 }')
versionRev=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $3 }')
version="${versionMaj}.${versionMin}.${versionRev}"

echo "Postman V${version}"

curl -s --fail -L https://api.github.com/repos/comdotlinux/postman/releases/tags/v${version}
if [[ $? -eq 0 ]] ; then
	echo "Release v${version}" exists. Not running.
	exit 0
fi

packageName="postman-${version}"
echo "${version}" > ./version.txt

if [[ -d "${packageName}" ]]; then
	echo "Removing old '${packageName}/'"
	rm -rf "${packageName}/"
fi

echo "Downloading the tarball ${postmanTarball} "

curl -s -L -C- https://dl.pstmn.io/download/latest/linux64 -o ${postmanTarball}

echo "Extracting Postman tarball ${postmanTarball}"
tar -xf ${postmanTarball} || ( echo "Failed to extract Postman tarball" && exit )

echo "Creating ${packageName} folder structure and files"
mkdir -pv "${packageName}"
mkdir -pv "${packageName}/usr/share/applications"
touch "${packageName}/usr/share/applications/Postman.desktop"

mkdir -pv "${packageName}/usr/share/icons/hicolor/128x128/apps"
mkdir -pv "${packageName}/opt/postman"
mkdir -pv "${packageName}/DEBIAN"
touch "${packageName}/DEBIAN/control" "${packageName}/DEBIAN/postinst" "${packageName}/DEBIAN/prerm"

echo "Copying files"
cp -v "Postman/app/resources/app/assets/icon.png" "${packageName}/usr/share/icons/hicolor/128x128/apps/postman.png"
cp -Rv "Postman/"* "${packageName}/opt/postman/"

echo "Creating desktop file"
tee ${packageName}/usr/share/applications/Postman.desktop << END
[Desktop Entry]
Type=Application
Name=Postman
GenericName=Postman API Tester
Icon=postman
Exec=postman
Path=/opt/postman
Categories=Development;
END

tee ${packageName}/DEBIAN/control << END
Package: Postman
Version: ${version}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: You
Description: Postman API something
END

tee ${packageName}/DEBIAN/postinst << END
if [ -f /usr/bin/postman ]; then
	sudo rm -fv /usr/bin/postman
fi
sudo ln -sv /opt/postman/Postman /usr/bin/postman
END


tee ${packageName}/DEBIAN/prerm << END
if [ -f /usr/bin/postman ]; then
	sudo rm -fv /usr/bin/postman
fi
END


echo "Setting modes"
chmod 0775 "${packageName}/usr/share/applications/Postman.desktop"
chmod 0775 "${packageName}/DEBIAN/control"
chmod 0775 "${packageName}/DEBIAN/postinst"
chmod 0775 "${packageName}/DEBIAN/prerm"

debName="${packageName}.deb"

echo "Validating modes"
nc=""
if [[ $(stat -c "%a" "${packageName}/DEBIAN/control") != "775" ]]; then
	echo "File modes are invalid, calling 'dpkg-deb' with '--nocheck'"
	nc="--nocheck"
else
	echo "File modes are valid"
fi
echo "Building '${packageName}.deb'"
dpkg-deb $nc -b "${packageName}" > /dev/null

ls -ltra

if [[ $? -gt 0 ]]; then
	echo "Failed to build '${packageName}.deb'"
	exit
fi

echo "--"
zip ${packageName}.zip ${packageName}.deb

mkdir ${version}
mv -v ${packageName}.deb ${version}
echo "::set-env name=PACKAGE_DIR::${version}"
echo "::set-env name=PACKAGE_ZIP::${version}/${packageName}.zip"
echo "::set-env name=PACKAGE_VERSION::v${version}"
echo "::set-env name=RELEASE_INFO::Created from ${postmanTarball}"

echo "--"
