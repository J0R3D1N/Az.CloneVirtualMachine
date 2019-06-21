<#
    .SYNOPSIS
        Creates a Copy of a VM in a new AV set with a new size

    .PARAMETER SubscriptionId
        Subscription Id of subscription to use

    .PARAMETER Name
        Name of VM to move

    .PARAMETER ResourceGroupName
        Resource group of VM being moved

    .PARAMETER VMSize
        New size of VM

    .PARAMETER NewAvailSetName
        Name of the new availability set

    .PARAMETER PlatformFaultDomainCount 
        Fault domain count of new availability set

    .PARAMETER PlatformUpdateDomainCount
        Update  domain count of new availability set

    .PARAMETER BlobUrl
        Blob url of storage account. Changes based on Azure env being used

    .NOTES
        This script attempts to support all of the little pieces that make up a VM in Azure. Not
        all are currently or feasibly supported.

        Backup
            - Still connected to previous recovery vault post move
            - can still backup VM
        Log Analytics
            - still reporting post move
        Extensions
            - No longer showing in portal
            - Still on disk however, will require re-enabling, but not reinstalling
        Disaster Recovery
            - pre-move DR moves to critical state, cannot re-associate with new VM
                - Can restore previous VM
            - Can re-protect moved VM after removing old VM from DR
        Tags
            - Moving tags is support via code
        Nics
            - Multiple NICS supported via code
        Disk
            - OS and Data disk supported via code
        OS profile
            - This is not supported with this type of move and will be empty
        Boot diag
            - supported via code
        Alerts (classic)
            - Alert remained and still triggered

    .EXAMPLE
        .\New-AzureVMCopy.ps1 `
            -SubscriptionId '<Your Sub ID HERE>' `
            -Name "Jenkins1" `
            -ResourceGroupName "Jenkins" `
            -VMSize "Standard_DS1_v2" `
            -newAvailSetName "AVSET2s" 
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]
    $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName = "DomainJoin",

    [Parameter(Mandatory = $true)]
    [string]
    $VMSize,

    [Parameter(Mandatory = $true)]
    [string]
    $newAvailSetName,

    $PlatformFaultDomainCount = 2,

    $PlatformUpdateDomainCount = 5,

    $BlobUrl = '.blob.core.usgovcloudapi.net/'
)

<#
    .SYNOPSIS
        Connects to Azure and sets the provided subscription.
    .PARAMETER SubscriptionId
        ID of subscription to use
    .PARAMETER AutomationConnection
        Azure automation connection object for using a AA run as account
#>

function Set-AzureConnection
{
    Param
    (
        [parameter(mandatory = $true)]
        $SubscriptionId,

        $AutomationConnection,

        $AzureEnvironment = 'AzureCloud'
    )

    $context = Get-AzureRmContext

    if($null -eq $context.Account)
    {
        $envARM = Get-AzureRmEnvironment -Name $AzureEnvironment

        if($null -ne $AutomationConnection)
        {
            $context = Add-AzureRmAccount `
                        -ServicePrincipal `
                        -Tenant $Conn.TenantID `
                        -ApplicationId $Conn.ApplicationID `
                        -CertificateThumbprint $Conn.CertificateThumbprint `
                        -Environment $envARM
        }
        else # if no connection info, log in using the web prompts
        {
            $context = Add-AzureRmAccount -Environment $envARM -ErrorAction Stop
        }
    }

    $null = Set-AzureRmContext -Subscription $SubscriptionId -ErrorAction Stop
}

Function New-AzureVMClone {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true)]
        [Object]$VMObject,
        [Switch]$NewAvailabilitySet,
        [Switch]$IncludeExtensions
    )

    BEGIN {
        try {
            If ($VMObject.GetType().ToString() -ne "Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine") {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.SystemException]::New("The VMObject type is not supported or is not an Azure Virtual Machine"),
                        "InvalidObjectType",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        $VMObject.GetType().ToString()
                    )
                )
            }

        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
    }
    PROCESS {
        try {

        }
        catch {

        }
    }
    END {
        try {

        }
        catch {

        }
    }
}

Set-AzureConnection -SubscriptionId $SubscriptionId -AzureEnvironment 'AzureUSGovernment'

# Set variables
$vmInfo = @{
    Name = $Name
    ResourceGroupName = $ResourceGroupName
}

# Get the details of the VM to be moved to the Availablity Set
$vmState = Get-AzureRmVm @vmInfo -Status

if($vmState.Statuses[-1].Code -ne 'PowerState/running')
{
    Start-AzureRMVM @vmInfo -ErrorAction 'Stop'
}

$originalVM = Get-AzureRmVM @vmInfo

# warn about extensions
foreach($extension in $originalVM.Extensions)
{
    Write-Warning "Vm $($vmInfo.Name) has extension $($extension.Name). It will need to be redeployed."
}

# Create new availability set if it does not exist
$availSet = Get-AzureRmAvailabilitySet `
   -ResourceGroupName $vmInfo.ResourceGroupName `
   -Name $newAvailSetName `
   -ErrorAction Ignore

if (-Not $availSet) 
{
    $availSet = New-AzureRmAvailabilitySet `
        -Location $originalVM.Location `
        -Name $newAvailSetName `
        -ResourceGroupName $vmInfo.ResourceGroupName `
        -PlatformFaultDomainCount $PlatformFaultDomainCount `
        -PlatformUpdateDomainCount $PlatformUpdateDomainCount `
        -Sku Aligned `
        -ErrorAction Stop
}

# Remove the original VM
Write-Output "Removing VM $($vmInfo.Name)"

Remove-AzureRmVM @vmInfo -Force -ErrorAction Stop

# Create the basic configuration for the replacement VM
$vmConfigParam = @{
    VMName = $originalVM.Name
    VMSize = $VMSize
    AvailabilitySetId = $availSet.Id
    Tags = $originalVM.Tags
    ErrorAction = 'Stop'
}

if($originalVM.StorageProfile.OsDisk.OsType -eq 'Windows')
{
    $newVM = New-AzureRmVMConfig @vmConfigParam -LicenseType "Windows_Server"
}
elseif($originalVM.StorageProfile.OsDisk.OsType -eq 'Linux')
{
    $newVM = New-AzureRmVMConfig @vmConfigParam
}

# Add OS Disk
$osDiskParam = @{
    VM = $newVM
    CreateOption = 'Attach'
    ManagedDiskId = $originalVM.StorageProfile.OsDisk.ManagedDisk.Id
    Name = $originalVM.StorageProfile.OsDisk.Name
    ErrorAction = 'Stop'
}

if($originalVM.StorageProfile.OsDisk.OsType -eq 'Windows')
{
    $null = Set-AzureRmVMOSDisk @osDiskParam -Windows
}
elseif($originalVM.StorageProfile.OsDisk.OsType -eq 'Linux')
{
    $null = Set-AzureRmVMOSDisk @osDiskParam -Linux
}

# Add Data Disks
foreach ($disk in $originalVM.StorageProfile.DataDisks) 
{ 
    $null = Add-AzureRmVMDataDisk `
        -VM $newVM `
        -Name $disk.Name `
        -ManagedDiskId $disk.ManagedDisk.Id `
        -Caching $disk.Caching `
        -Lun $disk.Lun `
        -DiskSizeInGB $disk.DiskSizeGB `
        -CreateOption 'Attach' `
        -ErrorAction Stop
}

# Add NIC(s)
foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) 
{
    $null = Add-AzureRmVMNetworkInterface `
       -VM $newVM `
       -Id $nic.Id `
       -ErrorAction Stop
}

# Add Boot Diag
if($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled)
{
    $storageAccountName = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri
    $storageAccountName = $storageAccountName.Replace('https://', '')
    $storageAccountName = $storageAccountName.Replace($BlobUrl, '')

    $storageAccount = Get-AzureRmResource -Name $storageAccountName -ResourceType 'Microsoft.Storage/storageAccounts'

    $null = Set-AzureRmVMBootDiagnostics `
        -VM $newVM `
        -Enable `
        -StorageAccountName $storageAccountName `
        -ResourceGroupName $storageAccount.ResourceGroupName
}

# Recreate the VM
Write-Output "Recreating VM $($vmInfo.Name)"

New-AzureRmVM `
   -ResourceGroupName $originalVM.ResourceGroupName `
   -Location $originalVM.Location `
   -VM $newVM `
   -DisableBginfoExtension
