# Packer
Collection of scripts and configs for deploying Windows images
You will need to add your own provisioning scripts and adjust them accordingly in the HCL file creation portions of the script.

I put the pvscsi drivers in the ./scripts/drivers directory (local to packer.exe). That is where the autounattend files will look for the drivers.
VMware tools ISO is assumed to be in the default location on the ESXi host.
