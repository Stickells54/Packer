# Packer
Collection of scripts and configs for deploying Windows images
You will need to add your own provisioning scripts and adjust them accordingly in the HCL file creation portions of the script.

I put the pvscsi drivers in the ./scripts/drivers directory (local to packer.exe). That is where the autounattend files will look for the drivers.
VMware tools ISO is assumed to be in the default location on the ESXi host.

# Usage
Change the hashtable in DeployPacker.ps1 to fit your needs. Place the files and folders in C:\Packer along with Packer.exe
You will need to make sure you change the provisioning sections of the HCL files to match your provisioning scripts.
Also, you could replace the powershell provisioners with Ansible, Chef, etc. 
