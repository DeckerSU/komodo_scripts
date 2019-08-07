## Creating a VM for notarizing 3rd party on a Headless Server

Use this guide on your own risk!

### Installing Virtual Box

- https://www.virtualbox.org/wiki/Linux_Downloads

For Ubuntu 16.04:

```
sudo nano /etc/apt/sources.list
# add the following line at the end without initial #
# deb https://download.virtualbox.org/virtualbox/debian xenial contrib
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
sudo apt-get update
sudo apt install virtualbox-5.2
# add your username to vboxusers group (decker in this example)
sudo usermod -aG vboxusers decker
# check virtualbox kernel modules
sudo systemctl status vboxdrv
# download and install latest (!) extension pack
wget https://download.virtualbox.org/virtualbox/5.2.32/Oracle_VM_VirtualBox_Extension_Pack-5.2.32.vbox-extpack
sudo VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-5.2.32.vbox-extpack
```

### Creating a VM

1. SSH to your server with installed on previous step Virtual Box.
2. Create a VM following next guide:
```
cd $HOME
wget http://releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso
# VBoxManage list ostypes # to get a complete list of supported operating systems
VBoxManage createvm --name "Ubuntu_3rdparty" --ostype Ubuntu_64 --register
VBoxManage modifyvm "Ubuntu_3rdparty" --memory 16384 --cpus 4 --vram 16 --boot1 dvd --nic1 nat
# create IDE & SATA controllers
VBoxManage storagectl "Ubuntu_3rdparty" --name "IDE Controller" --add ide --controller PIIX4
VBoxManage storagectl "Ubuntu_3rdparty" --name "SATA Controller" --add sata --portcount 1
# create & attach disk drives
VBoxManage createhd --filename "Ubuntu_3rdparty.vdi" --size 250000 # 250 Gb Virtual HDD at $HOME directory
VBoxManage storageattach "Ubuntu_3rdparty" --storagectl "IDE Controller" --port 0 --device 1 --type dvddrive --medium "$HOME/ubuntu-18.04.2-live-server-amd64.iso"
VBoxManage storageattach "Ubuntu_3rdparty" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "Ubuntu_3rdparty.vdi"
# enable VRDP server
VBoxManage modifyvm "Ubuntu_3rdparty" --vrde on --vrdeport 5900 --vrdeaddress "127.0.0.1"
# disable audio
VBoxManage modifyvm "Ubuntu_3rdparty" --audio none --audioin off --audioout off
# start the virtual machine (in screen or tmux)
VBoxHeadless --startvm "Ubuntu_3rdparty"
```

3. Forward port from Virtual Box host server to your local PC:

```
ssh -L 5900:127.0.0.1:5900 <user@your_server_with_virtualbox>
rdesktop-vrdp 127.0.0.1:5900 # connect via RDP to VRDE or use Remmina or any other RDP client for that
```

4. Install Ubuntu standart way.

5. Stop the VM and turn off VRDE with:
```
VBoxManage controlvm "Ubuntu_3rdparty" poweroff
VBoxManage modifyvm "Ubuntu_3rdparty" --vrde off

```

6. Setup port forward from Host to Guest (bcz guest behind a VM NAT):

```
VBoxManage modifyvm "Ubuntu_3rdparty" --natpf1 "guestssh,tcp,,7722,,22" # natfp<nic number>
```

7. Start VM again (in screen or tmux)

```
VBoxHeadless --startvm "Ubuntu_3rdparty"
```

Connect to VM via SSH:
```
ssh <user@your_server_with_virtualbox> -p 7722
```

Don't forget to allow connection to VM from outside if you use ufw:

```
sudo ufw allow 7722/tcp comment 'vm ssh'
```

8. Setup 3rd party server in VM. Don't forget to port-forward needed ports from Host -> Guest (VM) machine same way as ssh port.

### Useful links

- https://www.virtualbox.org/manual/ch07.html - 7.1.3. Step by Step: Creating a Virtual Machine on a Headless Server
- https://www.virtualbox.org/manual/ch09.html#otherextpacks - 9.22. Other Extension Packs
- https://superuser.com/questions/322803/how-to-connect-to-virtualbox-remote-desktop-client-using-vnc
- https://forums.virtualbox.org/viewtopic.php?f=7&t=58560
- https://bugs.launchpad.net/ubuntu/+source/virtualbox/+bug/1822996
- https://superuser.com/questions/901422/virtualbox-command-line-setting-up-port-forwarding
- https://blog.regolit.com/2018/03/27/secure-virtualbox-vrde-connection
- https://eax.me/vboxmanage/
- https://www.ostechnix.com/install-oracle-virtualbox-ubuntu-16-04-headless-server/

### Useful commands

- `VBoxManage list vms` - list of VMs
- `VBoxManage list runningvms` - list of running VMs
- `VBoxManage controlvm "Ubuntu_3rdparty" acpipowerbutton` or `VBoxManage controlvm "Ubuntu_3rdparty" poweroff` - [safe](https://askubuntu.com/questions/42482/how-to-safely-shutdown-guest-os-in-virtualbox-using-command-line) stop VM
- `VBoxManage showvminfo "Ubuntu_3rdparty" --details` - show VM details

### Useful notes

- Oracle VM VirtualBox Extension Pack needed for support for USB 2.0 devices, **VirtualBox RDP** and PXE boot for Intel cards.

Switching between RDP and VNC:

```
# setting password for VRDE
# for RDP (in case of Oracle VM VirtualBox Extension Pack installed)
VBoxManage setproperty vrdeextpack "Oracle VM VirtualBox Extension Pack"
VBoxManage setproperty vrdeauthlibrary "VBoxAuthSimple"
VBoxManage internalcommands passwordhash "secret"
VBoxManage modifyvm "Ubuntu_3rdparty" --vrdeauthtype external
VBoxManage setextradata "Ubuntu_3rdparty" "VBoxAuthSimple/users/decker" "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b"
# for VNC
VBoxManage setproperty vrdeextpack VNC
VBoxManage modifyvm "Ubuntu_3rdparty" --vrdeproperty VNCPassword=secret
```

In case of VNC use `Remmina` to connect to your VRDE server. Note that you should setup 16 bit color depth in VNC connection properties, otherwise you will get `rfbProcessClientNormalMessage: ignoring unsupported encoding type ultraZip` error during connection.
