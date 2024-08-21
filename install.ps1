# PowerShell script to run and install the Command Logger
# Run this with admin perms

#Requires -RunAsAdministrator

# Checking to see if we have all the files
if (!(Test-Path -path ./logcmd.c))
{
    Write-Error "Unable to locate ./logcmd.c. Aborting installation."
    exit
}

if (!(Test-Path -path ./log_events.h))
{
    Write-Error "Unable to locate ./log_events.h. Aborting installation."
    exit
}

if (!(Test-Path -path ./log_events.dll))
{
    Write-Error "Unable to locate ./log_events.dll. Aborting installation."
    exit
}

$CMD_LOG_PATH = "C:\Program Files\Command Logs"
mkdir $CMD_LOG_PATH

if (!$?)
{
    echo "C:\Program Files\Command Logs already exists. Aborting installation in case we're accidentally overwriting something"
    exit
}

cp ./logcmd.c $CMD_LOG_PATH
cp ./log_events.h $CMD_LOG_PATH
cp ./log_events.dll $CMD_LOG_PATH

# Compiling logcmd.exe
cd $CMD_LOG_PATH
gcc ./logcmd.c -o ./logcmd.exe -m32
if (!$?)
{
    echo "Failed to compile and link ./logcmd.exe. Check above error message."
    exit
}

# Adding log_events.dll and logcmd.exe to registry
# Don't want to use $ls here because this functions a bit differently in ps1
$LOG_EVENTS_PATH = Get-ChildItem ./log_events.dll | Select -expand FullName
$LOGCMD_PATH = Get-ChildItem ./logcmd.exe | Select -expand FullName

# AutoRun
$REGISTRY_CMDPROCESSOR = "HKLM:\SOFTWARE\Microsoft\Command Processor"
$RUN_CMD = "call `"$LOGCMD_PATH`""

function Create-ItemPropertyStr
{
    param (
        [string]$ITEM_PATH,
        [string]$ITEM_NAME,
        [string]$ITEM_VALUE
    )

    # Creates an item at $ITEM_PATH with $ITEM_VALUE if it exists. Otherwise, update the $ITEM_NAME
    if (!(Get-ItemProperty -Path $ITEM_PATH -Name $ITEM_NAME -ErrorAction SilentlyContinue))
    {
        New-ItemProperty -Path $ITEM_PATH -Name $ITEM_NAME -Value $ITEM_VALUE -PropertyType String
    }
    else
    {
        Set-ItemProperty -Path $ITEM_PATH -Name $ITEM_NAME -Value $ITEM_VALUE
    }
}

function Create-ItemPropertyDWORD
{
    param (
        [string]$ITEM_PATH,
        [string]$ITEM_NAME,
        [int]$ITEM_VALUE
    )

    # Creates an item at $ITEM_PATH with $ITEM_VALUE if it exists. Otherwise, update the $ITEM_NAME. This is for DWORDS
    if (!(Get-ItemProperty -Path $ITEM_PATH -Name $ITEM_NAME -ErrorAction SilentlyContinue))
    {
        New-ItemProperty -Path $ITEM_PATH -Name $ITEM_NAME -Value $ITEM_VALUE -PropertyType DWORD
    }
    else
    {
        Set-ItemProperty -Path $ITEM_PATH -Name $ITEM_NAME -Value $ITEM_VALUE
    }
}

Create-ItemPropertyStr $REGISTRY_CMDPROCESSOR "AutoRun" $RUN_CMD

# DLL
$REGISTRY_CMDLINE = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\CommandLine"

if (!(Get-Item $REGISTRY_CMDLINE -ErrorAction SilentlyContinue))
{
    New-Item $REGISTRY_CMDLINE
}
else
{
    echo "$REGISTRY_CMDLINE already exists. We are not creating a new one"
}

Create-ItemPropertyDWORD $REGISTRY_CMDLINE "AutoBackupLogFiles" 0
Create-ItemPropertyDWORD $REGISTRY_CMDLINE "MaxSize" 524288
Create-ItemPropertyStr $REGISTRY_CMDLINE "PrimaryModule" "CommandLine"

$REGISTRY_CMDLINE_CMD = "$REGISTRY_CMDLINE\cmdexe"

if (!(Get-Item $REGISTRY_CMDLINE_CMD -ErrorAction SilentlyContinue))
{
    New-Item $REGISTRY_CMDLINE_CMD
}
else
{
    echo "$REGISTRY_CMDLINE_CMD already exists. We are not creating a new one"
}

Create-ItemPropertyDWORD $REGISTRY_CMDLINE_CMD "TypesSupported" 7
Create-ItemPropertyStr $REGISTRY_CMDLINE_CMD "EventMessageFile" $LOG_EVENTS_PATH

echo "Installation Complete."