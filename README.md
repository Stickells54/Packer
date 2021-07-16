# Packer
Collection of scripts and configs for deploying Windows images
You will need to add your own provisioning scripts and adjust them accordingly in the HCL file creation portions of the script.

I put the pvscsi drivers in the ./scripts/drivers directory (local to packer.exe). That is where the autounattend files will look for the drivers.
VMware tools ISO is assumed to be in the default location on the ESXi host.

# Usage
Change the hashtable in DeployPacker.ps1 to fit your needs. Place the files and folders in C:\Packer along with Packer.exe
You will need to make sure you change the provisioning sections of the HCL files to match your provisioning scripts.
Also, you could replace the powershell provisioners with Ansible, Chef, etc. 

# Paramaters
A list of parameters available in Packer.ps1. This list is also in the file itself. 

> ISODatastore

  Datastore name that constains the needed Windows ISO
	
> ISOPath
	
  Absolute path to the ISO. Example: If ISO lives in the ISO Folder on the ISODatasore, your ISO Path would be /ISO/Windows.iso. Must end with the .ISO file itself.
	
> VMCPU
	
  The number of vCPUs assigned to a VM

> VMDiskMB

  Size in MB of the HDD attached to the VM

> VMMemoryMB

  Size in MB of how much memory to assign the VM

> vCenterServerCluster

Name of the CLUSTER the VM will be deployed to

> vCenterServerDataCenter

  Name of the DATACENTER the VM will be deployed to

> VMDataStore

  Name of the Datastore that the VM itself will live on. Usually separate from the datastore that ISO files are stored on

> vCenterServerFolder

  The folder that will nest the VM in vCenter

> VMPortGroup

  Name of the PortGroup that the VM will connect to

> vCenterServer

  IP or FQDN of the VCSA that will provision the VM

> WinRMPass

  Password of the local admin account created in the autounattend.xml. Used to establish WinRM connection to the VM

> WinRMUser

  Username of the local admin account created in the autounattend.xml. Used to establish WinRM connection to the VM

> AdminID

  vCenter Admin Username

> AdminPass

  vCenter Admin Password

> VMName

  Name of the VM that will be created.

> DeploymentType

  Tells the script what to do with the VM post deployment. 
	
    HorizonIC = Take a snaphot of the VM and push to the $PoolName
	 
    HorizonStatic = Same as HorizonIC but it calls a differnet provisioning script that does not install the IC agent
	 
    Standard = Does nothing after VM creation aside from power down (normal Packer behavior)
	 
    Template = Convert the VM into a template. 

> SnapshotName

  What to name the snapshot that is taken and then pushed to the Horizon pool. Only used if DeploymentType is HorizonIC or HorizonStatic

> HVSERVER
  
  The Horizon URL that is used to connect to and push the image to a pool.

> PoolName

  Name of the Horizon Pool to push the image to. Only used if DeploymentType is HorizonIC or HorizonStatic

> WinVersion

  Determines either the Enterprise or Pro autounattend file to install windows. 
