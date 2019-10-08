Function New-AzVMClone {
    <#
    .SYNOPSIS
        From an existing Virtual Machine, clone its configuration and change it's Availability Set
        affiliation (migrate, remove, leave 'as-is')

    .DESCRIPTION
        This function is designed to MIGRATE or REMOVE an Azure Virtual Machine to or from an
        Availability Set.  This function requires that the incoming object, through pipeline
        or parameter, is a Virtual Machine object.  Most commonly, this object is created
        using the Get-AzVM cmdlet and storing the VM(s) into a variable.

        This function assumes that IF you are migrating a Virutal Machine to NEW Availability
        Set, the target Availability Set has already been created.

        WARNING:  THIS FUNCTION DOES NOT CURRENTLY ADDRESS ANY EXTENSION FOR THE VIRTUAL MACHINE
        AND THEY WILL NEED TO BE RE-INSTALLED MANUALLY.
    .EXAMPLE
        Get-AzVM -ResourceGroupName MyResourceGroup -Name TestVM001 | New-AzVMClone -MigrateAvailabilitySet -AvailabilitySetName MyNewAS01
        
        - OR -

        PS C:\>$myVM =  Get-AzVM -ResourceGroupName MyResourceGroup -Name TestVM001
        PS C:\>$myVM | New-AzVMClone -MigrateAvailabilitySet -AvailabilitySetName MyNewAS01

        - OR -

        PS C:\>$myVM =  Get-AzVM -ResourceGroupName MyResourceGroup -Name TestVM001
        PS C:\>New-AzVMClone -VMObject $myVM -MigrateAvailabilitySet -AvailabilitySetName MyNewAS01

        Description: Migrate a single Virtual Machine to a new Availability Set
    .EXAMPLE
        Get-AzVM -ResourceGroupName MyResourceGroup -Name TestVM001 | New-AzVMClone -RemoveAvailabilitySet
        
        - OR -

        PS C:\>$myVM =  Get-AzVM -ResourceGroupName MyResourceGroup -Name TestVM001
        PS C:\>$myVM | New-AzVMClone -RemoveAvailabilitySet

        - OR -

        PS C:\>$myVM =  Get-AzVM -ResourceGroupName MyResourceGroup -Name TestVM001
        PS C:\>New-AzVMClone -VMObject $myVM -RemoveAvailabilitySet

        Description: Remove a single Virtual Machine from an Availability Set
    .EXAMPLE
        Get-AzVM -ResourceGroupName MyResourceGroup | New-AzVMClone -MigrateAvailabilitySet -AvailabilitySetName MyNewAS01

        - OR -

        PS C:\>$myVMs =  Get-AzVM -ResourceGroupName MyResourceGroup
        PS C:\>$myVMs | New-AzVMClone -MigrateAvailabilitySet -AvailabilitySetName MyNewAS01

        - OR -

        PS C:\>$myVMs =  Get-AzVM -ResourceGroupName MyResourceGroup
        PS C:\>New-AzVMClone -VMObject $myVMs -MigrateAvailabilitySet -AvailabilitySetName MyNewAS01

        Description: Migrate a GROUP of Virtual Machines in a Resource Group to a new Availability Set
    .EXAMPLE
        Get-AzVM -ResourceGroupName MyResourceGroup | New-AzVMClone -RemoveAvailabilitySet

        - OR -

        PS C:\>$myVMs =  Get-AzVM -ResourceGroupName MyResourceGroup
        PS C:\>$myVMs | New-AzVMClone -RemoveAvailabilitySet

        - OR -

        PS C:\>$myVMs =  Get-AzVM -ResourceGroupName MyResourceGroup
        PS C:\>New-AzVMClone -VMObject $myVMs -RemoveAvailabilitySet

        Description: Remove a GROUP of Virtual Machines in a Resource Group from an Availability Set
    .INPUTS
        Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine

        Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList
    .OUTPUTS
        None.  This function does not provide an output, only on screen information
    #>
    <#
        CHANGE LOG
        ---------------------------------------------------------------------------------
        v1.2
          - Primary production release
        v1.3
          - Fixed some string values that called a split method, but if the value was NULL, the method would error.  Changed to an operator.
        v1.4
          - Fixed issue where grabbing the string from the StorageUri would incorrectly split the string
          - Moved the Show-Menu helper function inside the main function
        v1.5
          - Added support for VM Resize during clone operation (new function Select-AzVMSize)
          - Added support for VM(s) that are using a Marketplace plan
          - Added feature where the VMObject is converted to JSON (in the same working directory) before it is deleted from Azure
        v1.6
          - Fix display output for Resize and plan properties cloning
    #>
    [CmdletBinding(DefaultParameterSetName="Default",SupportsShouldProcess,ConfirmImpact="High")]
    Param(
        # The VM Object(s) to be cloned
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [Object]$VMObject,

        # The name of the new Availability Set to associated with the cloned VM(s)
        [Parameter(Mandatory=$true,ParameterSetName="Migrate",Position=1)]
        [String]$AvailabilitySetName,

        # Switch to enable Availability Set migration
        [Parameter(Mandatory=$true,ParameterSetName="Migrate",Position=0)]
        [Switch]$MigrateAvailabilitySet,

        # Switch to remove a VM from its current availability set after cloning
        [Parameter(Mandatory=$true,ParameterSetName="Remove",Position=0)]
        [Switch]$RemoveAvailabilitySet,

        # Switch to resize the VM to a new size
        [Parameter(Mandatory=$false,ParameterSetName="Migrate",Position=2)]
        [Parameter(Mandatory=$false,ParameterSetName="Remove",Position=1)]
        [Switch]$Resize,

        #Switch parameter to bypass confirmation
        [Switch]$Force
    )

    BEGIN {
        try {
            # Checks for legacy Azure RM PowerShell Module
            If ((Get-InstalledModule -Name AzureRm -ErrorAction SilentlyContinue -Debug:$false)) {
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
            # Checks for current Azure PowerShell Module
            ElseIf (-NOT (Get-InstalledModule -Name Az -MinimumVersion 1.5 -ErrorAction SilentlyContinue -Debug:$false)) {
                Write-Warning ("Missing valid Azure PowerShell Module - Please install v1.5.0 from PSGallery")
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.SystemException]::New("Missing correct Azure Powershell module (Az)"),
                        "InvalidPowerShellModule",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        "Az Module"
                    )
                )
            }
            Else {Write-Verbose ("Azure Powershell Module verified")}

            # Helper function for display output
            Function Show-Menu {
                Param(
                    [string]$Menu,
                    [string]$Title = $(Throw [System.Management.Automation.PSArgumentNullException]::new("Title")),
                    [switch]$ClearScreen,
                    [Switch]$DisplayOnly,
                    [ValidateSet("Full","Mini","Info")]
                    $Style = "Full",
                    [ValidateSet("White","Cyan","Magenta","Yellow","Green","Red","Gray","DarkGray")]
                    $Color = "Gray"
                )
                if ($ClearScreen) {[System.Console]::Clear()}
            
                If ($Style -eq "Full") {
                    #build the menu prompt
                    $menuPrompt = "`n`r"
                    $menuPrompt = "/" * (95)
                    $menuPrompt += "`n`r////`n`r//// $Title`n`r////`n`r"
                    $menuPrompt += "/" * (95)
                    $menuPrompt += "`n`n"
                }
                ElseIf ($Style -eq "Mini") {
                    $menuPrompt = "`n`r"
                    $menuPrompt = "\" * (80)
                    $menuPrompt += "`n$Title`n"
                    $menuPrompt += "\" * (80)
                    $menuPrompt += "`n"
                }
                ElseIf ($Style -eq "Info") {
                    $menuPrompt = "`n`r"
                    $menuPrompt = "-" * (80)
                    $menuPrompt += "`n-- $Title`n"
                    $menuPrompt += "-" * (80)
                }
            
                #add the menu
                $menuPrompt+=$menu
            
                [System.Console]::ForegroundColor = $Color
                If ($DisplayOnly) {Write-Host $menuPrompt}
                Else {Read-Host -Prompt $menuprompt}
                [system.console]::ResetColor()
            }

            Function Select-AzVMSize {
                [CmdletBinding()]
                Param(
                    [String]$ResourceGroupName,
                    [Parameter(ParameterSetName="AVSet",Position=0)]
                    [String]$AvailabilitySetName,
                    [Parameter(ParameterSetName="Location",Position=0)]
                    [String]$Location
                )

                # Getting possible sizes from Availability Set
                If ($AvailabilitySetName) {$ResizeOptions = Get-AzVMSize -ResourceGroupName $ResourceGroupName -AvailabilitySetName $AvailabilitySetName}
                ElseIf ($Location) {$ResizeOptions = Get-AzVMSize -ResourceGroupName $ResourceGroupName -AvailabilitySetName $AvailabilitySetName}
                Else {Return}
                $ResizeFamilies = $ResizeOptions.Name.Substring(9,1) | Select-Object -Unique | Sort-Object

                Write-Verbose ("Found {0} Virtual Machine Series and {1} total size options" -f $ResizeFamilies.Count,$ResizeOptions.count)
                # Building prompts for VM Resizing
                $ResizeMsgBanner = ("`n`r Azure VM Size Information: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes `n`r")
                $Range = 0..($ResizeFamilies.Count -1)
                For ($i = 0; $i -lt $ResizeFamilies.Count; $i++) {$ResizeMsgBanner += " [$i] $($ResizeFamilies[$i]) Series`n"}
                $ResizeMsgBanner += "`n Please select a Virtual Machine Family - 99 to Cancel"

                # Prompt for VM Family
                Do {$FamilyChoice = Show-Menu -Title "Select a Virtual Machine Family" -Menu $ResizeMsgBanner -Style Info -Color Yellow}
                Until (($Range -contains $FamilyChoice) -OR ($FamilyChoice -eq "99"))

                If ($FamilyChoice -eq "99") {Return}

                # Prompt for VM Size
                $SelectionCount = 0
                Do {
                    $VMSize = ($ResizeOptions.Where{$_.Name -like "Standard_$($ResizeFamilies[$FamilyChoice])*"} | Sort-Object NumberOfCores,MemoryInMB | Out-GridView -PassThru).Name

                    If ([System.String]::IsNullOrEmpty($VMSize)) {
                        $SelectionCount++
                        Write-Warning "Invalid or No Virtual Machine Size selected!"
                        If ($SelectionCount -ge 2) {
                            Write-Warning ("No Virtual Machine Size selection was made!" -f $VMObject.GetType().Name)
                            $PSCmdlet.ThrowTerminatingError(
                                [System.Management.Automation.ErrorRecord]::New(
                                    [System.SystemException]::New("Invalid Virtual Machine Size Selection"),
                                    "InvalidSelection",
                                    [System.Management.Automation.ErrorCategory]::InvalidResult,
                                    "NoSelectionFound"
                                )
                            )
                            Return
                        }
                        Else {Start-Sleep -Milliseconds 2500}
                    }
                }
                Until ($ResizeOptions.Name -contains $VMSize)
                Return $VMSize
            }
        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
    }
    PROCESS {
        try {
            # Checks to see if the incoming $VMObject is of the correct type
            If ($VMObject.GetType().Name -ne "PSVirtualMachine" -and $VMObject.GetType().Name -ne "PSVirtualMachineList") {
                Write-Warning ("The VMObject passed via pipeline or parameter is invalid {0}, Virtual Machine types ONLY!" -f $VMObject.GetType().Name)
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.SystemException]::New("The VMObject type is not supported or is not an Azure Virtual Machine"),
                        "InvalidObjectType",
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        $VMObject.GetType().Name
                    )
                )
            }
            Else {Write-Verbose ("Virtual Machine object type verified ({0})" -f $VMObject.GetType().Name)}
            
            If ([System.String]::IsNullOrEmpty($VMObject.AvailabilitySetReference.Id)) {
                $CurrentAvailabilitySetName = "Standalone VM"
            }
            Else {$CurrentAvailabilitySetName = ($VMObject.AvailabilitySetReference.Id -Split "/")[-1]}

            # Simple hashtable to show which components have been cloned
            $ConfigStatus = [Ordered]@{
                VMName = $VMObject.Name
                OS = $VMObject.StorageProfile.OsDisk.OsType
                Size = $VMObject.HardwareProfile.VmSize
                AvailabilitySet = $AvailabilitySetName
                Tags = $true
                OSDisk = $false
                DataDisks = $false
                Network = $false
                Plan = $false
                BootDiagnostics = $false
                Extensions = $false
            }

            # Checks that this is a migration and that the new AVSet is not the same as the current
            If ($MigrateAvailabilitySet -and $AvailabilitySetName -ne $CurrentAvailabilitySetName) {
                $AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $VMObject.ResourceGroupName -Name $AvailabilitySetName -Debug:$false
                Show-Menu -Title ("{0} will be migrated to a new Availability Set ({1})" -f $VMObject.Name,$AvailabilitySetName) -DisplayOnly -Style Info -Color Green
                # Continuation prompt asking to clone the configuration for the VM
                If ($Force -or $PSCmdlet.ShouldProcess("$($VMObject.Name)","Virtual Machine migration to new Availability Set")) {
                    # Create Base VM Configuration object
                    If ($Resize) {
                        # Create new VM Object with new size
                        $VMSize = Select-AzVMSize -ResourceGroupName $VMObject.ResourceGroupName -AvailabilitySetName $AvailabilitySet.Name
                        Write-Host ("`n`r [{0}] Virtual Machine will be resized from {1} to {2} during the cloning operation! `n`r" -f $VMObject.Name,$VMObject.HardwareProfile.VmSize,$VMSize) -ForegroundColor Black -BackgroundColor Green
                        $ConfigStatus.Size = $VMSize
                        $newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id -Tags $VMObject.Tags -Debug:$false
                    }
                    Else {$newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMObject.HardwareProfile.VmSize -AvailabilitySetId $AvailabilitySet.Id -Tags $VMObject.Tags -Debug:$false}
                }
                Else {Return}
            }
            # Checks that this is an AVSet removal
            ElseIf ($RemoveAvailabilitySet) {
                If ([System.String]::IsNullOrEmpty($VMObject.AvailabilitySetReference.Id)){
                    # Does NOT process VM(s) not in an AVSet
                    Show-Menu -Title ("{0} is not part of an Availability Set and will not be processed." -f $VMObject.Name) -DisplayOnly -Style Info -Color Red
                    Return
                }
                Else {
                    Show-Menu -Title ("{0} is associated with {1} Availability Set and will be removed" -f $VMObject.Name,($VMObject.AvailabilitySetReference.Id -Split "/")[-1]) -DisplayOnly -Style Info -Color Cyan
                    If ($Force -or $PSCmdlet.ShouldProcess("$($VMObject.Name)","Virtual Machine removal from Availability Set [$CurrentAvailabilitySetName]")) {
                        If ($Resize) {
                            # Getting possible sizes from Location
                            $VMSize = Select-AzVMSize -ResourceGroupName $VMObject.ResourceGroupName -Location $VMObject.Location    
                            # Create new VM Object with new size
                            Write-Host ("`n`r [{0}] Virtual Machine will be resized from {1} to {2} during the cloning operation! `n`r" -f $VMObject.Name,$VMObject.HardwareProfile.VmSize,$VMSize) -ForegroundColor Black -BackgroundColor Green
                            $ConfigStatus.Size = $VMSize
                            $newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMSize -Tags $VMObject.Tags -Debug:$false
                        }
                        Else {$newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMObject.HardwareProfile.VmSize -Tags $VMObject.Tags -Debug:$false}
                    }
                    Else {Return}
                }
            }
            # If no other conditions exist, the VM(s) are cloned 'AS-IS'
            Else {
                If ([System.String]::IsNullOrEmpty($VMObject.AvailabilitySetReference.Id)){
                    Show-Menu -Title ("{0} is NOT part of an Availability Set" -f $VMObject.Name) -DisplayOnly -Style Info -Color Yellow
                    # Continuation prompt asking to remove the AVSet from the configuration for the VM
                    If ($Force -or $PSCmdlet.ShouldProcess("$($VMObject.Name)","Clone the Virtual Machine 'AS IS'")) {
                        If ($Resize) {
                            # Getting possible sizes from Location
                            $VMSize = Select-AzVMSize -ResourceGroupName $VMObject.ResourceGroupName -Location $VMObject.Location    
                            # Create new VM Object with new size
                            Write-Host ("`n`r [{0}] Virtual Machine will be resized from {1} to {2} during the cloning operation! `n`r" -f $VMObject.Name,$VMObject.HardwareProfile.VmSize,$VMSize) -ForegroundColor Black -BackgroundColor Green
                            $ConfigStatus.Size = $VMSize
                            $newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMSize -Tags $VMObject.Tags -Debug:$false
                        }
                        Else {$newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMObject.HardwareProfile.VmSize -Tags $VMObject.Tags -Debug:$false}
                    }
                    Else {Return}
                }
                Else {
                    Show-Menu -Title ("{0} IS associated with {1} Availability Set (NO CHANGE)" -f $VMObject.Name,($VMObject.AvailabilitySetReference.Id -Split "/")[-1]) -DisplayOnly -Style Info -Color Magenta
                    If ($Force -or $PSCmdlet.ShouldProcess("$($VMObject.Name)","Clone the Virtual Machine 'AS IS'")) {
                        If ($Resize) {
                            # Create new VM Object with new size
                            $VMSize = Select-AzVMSize -ResourceGroupName $VMObject.ResourceGroupName -AvailabilitySetName $AvailabilitySet.Name
                            Write-Host ("`n`r [{0}] Virtual Machine will be resized from {1} to {2} during the cloning operation! `n`r" -f $VMObject.Name,$VMObject.HardwareProfile.VmSize,$VMSize) -ForegroundColor Black -BackgroundColor Green
                            $ConfigStatus.Size = $VMSize
                            $newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id -Tags $VMObject.Tags -Debug:$false
                        }
                        Else {$newVMConfig = New-AzVMConfig -VMName $VMObject.Name -VMSize $VMObject.HardwareProfile.VmSize -AvailabilitySetId $VMObject.AvailabilitySetReference.Id -Tags $VMObject.Tags -Debug:$false}
                    }
                    Else {Return}
                }
            }

            # Check OS from OSDisk and set OSDisk object
            Switch ($VMObject.StorageProfile.OsDisk.OsType) {
                "Windows" {
                    Set-AzVMOSDisk -VM $newVMConfig -Name $VMObject.StorageProfile.OsDisk.Name -Caching $VMObject.StorageProfile.OsDisk.Caching -CreateOption Attach -Windows -ManagedDiskId $VMObject.StorageProfile.OsDisk.ManagedDisk.Id -Debug:$false | Out-Null
                    # Used for Hybrid Use Benefit
                    $newVMConfig.LicenseType = "Windows_Server"
                    $ConfigStatus.OsDisk = $true
                }
                "Linux" {
                    Set-AzVMOSDisk -VM $newVMConfig -Name $VMObject.StorageProfile.OsDisk.Name -Caching $VMObject.StorageProfile.OsDisk.Caching -CreateOption Attach -Linux -ManagedDiskId $VMObject.StorageProfile.OsDisk.ManagedDisk.Id -Debug:$false | Out-Null
                    $ConfigStatus.OsDisk = $true
                }
            }

            # Add data disks if they exist
            Foreach ($Datadisk in $VMObject.StorageProfile.DataDisks) {
                If ($Datadisk.ManagedDisk) {
                    Add-AzVMDataDisk -VM $newVMConfig -Name $Datadisk.Name -Caching $Datadisk.Caching -ManagedDiskId $Datadisk.ManagedDisk.Id -DiskSizeInGB $Datadisk.DiskSizeGB -Lun $Datadisk.Lun -CreateOption Attach -Debug:$false | Out-Null
                    $ConfigStatus.DataDisks = $true
                }
                Else {
                    Add-AzVMDataDisk -VM $newVMConfig -Name $Datadisk.Name -Caching $Datadisk.Caching -DiskSizeInGB $Datadisk.DiskSizeGB -Lun $Datadisk.Lun -CreateOption Attach -Debug:$false | Out-Null
                    $ConfigStatus.DataDisks = $true
                }
            }

            # Add network interfaces
            foreach ($vNic in $VMObject.NetworkProfile.NetworkInterfaces) {
                If ($vNic.Primary) {
                    Add-AzVMNetworkInterface -VM $newVMConfig -Id $vNic.Id -Primary -Debug:$false | Out-Null
                    $ConfigStatus.Network = $true
                }
                Else {
                    Add-AzVMNetworkInterface -VM $newVMConfig -Id $vNic.Id -Debug:$false | Out-Null
                    $ConfigStatus.Network = $true
                }
            }

            # Add vm plan information
            If ($VMObject.Plan) {
                Set-AzVMPlan -VM $newVMConfig -Name $VMObject.Plan.Name -Product $VMObject.Plan.Product -PromotionCode $VMObject.Plan.PromotionCode -Publisher $VMObject.Plan.Publisher
                $ConfigStatus.Plan = $true
            }

            # Add boot diagnostics
            If ($VMObject.DiagnosticsProfile.BootDiagnostics.Enabled -eq $true) {
                $StorageAccount = ($VMObject.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("."))[0].SubString(8)
                Set-AzVMBootDiagnostic -VM $newVMConfig -Enable -ResourceGroupName $VMObject.ResourceGroupName -StorageAccountName $StorageAccount -Debug:$false | Out-Null
                $ConfigStatus.BootDiagnostics = $true
            }

            <# Place holder for possible addition for extension configuration cloning #>
            
            # Displays the cloning configuration status based on the components that were added to the configuration
            $Banner = @"

-------------------------------
Virtual Machine Clone Status
-------------------------------
Name:              $($ConfigStatus.VMName)
OS:                $($ConfigStatus.OS)
Size:              $($ConfigStatus.Size) [Resize: $Resize]
Availability Set:  $CurrentAvailabilitySetName --> $AvailabilitySetName
OSDisk:            $($ConfigStatus.OSDisk)
DataDisks:         $($ConfigStatus.DataDisks)
Network:           $($ConfigStatus.Network)
Plan:              $($ConfigStatus.Plan)
Boot Diagnostics:  $($ConfigStatus.BootDiagnostics)
Extensions:        $($ConfigStatus.Extensions)

"@

            Show-Menu -Title $banner -DisplayOnly -Style Mini -Color Yellow
            Write-Host "`n`r"
            Show-Menu -Title "IF YOU CONTINUE, THE VM WILL BE DELETED AND RECREATED USING THE ABOVE CONFIGURATION!!" -DisplayOnly -Style Full -Color Red
            
            # Continuation prompt asking DELETE and RE-CREATE the VM(s) using the cloned configuration
            If ($PSCmdlet.ShouldProcess($VMObject.Name,"Clone Virtual Machine")) {
                Write-Verbose ("Converting VMObject to JSON for reference and backup (in the current directory)")
                $VMObject | ConvertTo-Json | Out-File ("{0}_AzVMClone_{1}.json" -f $VMObject.Name,(Get-Date -Format yyyyMMdd))
                Write-Host ("`n`r[{0}] Removing the Virtual Machine (long running operation)" -f $VMObject.Name) -NoNewline -ForegroundColor Magenta
                # VM removal in a background job - monitored for completion and received for status
                $jobRemove = Remove-AzVM -ResourceGroupName $VMObject.ResourceGroupName -Name $VMObject.Name -Force -AsJob
                While ($jobRemove.State -eq "Running") {
                    Write-Host (".") -NoNewline
                    Start-Sleep -Seconds 3
                }
                $jobDetails = $jobRemove | Receive-Job
                If ($jobRemove.State -eq "Completed" -and $jobDetails.Status -eq "Succeeded") {
                    Write-Host ("DONE!") -BackgroundColor Green -ForegroundColor Black
                    Write-Host ("[{0}] Removing Virtual Machine - JOB: {1} | TASK: {2} | TIME: {3:N2} minutes" -f $VMObject.Name,$jobRemove.State,$jobDetails.Status,($jobDetails.EndTime - $jobDetails.Starttime).TotalMinutes) -ForegroundColor Green
                    Write-Host ("`n`r[{0}] Cloning Virtual Machine" -f $VMObject.Name) -NoNewline -ForegroundColor Cyan
                    # VM creation in a background job - monitored for completion and received for status
                    $jobCreate = New-AzVM -ResourceGroupName $VMObject.ResourceGroupName -Location $VMObject.Location -VM $newVMConfig -DisableBginfoExtension -AsJob
                    While ($jobCreate.State -eq "Running") {
                        Write-Host (".") -NoNewline
                        Start-Sleep -Milliseconds 2750
                    }
                    $jobDetails = $jobCreate | Receive-Job
                    If ($jobCreate.State -eq "Completed" -and $jobDetails.StatusCode -eq "OK") {
                        Write-Host ("DONE!") -BackgroundColor Green -ForegroundColor Black
                        Write-Host ("[{0}] Cloning Virtual Machine - JOB: {1} | TASK: {2} | TIME: {3:N2} minutes" -f $VMObject.Name,$jobCreate.State,$jobDetails.StatusCode,($jobCreate.PSEndTime - $jobCreate.PSBeginTime).TotalMinutes) -ForegroundColor Green
                    }
                    Else {
                        Write-Host ("FAILED!") -BackgroundColor Red -ForegroundColor White
                        Write-Host ("[{0}] Cloning Virtual Machine - JOB: {1} | TASK: {2} | TIME: {3:N2} minutes" -f $VMObject.Name,$jobCreate.State,$jobDetails.StatusCode,($jobCreate.PSEndTime - $jobCreate.PSBeginTime).TotalMinutes) -ForegroundColor Red
                    }
                }
                Else {
                    Write-Host ("FAILED!") -BackgroundColor Red -ForegroundColor White
                    Write-Host ("[{0}] Removing Virtual Machine - JOB: {1} | TASK: {2} | TIME: {3:N2} minutes" -f $VMObject.Name,$jobRemove.State,$jobDetails.Status,($jobDetails.EndTime - $jobDetails.StartTime).TotalMinutes) -ForegroundColor Red
                }
            }
            Else {Return}
        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
    }
}