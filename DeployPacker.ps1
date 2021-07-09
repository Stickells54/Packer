<#	
	.NOTES
	===========================================================================
	 Created on:   	7/9/2021 10:24 AM
	 Created by:   	Travis Stickells
	 Filename:     	DeployPacker.ps1
	===========================================================================
	.DESCRIPTION
		Fill out the hashtable and run this script to pass the parameters to the Packer.ps1 script. Detailed descriptions of each variable are available in Packer.ps1.
#>

$HASHTABLE = @{
	ISODatastore		    = "unRAID"
	ISOPath				    = "en_windows_10_business_editions_version_20h2_x64_dvd_4788fb7c.iso"
	VMCPU				    = "2"
	VMDiskMB			    = "80912"
	VMMemoryMB			    = "4096"
	vCenterServerCluster    = "SHLAB"
	vCenterServerDataCenter = "SH-DC"
	VMDataStore			    = "SSD-R720"
	vCenterServerFolder	    = "Packer"
	VMPortGroup			    = "dSW-VDI"
	vCenterServer		    = "vcenter.stickellshome.net"
	DeploymentType		    = "Standard"
	WinVersion			    = "Enterprise"
	WinRMPAss			    = "VMware1!"
	WinRMUser			    = "ADmin"
	VMName				    = "w10-pkr-vra"
	SkipWU 					= "Yes"
}


$Packer = "$PSScriptRoot\Packer.ps1"

& $Packer @HashTable