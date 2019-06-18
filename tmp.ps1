Function New-AzureVMClone {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,ParameterSetName="Default",Position=0)]
        [Object]$VMObject,
        [Parameter(ParameterSetName="MigrateAvailabilitySet",Position=1)]
        [Parameter(ParameterSetName="Default",Position=1)]
        [String]$AvailabilitySetName,
        [Parameter(ParameterSetName="MigrateAvailabilitySet",Position=2)]
        [Parameter(ParameterSetName="Default",Position=2)]
        [Switch]$MigrateAvailabilitySet,
        [Parameter(ParameterSetName="ClearAvailabilitySet",Position=3)]
        [Parameter(ParameterSetName="Default",Position=3)]
        [Switch]$ClearAvailabilitySet
    )

    BEGIN {
        try {
            If ((Get-Command Get-AzureRMContext -ErrorAction SilentlyContinue)) {
                Write-Verbose ("AzureRM Module installed, this cmdlet requires Az Module v1.5.0 from PSGallery")
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.SystemException]::New("Invalid Azure Powershell module is installed (AzureRM)"),
                        "InvalidPowerShellModule",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        "AzureRm Module"
                    )
                )
            }
            ElseIf (-NOT (Get-Command Get-AzContext -ErrorAction SilentlyContinue)) {
                Write-Verbose ("Missing valid Azure PowerShell Module - Please install v1.5.0 from PSGallery")
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.SystemException]::New("Missing correct Azure Powershell module (Az)"),
                        "InvalidPowerShellModule",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        "Az Module"
                    )
                )
            }
            Else {Write-Verbose ("Azure Powershell Module Verified!")}
        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
    }
    PROCESS {
        try {
            If ($VMObject.GetType().ToString() -ne "Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine") {
                Write-Verbose ("The VMObject passed via pipeline or parameter is invalid, Virtual Machine types ONLY!")
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.SystemException]::New("The VMObject type is not supported or is not an Azure Virtual Machine"),
                        "InvalidObjectType",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        $VMObject.GetType().ToString()
                    )
                )
            }

            If ($MigrateAvailabilitySet -and [System.String]::IsNullOrEmpty($AvailabilitySetName)) {
                Write-Verbose ("AvailabilitySetName parameter is required when using -MigrateAvailabilitySet")
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.ArgumentNullException]::New("AvailabilitySetName parameter cannot be empty"),
                        "ParameterNullOrEmpty",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        $null
                    )
                )
            }
            ElseIf ($MigrateAvailabilitySet -and $AvailabilitySetName) {
                Write-Verbose ("{0} will be migrated to a new Availability Set ({1})" -f $VMObject.Name,$AvailabilitySetName)
                $AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $VMObject.ResourceGroupName -Name $AvailabilitySetName
            }
            Else {
                If ([System.String]::IsNullOrEmpty($VMObject.AvailabilitySetReference.Id)){Write-Verbose ("{0} is not part of an Availability Set" -f $VMObject.Name)}
                Else {
                    Write-Verbose ("{0} is associated with {1} Availability Set and keep its association" -f $VMObject.Name,$VMObject.AvailabilitySetReference.Id.Split("/")[-1])
                    $AvailabilitySet = $VMObject.AvailabilitySetReference
                }
            }
            
            #Create Base VM Configuration object
            $newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMObject.HardwareProfile.VmSize -AvailabilitySetId $AvailabilitySet.Id -Tags $VMObject.Tags

            #Check OS from OSDisk and set OSDisk object
            Switch ($VMObject.StorageProfile.OsDisk.OsType) {
                "Windows" {
                    Set-AzVMOSDisk -VM $newVMConfig -Name $VMObject.StorageProfile.OsDisk.Name -Caching $VMObject.StorageProfile.OsDisk.Caching -CreateOption Attach -Windows -ManagedDiskId $VMObject.StorageProfile.OsDisk.ManagedDisk.Id | Out-Null
                    $newVMConfig.LicenseType = "Windows_Server"
                }
                "Linux" {Set-AzVMOSDisk -VM $newVMConfig -Name $VMObject.StorageProfile.OsDisk.Name -Caching $VMObject.StorageProfile.OsDisk.Caching -CreateOption Attach -Linux -ManagedDiskId $VMObject.StorageProfile.OsDisk.ManagedDisk.Id}
            }

            #Add data disks
            Foreach ($Datadisk in $VMObject.StorageProfile.DataDisks) {
                If ($Datadisk.ManagedDisk) {Add-AzVMDataDisk -VM $newVMConfig -Name $Datadisk.Name -Caching $Datadisk.Caching -ManagedDiskId $Datadisk.ManagedDisk.Id -DiskSizeInGB $Datadisk.DiskSizeGB -Lun $Datadisk.Lun -CreateOption Attach}
                Else {Add-AzVMDataDisk -VM $newVMConfig -Name $Datadisk.Name -Caching $Datadisk.Caching -DiskSizeInGB $Datadisk.DiskSizeGB -Lun $Datadisk.Lun -CreateOption Attach}
            }

            #Add network interfaces
            foreach ($vNic in $VMObject.NetworkProfile.NetworkInterfaces) {
                If ($vNic.Primary) {Add-AzVMNetworkInterface -VM $newVMConfig -Id $vNic.Id -Primary}
                Else {Add-AzVMNetworkInterface -VM $newVMConfig -Id $vNic.Id}
            }

            #Add boot diagnostics
            If ($VMObject.DiagnosticsProfile.BootDiagnostics.Enabled -eq $true) {
                $StorageAccount = $VMObject.DiagnosticsProfile.BootDiagnostics.StorageUri.Split(".")[0].SubString(8)
                Set-AzVMBootDiagnostic -VM $newVMConfig -Enable -ResourceGroupName $VMObject.ResourceGroupName -StorageAccountName $StorageAccount
            }
            
            Sleep 10

        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
    }
    END {
        try {

        }
        catch {

        }
    }
}