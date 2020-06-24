Advanced partitioning with LUKS full disk encryption
----------------------------------------------------

This was adapted from [an answer on AskUbuntu](https://askubuntu.com/questions/293028/how-can-i-install-ubuntu-encrypted-with-luks-with-dual-boot).

1. Install `pv`:

    ```bash
    apt install pv
    ```

2. Using GParted, create the partitions that will not be encrypted,
	such as the `/boot` partition (e.g. an EXT4 partition with about
	1 GB). We will refer to this partition as `/dev/sdaY`, and it is **not**
  the "EFI system partition".

3. Still on GParted, create a single unformatted partition for the
    encrypted volume which will later contain all of the encrypted
    partitions. That partition will be referred to as `/dev/sdaX`.

4. If necessary, write "random" data to `/dev/sdaX`. This can be done
     by encrypting null data with any password:

     ```bash
     cryptsetup luksFormat /dev/sdaX --verify-passphrase
     cryptsetup luksOpen /dev/sdaX AnyName
     # when prompted, choose any password
     sh -c 'exec pv -tprebB 16m /dev/zero >"$1"' _ /dev/mapper/AnyName
     cryptsetup luksClose AnyName
	 ```

5. Create a LUKS container and open it:

     ```bash
     cryptsetup luksFormat /dev/sdaX --verify-passphrase
     cryptsetup luksOpen /dev/sdaX AnyName
     ```
    Choose a good name to replace `AnyName`, because it will be shown
    when the system boots and asks for the password.

6. Create an LVM physical volume and a volume group in the container.

      ```bash
      lvm pvcreate /dev/mapper/AnyName
      vgcreate VolName /dev/mapper/AnyName
      ```

7. Create the logical volumes for the partitions, running the
      following command for each one:

      ```bash
      lvcreate -n <PartName> -L <size> VolName
      ```

      In the last partition, instead of `-L <size>`, we can use `-l
	  100%FREE` to use the remaining space.

      A complete example:

      ```bash
      lvcreate -n RootPart -L 300G VolName
      lvcreate -n HomePart -L 400G VolName
      lvcreate -n SwapPart -L   8G VolName
      ```

8. For each partition, create the corresponding file system with
     `mkfs.ext4` (or another equivalent utility for other file systems),
     and use `mkswap` for the swap partition, as in the example:

     ```bash
      mkfs.ext4 /dev/mapper/VolName-RootPart
      mkfs.ext4 /dev/mapper/VolName-HomePart
      mkswap    /dev/mapper/VolName-SwapPart
      ```

9. Install the operating system using the graphical interface as usual.
    Choose "something else" rather than "erase disk".

    The "device for the bootloader installation" should
    be set to the existing EFI FAT16/FAT32 small partition for UEFI mode,
    or the hard disk itself (e.g. `/dev/sda`) for BIOS mode. It is **not**
    the `/dev/sdaY` partition, which is mounted as `/boot`.

    Make sure to fill in the correct type and mount point for each encrypted
    partition and for the boot partition, and as in this example:

+--------------------------------+------------------+-------------+
| Device                         | Use as           | Mount point |
+===============================:+:================:+:============+
| `/dev/mapper/VolName-RootPart` | Ext4 file system | `/`         |
+--------------------------------+------------------+-------------+
| `/dev/mapper/VolName-HomePart` | Ext4 file system | `/home`     |
+--------------------------------+------------------+-------------+
| `/dev/sdaY`                    | Ext4 file system | `/boot`     |
+--------------------------------+------------------+-------------+
| `/dev/mapper/VolName-SwapPart` | Swap area        | (none)      |
+--------------------------------+------------------+-------------+


10. After the installation, **do not reboot** and choose
    "continue testing".

11. Get the UUID of the encrypted container (we will need it later):

    ```bash
    blkid -s UUID /dev/sdaX
    ```

12. Mount the devices in `/mnt`:

    ```bash
    mount /dev/mapper/VolName-RootPart /mnt
	mount /dev/sdaY /mnt/boot
	mount --bind /dev /mnt/dev
	```

13. Use `chroot` into `/mnt` and mount `/proc`, `/sys` and `/dev/pts`:

    ```bash
	chroot /mnt
	mount -t proc proc /proc
    mount -t sysfs sys /sys
    mount -t devpts devpts /dev/pts
    ```

14. Still in the `chroot`ed environment, create the file `/etc/crypttab`:

    ```bash
    echo 'AnyName UUID=𝒕𝒉𝒆-𝒖𝒖𝒊𝒅-𝒈𝒐𝒆𝒔-𝒉𝒆𝒓𝒆-𝒘𝒊𝒕𝒉𝒐𝒖𝒕-𝒒𝒖𝒐𝒕𝒆𝒔 none luks,discard' > /etc/crypttab
    ```

15. Run the following commands (still in the `chroot`ed environment):

    ```bash
    update-initramfs -k all -c
    update-grub
    ```

16. Reboot. 
