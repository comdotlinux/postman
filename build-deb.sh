#!/bin/bash

if [ -d "Postman" ]; then
	echo "Removing old 'Postman/'"
	rm -rf "Postman/"
fi

postmanTarball=$(curl --head -s "https://dl.pstmn.io/download/latest/linux64" | grep -o "Postman.*.gz")

versionMaj=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $1 }')
versionMin=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $2 }')
versionRev=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $3 }')
version="${versionMaj}.${versionMin}.${versionRev}"

echo "Postman V${version}"

curl -i --fail -L https://api.github.com/repos/comdotlinux/postman/releases/tags/v${version}
if [ $? -eq 0 ] ; then
	echo "Release v${version}" exists. Not running.
	exit 0
fi

packageName="postman-${version}"
echo "${version}" > ./version.txt

if [ -d "${packageName}" ]; then
	echo "Removing old '${packageName}/'"
	rm -rf "${packageName}/"
fi

echo "Downloading the tarball."

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
cp "Postman/app/resources/app/assets/icon.png" "${packageName}/usr/share/icons/hicolor/128x128/apps/postman.png"
cp -R "Postman/"* "${packageName}/opt/postman/"

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
	sudo rm -f /usr/bin/postman
fi
sudo ln -s /opt/postman/Postman /usr/bin/postman
END


tee ${packageName}/DEBIAN/prerm << END
if [ -f /usr/bin/postman ]; then
	sudo rm -f /usr/bin/postman
fi
END


echo "Setting modes"
chmod 0775 "${packageName}/DEBIAN/postinst"
chmod 0775 "${packageName}/DEBIAN/prerm"

debName="${packageName}.deb"
echo "Building '${debName}'"
dpkg-deb -b "${packageName}" > /dev/null

ls -ltra

if [ $? -gt 0 ]; then
	echo "Failed to build '${debName}'"
	exit
fi

tee release_body.json << END
{
  "tag_name": "v${version}",
  "target_commitish": "master",
  "name": "v${version}",
  "body": "Postman Debian Package for x86_64 Linux built on Ubuntu",
  "draft": false,
  "prerelease": false
}
END

curl --fail -i -XPOST -H "Authorization: token ${GITHUB_TOKEN}" --data @release_body.json https://api.github.com/repos/comdotlinux/postman/releases 2>&1 | tee /tmp/release
[ $? -ne 0 ] && echo "Failed to create release" && exit 1
location=$(grep Location: /tmp/release | awk '{print $2}')
echo "Release : ${location}"

release_id=$(basename ${location})
echo "Release ID : ${release_id}"

[ -z release_id ] && echo "Failed to get release id" && exit 3
curl --fail -i -XPOST -H "Authorization: token ${GITHUB_TOKEN}" -H 'Content-Type: application/octet-stream' --data @${debName} https://uploads.github.com/repos/comdotlinux/postman/releases/${release_id}/assets?name=${debName}
[ $? -ne 0 ] && echo "Failed to create release asset" && exit 4
