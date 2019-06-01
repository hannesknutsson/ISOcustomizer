#!/bin/bash

#Commands stolen from https://help.ubuntu.com/community/LiveCDCustomization
#I have made my own comments here that differ a slight bit just so that I can understand what's goning on in my own words or whatever :)

#Temporary folder location where we will do all of the work
TEMPDIR=customiso

#The script to be used when modifying the ISO
INSCRIPT=$1

if [ `echo $#` -eq 0 ] || [ `cat $INSCRIPT 2>/dev/null | wc -c` -eq 0 ] 
then
	echo -e "Could not find the file '$INSCRIPT' in the working directory.\nThis file should be a script containing the customizations to be made to the ISO you are attempting to modify.\n\nProvide a input file and try again :)\n\nExiting..."
	exit
else
	echo -e "Welcome to this extremely simple script that you somehow found on the wild internet!\n\nYou just passed the first and only sanity check, which in english means: we found your input file, wohoo!\nSadly, this is the only sanity check so far in this script. You may encounter some errors when running this shitty script, so be prepared to read the error messages that occur. The script is full of pretty messages that should make it easy for you to debug the output data to resolve potential errors."
fi

echo -e "\n"

#Copy contents from Download-dir to new dir where we may customize it however much we like
echo -e "\tMoving iso to a temporary location: $TEMPDIR"
mkdir $TEMPDIR
cp -v ~/Downloads/ubuntu-18.04.2-desktop-amd64.iso $TEMPDIR
echo -e "\tDone\n"

#Make a new directory and mount the .iso to it
echo -e "\tMounting ISO to $TEMPDIR/mnt"
mkdir $TEMPDIR/mnt
sudo mount -o loop $TEMPDIR/ubuntu-18.04.2-desktop-amd64.iso $TEMPDIR/mnt
echo -e "\tDone\n"

#Make one more directory for the extracted .iso
echo -e "\tExtracting iso to $TEMPDIR/extract-cd"
mkdir $TEMPDIR/extract-cd
sudo rsync --exclude=/casper/filesystem.squashfs -a $TEMPDIR/mnt/ $TEMPDIR/extract-cd
echo -e "\tDone\n"

#Make yet another directory for the extracted squashFS filesystem
echo -e "\tUnsquashing squashFS filesystem"
sudo unsquashfs -d $TEMPDIR/edit $TEMPDIR/mnt/casper/filesystem.squashfs
echo -e "\tDone\n"

#Move necesary files into squashfs and mount /run so we can reach the internet
echo -e "\tEnabling network connectivity"
sudo cp /etc/resolv.conf $TEMPDIR/edit/etc/
sudo mount -o bind /run/ $TEMPDIR/edit/run
echo -e "\tDone\n"

#Mount system-important directories and prepare to chroot
echo -e "\tMounting system-directories and preparing for chrooting"
sudo mount --bind /dev/ $TEMPDIR/edit/dev
echo -e "mount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devpts none /dev/ptsi\nexport HOME=/root" > $TEMPDIR/prescript
echo -e "rm -rf /tmp/* ~/.bash_history" > $TEMPDIR/postscript
mkdir $TEMPDIR/edit/removeme
cp $TEMPDIR/prescript $TEMPDIR/edit/removeme
cp $INSCRIPT $TEMPDIR/edit/removeme/userscript
cp $TEMPDIR/postscript $TEMPDIR/edit/removeme
chmod u+x $TEMPDIR/edit/removeme/prescript
chmod u+x $TEMPDIR/edit/removeme/userscript
chmod u+x $TEMPDIR/edit/removeme/postscript
echo -e "\tDone\n"

#Run scripts in chrooted environment
echo -e "\tRunning your customisations on the ISO"
sudo chroot $TEMPDIR/edit sudo bash ./removeme/prescript
sudo chroot $TEMPDIR/edit sudo bash ./removeme/userscript
sudo chroot $TEMPDIR/edit sudo bash ./removeme/postscript
echo -e "\tDone\n"

#Unmount mounted directories
echo -e "\tUnmounting mounted directories"
sudo umount $TEMPDIR/edit/run
sudo umount $TEMPDIR/edit/dev
sudo umount $TEMPDIR/edit/proc
sudo umount $TEMPDIR/edit/sys
sudo umount $TEMPDIR/mnt
echo -e "\tDone\n"

#Create manifest
echo -e "\tRegenerating manifest"
chmod +w $TEMPDIR/extract-cd/casper/filesystem.manifest
sudo chroot $TEMPDIR/edit dpkg-query -W --showformat='${Package} ${Version}\n' > $TEMPDIR/extract-cd/casper/filesystem.manifest
sudo cp $TEMPDIR/extract-cd/casper/filesystem.manifest $TEMPDIR/extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' $TEMPDIR/extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' $TEMPDIR/extract-cd/casper/filesystem.manifest-desktop
echo -e "\tDone\n"

#Compress filesystem
echo -e "\tCompressing filessystem"
#sudo rm $TEMPDIR/extract-cd/casper/filesystem.squashfs #This line seems useless since we exclude this file when copying earlier in the script :)
sudo mksquashfs $TEMPDIR/edit $TEMPDIR/extract-cd/casper/filesystem.squashfs
sudo printf $(du -sx --block-size=1 $TEMPDIR/edit | cut -f1) > $TEMPDIR/extract-cd/casper/filesystem.size
rm $TEMPDIR/extract-cd/md5sum.txt
find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee $TEMPDIR/extract-cd/md5sum.txt
echo -e "\tDone\n"

#Create new ISO
echo -e "\tCreating new ISO file"
sudo mkisofs -joliet-long -D -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o customISO.iso $TEMPDIR/extract-cd

echo -e "\tYou reached the end, this is rare and amazing :D"
