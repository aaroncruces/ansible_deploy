df -h

umount  /target/boot/efi
umount  /target
mount /dev/nvme0n1p2 /mnt
cd /mnt

mv @rootfs/ @
btrfs su cr @home
btrfs su cr @root
btrfs su cr @proxmox
btrfs su cr @opt
btrfs su cr @tmp
btrfs su cr @log
btrfs su cr @cache
btrfs su cr @snapshots
btrfs su cr @docker
btrfs su cr @libvirt
btrfs su cr @vz


mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@ /dev/nvme0n1p2 /target
mkdir -pv /target/boot/efi
mkdir -pv /target/home
mkdir -pv /target/root
mkdir -pv /target/proxmox
mkdir -pv /target/opt
mkdir -pv /target/tmp
mkdir -pv /target/var/log
mkdir -pv /target/var/cache
mkdir -pv /target/.snapshots
mkdir -pv /target/var/lib/docker
mkdir -pv /target/var/lib/libvirt
mkdir -pv /target/var/lib/vz
mkdir -pv /target/btrfsroot



umount /target/boot/efi
umount /target/home
umount /target/root
umount /target/proxmox
umount /target/opt
umount /target/tmp
umount /target/var/log
umount /target/var/cache
umount /target/.snapshots
umount /target/var/lib/docker
umount /target/var/lib/libvirt
umount /target/var/lib/vz
umount /target/btrfsroot

# rm -rv /target/boot
# mkdir -pv /target/boot
# mount /dev/nvme0n1p2 /target/boot
# mkdir -pv /target/boot/efi
# mount /dev/nvme0n1p1 /target/boot/efi

mount -o defaults,subvolid=5                                                              /dev/nvme0n1p2 /target/btrfsroot
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@home      /dev/nvme0n1p2 /target/home
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@root      /dev/nvme0n1p2 /target/root
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@proxmox   /dev/nvme0n1p2 /target/proxmox
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@opt       /dev/nvme0n1p2 /target/opt
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@tmp       /dev/nvme0n1p2 /target/tmp
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@log       /dev/nvme0n1p2 /target/var/log
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@cache     /dev/nvme0n1p2 /target/var/cache
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@snapshots /dev/nvme0n1p2 /target/.snapshots
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@docker    /dev/nvme0n1p2 /target/var/lib/docker
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@libvirt   /dev/nvme0n1p2 /target/var/lib/libvirt
mount -o defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@vz        /dev/nvme0n1p2 /target/var/lib/vz
mount /dev/nvme0n1p1 /target/boot/efi


nano /target/etc/fstab

#
#
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /                   btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@           0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /btrfsroot          btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvolid=5         0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /home               btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@home       0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /root               btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@root       0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /proxmox            btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@proxmox    0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /opt                btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@opt        0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /tmp                btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@tmp        0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /var/log            btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@log        0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /var/cache          btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@cache      0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /.snapshots         btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@snapshots  0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /var/lib/docker     btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@docker     0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /var/lib/libvirt    btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@libvirt    0  0
UUID=d02c8878-0cdb-4edf-9111-8388f24f79f5   /var/lib/vz         btrfs  defaults,noatime,discard=async,space_cache=v2,ssd,compress=lzo,subvol=@vz         0  0
#
#
