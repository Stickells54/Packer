<#	
	.NOTES
	===========================================================================
	 Created on:   	6/14/2021 
	 Created by:   	Travis Stickells
	 Filename:     	Packer.ps1
	===========================================================================
	.DESCRIPTION
	Deploy Windows images into different enviornments via Packer. 

	.Parameter ISODatastore
	Datastore name that constains the needed Windows ISO

	.Parameter ISOPath
	Absolute path to the ISO. Example: If ISO lives in the ISO Folder on the ISODatasore, your ISO Path would be /ISO/Windows.iso. Must end with the .ISO file itself.

	.PARAMETER VMCPU
	The number of vCPUs assigned to a VM

	.PARAMETER VMDiskMB
	Size in MB of the HDD attached to the VM

	.PARAMETER VMMemoryMB
	Size in MB of how much memory to assign the VM

	.PARAMETER vCenterServerCluster
	Name of the CLUSTER the VM will be deployed to

	.PARAMETER vCenterServerDataCenter
	Name of the DATACENTER the VM will be deployed to

	.PARAMETER VMDataStore
	Name of the Datastore that the VM itself will live on. Usually separate from the datastore that ISO files are stored on

	.PARAMETER vCenterServerFolder
	The folder that will nest the VM in vCenter

	.PARAMETER VMPortGroup
	Name of the PortGroup that the VM will connect to

	.PARAMETER vCenterServer
	IP or FQDN of the VCSA that will provision the VM

	.PARAMETER WinRMPass
	Password of the local admin account created in the autounattend.xml. Used to establish WinRM connection to the VM

	.PARAMETER WinRMUser
	Username of the local admin account created in the autounattend.xml. Used to establish WinRM connection to the VM

	.PARAMETER AdminID
	vCenter Admin Username

	.PARAMETER AdminPass
	vCenter Admin Password

	.PARAMETER VMName
	Name of the VM that will be created.

	.PARAMETER DeploymentType
	Tells the script what to do with the VM post deployment. 
		HorizonIC = Take a snaphot of the VM and push to the $PoolName
		HorizonStatic = Same as HorizonIC but it calls a differnet provisioning script that does not install the IC agent
		Standard = Does nothing after VM creation aside from power down (normal Packer behavior)
		Template = Convert the VM into a template. 

	.PARAMETER SnapshotName
	What to name the snapshot that is taken and then pushed to the Horizon pool. Only used if DeploymentType is HorizonIC or HorizonStatic

	.PARAMETER HVSERVER
	The Horizon URL that is used to connect to and push the image to a pool.

	.PARAMETER PoolName
	Name of the Horizon Pool to push the image to. Only used if DeploymentType is HorizonIC or HorizonStatic

	.PARAMETER WinVersion
	Determines either the Enterprise or Pro autounattend file to install windows. 

#>

param
(
	[parameter(Mandatory = $true)]
	$ISODatastore,
	[parameter(Mandatory = $true)]
	$ISOPath,
	[parameter(Mandatory = $true)]
	$VMCPU,
	[parameter(Mandatory = $true)]
	$VMDiskMB,
	[parameter(Mandatory = $true)]
	$VMMemoryMB,
	[parameter(Mandatory = $true)]
	$vCenterServerCluster,
	[parameter(Mandatory = $true)]
	$vCenterServerDataCenter,
	[parameter(Mandatory = $true)]
	$VMDataStore,
	[parameter(Mandatory = $true)]
	$vCenterServerFolder,
	[parameter(Mandatory = $true)]
	$VMPortGroup,
	[parameter(Mandatory = $true)]
	$vCenterServer,
	[parameter(Mandatory = $true)]
	$WinRMPAss,
	[parameter(Mandatory = $true)]
	$WinRMUser,
	$AdminID,
	$AdminPass,
	[parameter(Mandatory = $true)]
	$VMName,
	[parameter(Mandatory = $true)]
	[ValidateSet('HorizonIC', 'HorizonStatic', 'Standard', 'Template')]
	$DeploymentType,
	$SnapshotName,
	$PoolName,
	[parameter(Mandatory = $true)]
	[ValidateSet('Pro', 'Enterprise')]
	$WinVersion = 'Enterprise',
	[ValidateSet('Yes', 'No')]
	$SkipWU = 'Yes',
	$HVServer
	
)


Import-Module -Name VMware.VimAutomation.Core

# vCenter Cred Check
if (!$AdminID)
{
	$AdminID = Read-Host -Prompt "Enter your vCenter Admin ID: "
}
if (!$AdminPass)
{
	$AdminPassEncrypted = Read-Host -Prompt "Enter your vCenter Admin Password: " -AsSecureString
	$str = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassEncrypted)
	$AdminPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($str)
}

# Define Scipt Functions
function Deploy-HZIC
{
	Import-Module -Name VMware.Hv.Helper
	switch ($SkipWU)
	{
		'Yes' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/TeamsInstall.ps1"]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/ImageSetup.ps1"]
  }

  provisioner "windows-restart" {
  }  
}
"@
		}
		'No' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }
  
  provisioner "powershell"{
	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }
  
  provisioner "windows-restart" {
	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }


  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/TeamsInstall.ps1"]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/ImageSetup.ps1"]
  }

  provisioner "windows-restart" {
  }  
}
"@
		}
		
	}
	
	$hclFILE | Out-File C:\Temp\$VMName.pkr.hcl -Encoding utf8
	
	CD C:\Packer
	.\packer.exe build C:\Temp\$VMName.pkr.hcl
	
	
	
	#Connect to vcenter and set display settings for VM, shut it down, and taken a snapshot
	Write-Host "Connecting to $vCenterServer" -ForegroundColor Green -BackgroundColor Black
	Connect-VIServer -Server $vCenterServer -User $AdminID -Password $AdminPass | Out-Null
	Write-Host "Connected.. Setting display settings..." -ForegroundColor Green -BackgroundColor Black
	$VM = Get-VM -Name $VMName
	$VideoAdapter = $vm.ExtensionData.Config.Hardware.Device | where { $_.GetType().Name -eq "VirtualMachineVideoCard" }
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$Config = New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Config.device = $VideoAdapter
	$Config.device.numDisplays = 3
	$Config.operation = "edit"
	$spec.deviceChange += $Config
	$VMView = $vm | Get-View
	$VMView.ReconfigVM($spec)
	Write-Host "Taking Snapshot..." -ForegroundColor Green -BackgroundColor Black
	New-Snapshot -VM $VMName -Name "$SnapshotName" -Description "Snapshot created during inital build of VM via Packer\PowerCLI" | Out-Null
	
	#Push to a Horizon Pool
	Write-Host "Connecting to Horizon..." -ForegroundColor Green -BackgroundColor Black
	Connect-HVServer -Server $HVServer -Username $AdminID -Password $AdminPass -Domain $env:USERDOMAIN | Out-Null
	Write-Host "Pushing $VMName/$SnapshotName to $PoolName" -ForegroundColor Green -BackgroundColor Black
	Start-HVPool -Pool $PoolName -SchedulePushImage -LogoffSetting FORCE_LOGOFF -ParentVM $VMName -SnapshotVM $SnapshotName -Vcenter $vCenterServer | Out-Null
	Write-Host "Updating Status every 60 seconds..." -ForegroundColor Green -BackgroundColor Black
	do
	{
		$ImageProgress = (Get-HVPool -PoolName $PoolName).AutomatedDesktopData.ProvisioningStatusData.InstantCloneProvisioningStatusData.PendingImageProgress
		Write-Host "Progress: $ImageProgress %"
		Start-Sleep 60
	}
	Until ($ImageProgress -eq $null)
	Write-Host "CLeaning up..." -ForegroundColor Green -BackgroundColor Black
	Remove-Item -Path C:\Temp\$VMName.pkr.hcl
	Start-Sleep 5
	Write-Host "Image Deployed!" -ForegroundColor Green -BackgroundColor Black
	Write-Host "               " -BackgroundColor Black
	Read-Host -Prompt "Press enter key to exit..."
	Exit 0
}
function Deploy-HZStatic
{
	Import-Module -Name VMware.Hv.Helper
	switch ($SkipWU)
	{
		'Yes' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/TeamsInstall.ps1"]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/ImageSetup_Static.ps1"]
  }

  provisioner "windows-restart" {
  }  
}
"@
		}
		'No' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }
  
  provisioner "powershell"{
	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }
  
  provisioner "windows-restart" {
	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }


  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/TeamsInstall.ps1"]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/ImageSetup_Static.ps1"]
  }

  provisioner "windows-restart" {
  }  
}
"@
		}
		
	}
	
	$hclFILE | Out-File C:\Temp\$VMName.pkr.hcl -Encoding utf8
	
	CD C:\Packer
	.\packer.exe build C:\Temp\$VMName.pkr.hcl
	
	
	
	#Connect to vcenter and set display settings for VM, shut it down, and taken a snapshot
	Write-Host "Connecting to $vCenterServer" -ForegroundColor Green -BackgroundColor Black
	Connect-VIServer -Server $vCenterServer -User $AdminID -Password $AdminPass | Out-Null
	Write-Host "Connected.. Setting display settings..." -ForegroundColor Green -BackgroundColor Black
	$VM = Get-VM -Name $VMName
	$VideoAdapter = $vm.ExtensionData.Config.Hardware.Device | where { $_.GetType().Name -eq "VirtualMachineVideoCard" }
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$Config = New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Config.device = $VideoAdapter
	$Config.device.numDisplays = 3
	$Config.operation = "edit"
	$spec.deviceChange += $Config
	$VMView = $vm | Get-View
	$VMView.ReconfigVM($spec)
	Write-Host "Taking Snapshot..." -ForegroundColor Green -BackgroundColor Black
	New-Snapshot -VM $VMName -Name "$SnapshotName" -Description "Snapshot created during inital build of VM via Packer\PowerCLI" | Out-Null
	
	#Push to a Horizon Pool
	Write-Host "Connecting to Horizon..." -ForegroundColor Green -BackgroundColor Black
	Connect-HVServer -Server $HVServer -Username $AdminID -Password $AdminPass -Domain $env:USERDOMAIN | Out-Null
	Write-Host "Pushing $VMName/$SnapshotName to $PoolName" -ForegroundColor Green -BackgroundColor Black
	Start-HVPool -Pool $PoolName -SchedulePushImage -LogoffSetting FORCE_LOGOFF -ParentVM $VMName -SnapshotVM $SnapshotName -Vcenter $vCenterServer | Out-Null
	Write-Host "Updating Status every 60 seconds..." -ForegroundColor Green -BackgroundColor Black
	do
	{
		$ImageProgress = (Get-HVPool -PoolName $PoolName).AutomatedDesktopData.ProvisioningStatusData.InstantCloneProvisioningStatusData.PendingImageProgress
		Write-Host "Progress: $ImageProgress %"
		Start-Sleep 60
	}
	Until ($ImageProgress -eq $null)
	Write-Host "CLeaning up..." -ForegroundColor Green -BackgroundColor Black
	Remove-Item -Path C:\Temp\$VMName.pkr.hcl
	Start-Sleep 5
	Write-Host "Image Deployed!" -ForegroundColor Green -BackgroundColor Black
	Write-Host "               " -BackgroundColor Black
	Read-Host -Prompt "Press enter key to exit..."
	Exit 0
}
function Deploy-Standard
{
	switch ($SkipWU)
	{
		'Yes' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }
  
}
"@
		}
		'No' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }
  
  provisioner "powershell"{
	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }
  
  provisioner "windows-restart" {
	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	scripts = ["./scripts/WUpdate.ps1"]
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }

}
"@
			
		}
	}
	$hclFILE | Out-File C:\Temp\$VMName.pkr.hcl -Encoding utf8
	
	CD C:\Packer
	.\packer.exe build C:\Temp\$VMName.pkr.hcl
	
}
function Deploy-Template
{
	switch ($SkipWU)
	{
		'Yes' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	inline = ["New-Item -Path C:\\Temp -ItemType Directory -Force"]
  }

  provisioner "file"{
  	source = "./scripts/vRA"
	destination = "C:\\Temp"
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	inline = ["C:\\Temp\\vRA\\prepare_vra_template.ps1"]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	script = "./scripts/vRASetup.ps1"
  }

}
"@
		}
		'No' {
			$hclFILE =
			@"
source "vsphere-iso" "$VMName" {
  CPUs                 = "$VMCPU"
  RAM                  = "$VMMemoryMB"
  RAM_reserve_all      = false
  video_ram			   = 128000
  cluster              = "$vCenterServerCluster"
  communicator         = "winrm"
  create_snapshot      = "false"
  datacenter           = "$vCenterServerDataCenter"
  datastore            = "$VMDataStore"
  disk_controller_type = ["pvscsi"]
  storage {
  disk_size             = "$VMDiskMB"
  disk_thin_provisioned = true
  disk_controller_index = 0
  }
  firmware             = "efi"
  boot_order	       = "disk,cdrom"
  floppy_files         = ["./$WinVersion/autounattend.xml",  "./scripts/Network.ps1", "./scripts/drivers/pvscsi.cat", "./scripts/drivers/pvscsi.inf", "./scripts/drivers/pvscsi.sys", "./scripts/drivers/txtsetup.oem"]
  folder               = "$vCenterServerFolder"
  guest_os_type        = "windows9_64Guest"
  insecure_connection  = "true"
  iso_paths            = ["[$ISODatastore] $ISOPath", "[] /vmimages/tools-isoimages/windows.iso"]
  network_adapters {
    network      = "$VMPortGroup"
    network_card = "vmxnet3"
  }
  password = "$AdminPass"
  
  username       = "$AdminID"
  vcenter_server = "$vCenterServer"
  vm_name        = "$VMName"
  winrm_insecure = "true"
  winrm_password = "$WinRMPAss"
  winrm_use_ssl  = "false"
  winrm_username = "$WinRMUser"
  boot_command = ["<enter>"]
  boot_wait = "3s"
}

build {
  sources = ["source.vsphere-iso.$VMName"]

  provisioner "windows-restart" {
  }
  
  provisioner "powershell"{
	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	script = "./scripts/WUpdate.ps1"
  }
  
  provisioner "windows-restart" {
	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	script = "./scripts/WUpdate.ps1"
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }
  
  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	script = "./scripts/WUpdate.ps1"
  }

  provisioner "windows-restart" {
  	restart_timeout = "30m"
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	inline = ["New-Item -Path C:\\Temp -ItemType Directory -Force"]
  }

  provisioner "file"{
  	source = "./scripts/vRA"
	destination = "C:\\Temp"
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	inline = ["C:\\Temp\\vRA\\prepare_vra_template.ps1"]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell"{
  	elevated_user = "$WinRMUser"
	elevated_password = "$WinRMPAss"
	script = "./scripts/vRASetup.ps1"
  }

}
"@
		}
		
	}
	
	$hclFILE | Out-File C:\Temp\$VMName.pkr.hcl -Encoding utf8
	
	CD $PSScriptRoot
	.\packer.exe build C:\Temp\$VMName.pkr.hcl
	
	Write-Host "Setting Display settings on VM..."
	Connect-VIServer -Server $vCenterServer -User $AdminID -Password $AdminPass
	$VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue | Out-Null
	$VideoAdapter = $vm.ExtensionData.Config.Hardware.Device | where { $_.GetType().Name -eq "VirtualMachineVideoCard" }
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$Config = New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Config.device = $VideoAdapter
	$Config.device.numDisplays = 3
	$Config.operation = "edit"
	$spec.deviceChange += $Config
	$VMView = $vm | Get-View
	$VMView.ReconfigVM($spec)
	Write-Host "Converting to Template..." -ForegroundColor Green -BackgroundColor Black
	Get-VM -Name $VMName | Set-VM -ToTemplate -Confirm:$false
	Write-Host "Template Created!" -ForegroundColor Green -BackgroundColor Black
	Start-Sleep 2
	Write-Host "Image created and a converted to a template." -ForegroundColor Green -BackgroundColor Black
	Write-Host "               " -BackgroundColor Black
	Read-Host -Prompt "Press enter key to exit..."
	Exit 0
}

# Execute based on DeploymentType Paramater
switch ($DeploymentType)
{
	'HorizonIC' {
		Deploy-HZIC
	}
	'HorizonStatic' {
		Deploy-HZStatic
	}
	'Standard' {
		Deploy-Standard
	}
	'Template' {
		Deploy-Template
	}
}
