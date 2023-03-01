# Author : Fabio Candeias
# Contact : fabio.candeias86@gmail.com
# Description : This script use OSFMount to mount an E01 as Physical Disk and the use it in a Hyper-V Virtual Machine
# Requirements : OSFMount
# Last Update : 01.03.2023

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}

Get-Date

$osfmountPath = "C:\Program Files\OSFMount\OSFMount.com"
$VMCPU = 4
$VMRAM = 8589934592

$caseInfo = Read-Host -Prompt 'Case Name'

$VMName = $caseInfo+"_VM"
Write-Host "Case Name : $caseInfo / VM Name : $VMName"

Write-Host "Forensic image to mount (E01) ?"

[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
$openFile = New-Object System.Windows.Forms.OpenFileDialog
$openFile.Filter = "Evidence File (.e01)|*.e01" 
If($openFile.ShowDialog() -eq "OK")
{$imageDisk = $openFile.FileName} 

$imageDiskQuotted = "`"$imageDisk`""


####################### OSFMOUNT #######################

Start-Process -FilePath $osfmountPath -ArgumentList "-a","-t","file","-f",$imageDiskQuotted,"-o", " wc,physical" -Wait

Start-Sleep 2

$osfmountDiskFound = Get-Disk | Where-Object -FilterScript {$_.FriendlyName -Eq 'PassMark osfdisk'} | Select-Object FriendlyName,Number,Size,PartitionStyle
if($osfmountDiskFound -isnot [system.array]){
    Write-Host "Only one disk found : $osfmountDiskFound.Number"
    $physicalDisk = $osfmountDiskFound.Number
} else {
    $osfmountDiskFound.foreach({"$($_.Number) - $($_.FriendlyName) - $($_.PartitionStyle)"})

    $physicalDisk = Read-Host -Prompt 'Which disk to you want to use ?'

    Write-Host "Using disk number $physicalDisk"
}

####################### DISKPART #######################

Set-Disk $physicalDisk -IsOffline $true
Set-Disk $physicalDisk -IsReadOnly $false

####################### HYPER-V #######################

$PartStyle = Get-Disk $physicalDisk | Select-Object PartitionStyle

if($PartStyle.PartitionStyle -like 'MBR') {
    Write-Host 'Disk selected is MBR, Hyper-V Gen1 choosed'
    $gen = 1
}
else {
    Write-Host 'Disk selected is GPT, Hyper-V Gen2 choosed'
    $gen = 2
}

Write-Host "$VMName - CPU $VMCPU - RAM $($VMRAM/1024/1024/1024)"
New-VM -Name $VMName -MemoryStartupBytes $VMRAM -Generation $gen

Set-VMProcessor -VMName $VMName -Count $VMCPU

Get-Disk $physicalDisk | Add-VMHardDiskDrive -VMName $VMName

Set-VM -Name $VMName -CheckpointType Disable

Enable-VMIntegrationService -VMName $VMName -Name "Interface de services d’invité"

start-vm $VMName

vmconnect.exe localhost $VMName

Write-Host "You can now work with the Virtual Machine. Presse Enter to kill it"
pause

Write-Host "Stop VM $VMName"
Stop-VM $VMName

Write-Host "Remove VM $VMName"
Remove-VM $VMName -Force

Write-Host "Umount physical drive $physicalDisk"
Start-Process -FilePath $osfmountPath -ArgumentList "-D","-m","$physicalDisk" -Wait

Start-Sleep 2


Write-Host "Remove OSFDelta files"
Remove-Item -fo $imageDisk".osfdelta.raw"
Remove-Item -fo $imageDisk".osfdelta.index"

Write-Host "Press Enter to exit"
pause
