#!/bin/bash

PROJECT_LOCATION=~/projects/basic-initrd-creator

INITRD_FILE_NAME=ramdisk.img

if [ -s "${INITRD_FILE_NAME}.gz" ]; then
    if [ -s "${INITRD_FILE_NAME}.gz.bak" ]; then
        rm -vrf "${INITRD_FILE_NAME}.gz.bak"
    fi
    
    mv -v "${INITRD_FILE_NAME}.gz" "${INITRD_FILE_NAME}.gz.bak"
fi


if [ -s "${PROJECT_LOCATION}/busybox" ]; then 
    # Ramdisk Constants
    RDSIZE=4000
    BLKSIZE=1024

    # Create an empty ramdisk image
    dd if=/dev/zero of=ramdisk.img bs=$BLKSIZE count=$RDSIZE

    # Make it an ext2 mountable file system
    /sbin/mke2fs -t ext4 -F -m 0 -b $BLKSIZE ramdisk.img $RDSIZE
    
    if ! [ -d "/mnt/initrd" ]; then
        sudo mkdir -p /mnt/initrd
    fi
    
    # Mount it so that we can populate
    sudo mount ramdisk.img /mnt/initrd -t ext4 -o loop=/dev/loop0
    
    cd /mnt/initrd
    
    # Populate the filesystem (subdirectories)
    mkdir bin
    mkdir sys
    mkdir dev
    mkdir proc

    # Grab busybox and create the symbolic links
    cd bin
    
    cp "${PROJECT_LOCATION}/busybox" .
    
    chmod +x busybox
    
    ln -s busybox sh
    ln -s busybox mount
    ln -s busybox echo
    ln -s busybox ls
    ln -s busybox cat
    ln -s busybox ps
    ln -s busybox dmesg
    ln -s busybox sysctl

    cd ..
    
    cd dev

    # Grab the necessary dev files
    cp -a /dev/console .
    #cp -a /dev/ramdisk .
    #cp -a /dev/ram0 .
    cp -a /dev/null .
    cp -a /dev/tty1 .
    cp -a /dev/tty2 .

    cd ..
    
    ln -s bin sbin

    # Create the init file
    cat >> linuxrc << EOF
#!/bin/ash
echo
echo "Simple initrd is active"
echo
mount -t proc /proc /proc
mount -t sysfs none /sys
/bin/ash --login
EOF

    chmod +x linuxrc
    
    cp linuxrc init
    
    cd $PROJECT_LOCATION
    
    # Finish up...
    sudo umount /mnt/initrd
    
    rmdir /mnt/initrd
    
    file $INITRD_FILE_NAME
    
    gzip -9 $INITRD_FILE_NAME
    
    echo "Initrd file creation was Done!"
    echo "File details:"
    
    ls -l $INITRD_FILE_NAME.gz    
else
    echo "ERROR! the 'busybox' binary was not found and it must be available to continue!"
    echo "Aborting ..."
    
    exit 1
fi
