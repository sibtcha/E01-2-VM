REM Author : Fabio Candeias
REM Contact : fabio.candeias86@gmail.com
REM Description : This script use OSFMount to mount an E01 as Physical Disk and the use it in a VirtualBox Virtual Machine
REM Requirements : OSFMount
REM Last Update : 01.03.2023

@echo off

CLS

:setinformation
set osfmount_path="C:\Program Files\OSFMount\OSFMount.com"
set vboxmanage="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

echo.
echo Case Name :
set /p case_info=

set vm_path=d:\Temp\%case_info%\
set vm_name=%case_info%_VM

echo.
echo VM Path : %vm_path%
echo VM Name : %vm_name%
echo.

choice /C YN /M "Are this informations correct ? "
IF "%ERRORLEVEL%" == "2" goto setinformation
IF "%ERRORLEVEL%" == "1" goto preprocess

:preprocess
call :removeolddata

echo.
echo Search for mounted image
%osfmount_path% -l | findstr /C:"\\.\PhysicalDrive"
IF "%ERRORLEVEL%" == "1" GOTO createvirtualmachine
IF "%ERRORLEVEL%" == "0" GOTO oldimagefound

:oldimagefound
echo.
CHOICE /N /C:123456789 /M "We found an oldest image. Please choose the number to unmount it"%1
IF "%ERRORLEVEL%" == "1" SET physical_drive=1
IF "%ERRORLEVEL%" == "2" SET physical_drive=2
IF "%ERRORLEVEL%" == "3" SET physical_drive=3
IF "%ERRORLEVEL%" == "4" SET physical_drive=4
IF "%ERRORLEVEL%" == "5" SET physical_drive=5
IF "%ERRORLEVEL%" == "6" SET physical_drive=6
IF "%ERRORLEVEL%" == "7" SET physical_drive=7
IF "%ERRORLEVEL%" == "8" SET physical_drive=8
IF "%ERRORLEVEL%" == "9" SET physical_drive=9

%osfmount_path% -D -m %physical_drive%

call :removeosddeltafiles

timeout 5

:createvirtualmachine
echo Create dir for Virtual Machine
mkdir %vm_path%
call :adddisk

echo.
echo Creating VirtualBox VM
%vboxmanage% createvm --basefolder %vm_path% --name %vm_name% --ostype "Windows10_64" --register

echo.
echo Configuring VirtualBox VM
%vboxmanage% modifyvm %vm_name% --cpus 8 --memory 32768 --vram 128 --acpi on --ioapic on --boot1 disk --nic1 none

echo.
echo Configuring VirtualBox VM for EFI boot
%vboxmanage% modifyvm %vm_name% --firmware efi64

echo.
echo Change Graphics Controller to vboxsvga
%vboxmanage% modifyvm %vm_name% --graphicscontroller vboxsvga

echo.
echo Creating disk for VirtualBox VM
%vboxmanage% storagectl %vm_name% --name "SATA" --add SATA --controller IntelAhci --bootable on

echo.
echo Attaching disk to VirtualBox VM
%vboxmanage% storageattach %vm_name% --storagectl "SATA" --port 0 --device 0 --type hdd --medium %vmdk_path%


:choiceadddisk
echo.
CHOICE /C YN /M "Do you want to add another disk"
IF "%ERRORLEVEL%" == "1" GOTO addsecondarydisk
IF "%ERRORLEVEL%" == "2" GOTO startvm

:addsecondarydisk
call :adddisk
echo.
echo Attaching disk to VirtualBox VM
%vboxmanage% storageattach %vm_name% --storagectl "SATA" --port 0 --device 0 --type hdd --medium %vmdk_path%

GOTO choiceadddisk

:startvm
echo.
echo Starting virtual machine with VBoxManage:
%vboxmanage% startvm %vm_name%

echo.
echo.
echo.
echo.
CHOICE /C Y /M "When you have finish working on this Virtual Machines and you want to clean the data please press Y "
IF "%ERRORLEVEL%" == "1" GOTO cleandata

:cleandata
echo Unmout virtual Disk
%osfmount_path% -D -m %physical_drive%
timeout 5
call :removeolddata
timeout 5
call :removeosddeltafiles
EXIT


:removeolddata
echo.
echo Remove older Virtual Machines in VirtualBox
%vboxmanage% unregistervm %vm_name% --delete

echo.
echo Remove old Virtual Machines dir %vm_path%
rmdir %vm_path% /Q /S
EXIT /B 0



:removeosddeltafiles
echo.
echo Remove old delta and index file
DEL /F /Q %image_disk%.osfdelta.raw
DEL /F /Q %image_disk%.osfdelta.index
EXIT /B 0


:adddisk
echo.
echo Forensic image to mount (E01)?:
set /p image_disk=

echo Mounting disk image file with OSFMount
%osfmount_path% -a -t file -f %image_disk% -o wc,physical

timeout 5

echo List of mounted disk
%osfmount_path% -l

CHOICE /N /C:123456789 /M "Please choose the disk number of the mounted file : "%1
IF "%ERRORLEVEL%" == "1" SET physical_drive=1
IF "%ERRORLEVEL%" == "2" SET physical_drive=2
IF "%ERRORLEVEL%" == "3" SET physical_drive=3
IF "%ERRORLEVEL%" == "4" SET physical_drive=4
IF "%ERRORLEVEL%" == "5" SET physical_drive=5
IF "%ERRORLEVEL%" == "6" SET physical_drive=6
IF "%ERRORLEVEL%" == "7" SET physical_drive=7
IF "%ERRORLEVEL%" == "8" SET physical_drive=8
IF "%ERRORLEVEL%" == "9" SET physical_drive=9

echo.
ECHO You choose disk number %physical_drive%

echo.
echo Clean mounted disk with diskpart
(echo select disk %physical_drive%
echo offline disk
echo attributes disk clear readonly)| DISKPART

timeout 5

echo.
echo Create VMDK
set vmdk_name=%vm_path%%physical_drive%.vmdk

set vmdk_name=%case_info%_%physical_drive%_disk.vmdk
set vmdk_path=%vm_path%%vmdk_name%
%vboxmanage% internalcommands createrawvmdk -filename %vmdk_path% -rawdisk \\.\PhysicalDrive%physical_drive%
exit /B 0