#!/bin/sh

if [ -d "Postman" ]; then
	echo "Removing old 'Postman/'"
	rm -rf "Postman/"
fi

postmanTarball=$(curl --head -s "https://dl.pstmn.io/download/latest/linux64" | grep -o "Postman.*.gz")
curl -s -L -C- https://dl.pstmn.io/download/latest/linux64 -o ${postmanTarball}
echo "Extracting Postman tarball ${postmanTarball}"
tar -xf ${postmanTarball} || ( echo "Failed to extract Postman tarball" && exit )

versionMaj=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $1 }')
versionMin=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $2 }')
versionRev=$(echo ${postmanTarball} | awk -F '-' '{ print $4 }' | awk -F '.' '{ print $3 }')
version="${versionMaj}.${versionMin}.${versionRev}"

echo "Postman V${version}"
packageName="postman-${version}"
echo "${version}" > ./version.txt

if [ -d "${packageName}" ]; then
	echo "Removing old '${packageName}/'"
	rm -rf "${packageName}/"
fi

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

echo "Building '${packageName}.deb'"
dpkg-deb -b "${packageName}" > /dev/null

if [ $? -gt 0 ]; then
	echo "Failed to build '${packageName}.deb'"
	exit
fi

version=$(echo ${postmanTarball} | awk -NF- '{print $4}' | awk -NF. '{printf "%s.%s.%s",$1,$2,$3}')

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

curl -i -XPOST -H "Authorization: token ${GITHUB_TOKEN}" --data @release_body.json https://api.github.com/repos/comdotlinux/postman/releases 2>&1 | tee /tmp/release

location=$(grep Location: /tmp/release | awk '{print $2}')
echo "Release : ${location}"

release_id=$(basename ${location})
echo "Release ID : ${release_id}"

curl -i -XPOST -H "Authorization: token ${GITHUB_TOKEN}" -H 'Content-Type: application/vnd.debian.binary-package' --data @${packageName}.deb https://uploads.github.com/repos/comdotlinux/postman/releases/${release_id}/assets?name=${packageName}.deb
