# Clone Azure Virtual Machine (Az.CloneVirtualMachine)

> #### WARNING: 
> This module contains a destructive function, but is safe guarded with continuation prompts allowing the operator to cancel execution.
___
## Overview
This module will install a function called *New-AzVMClone*.  The function will allow a user migrate to **OR** remove an Azure Virtual Machine from an Availability Set.  This process is most commonly used when Azure Virtual Machines are inadvertently placed into incorrect Availability Sets.  This code was developed to fill a gap because Azure does not provide a way to remove a Virtual Machine from an Availability Set or move a Virtual Machine to a new Availability Set.

---

### Configuration Components
#### CLONED
- VM Name
- VM Size
- OS
- Tags
- OS Disks
- Data Disks (*all*) 
- Network Interfaces (*all*)
- Boot Diagnostics

#### NOT CLONED
- Extensions (*may be included in a future release*)

---

## Module Functions
> ``New-AzVMClone`` : This is the primary function used to migrate **OR** remove a VM from an Availability Set

## Requirements
This function requires PowerShell 5.1 or higher on Windows.

To check your version of PowerShell run:

>``$PSVersionTable.PSVersion``

This function also requires the Azure PowerShell Module and the installation instructions can be found [here](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-2.7.0).

> #### WARNING: 
> You can't have both the AzureRM and Az modules installed for PowerShell 5.1 for Windows at the same time.  The troubleshooting section will outline how to remove the older module.

This Module requires that the correct Virtual Machine object type is passed through the pipeline or from the parameter

- ``Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine``
- ``Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList``
        
#### Verify ObjectType

![Figure10](1.4/Media/figure10_verify_object_type.png)

## Installation
The preferred method of installation is to *install* the module from the PowerShell Gallery for the active user.

>``Install-Module -Name Az.CloneVirtualMachine -AllowClobber -Scope CurrentUser``

If you want to install the module for all users, this requires administrative privileges.  Be sure to start PowerShell as an Administrator.

>``Install-Module -Name Az.CloneVirtualMachine -AllowClobber -Scope AllUsers``

By default, the PowerShell gallery isn't configured as a trusted repository for PowerShellGet. The first time you use the PSGallery you see the following prompt:

    Untrusted repository
    
    You are installing the modules from an untrusted repository. If you trust this repository, change its InstallationPolicy value by running the Set-PSRepository cmdlet.
    
    Are you sure you want to install the modules from 'PSGallery'?
    [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"):

The ``Install-Module`` command will install the module files on the machine, but the module will need to be imported into your PowerShell session.

>``Import-Module Az.CloneVirtualMachine``

## Module Updates

This module is maintained in the PowerShell Gallery and is updated to fix bugs or introduce new features.  Updating the module is a manual process outlined below:

### Determine what version is the latest release
>``Find-Module -Name Az.CloneVirtualMachine -AllVersions``

![Figure1](/1.4/Media/figure1_findmodule_allversions.png)

### Verify what version is currently installed
>``Get-Module -Name Az.CloneVirtualMachine -ListAvailable``

![Figure2](/1.4/Media/figure2_getmodule_listavailable.png)

### Uninstall the module

>*Requires PowerShell Run As Administrator*
>
>``Uninstall-Module -Name Az.CloneVirtualMachine``

![Figure3](/1.4/Media/figure3_uninstall_module.png)

### Install the latest version

Installing the module only makes the module files available to be imported into the PowerShell session.

>``Install-Module -Name Az.CloneVirtualMachine -RequiredVersion 1.4 -Scope CurrentUser``

![Figure4](1.4/Media/figure4_installmodule_requiredversion.png)

### Import the updated module to PowerShell

Using ``Import-Module`` will make the commands available from within the PowerShell session (and future sessions).

>``Import-Module -Name Az.CloneVirtualMachine``

![Figure5](1.4/Media/figure5_importmodule.png)

## Troubleshooting

The below items should fix most of the common issues found during installation, updating, or using the module.

### PowerShell Execution Policy

Depending on your organization, you may have a more restrictive PowerShell Execution Policy.  

![Figure6](1.4/Media/figure6_importmodule_EP_restricted.png)

It is recommended to set the PowerShell Execution Policy to ByPass temporarialy to be able to install the module.

>*Requires PowerShell Run As Administrator*
>
>``Set-ExecutionPolicy -ExecutionPolicy ByPass``

![Figure7](1.4/Media/figure7_setexecutionpolicy_bypass.png)

### Error: Invalid Azure Powershell module is installed (AzureRM)

If the legacy AzureRM module is still part of your PowerShell session, the function will throw the below error.

![Figure8](1.4/Media/figure8_error_invalid_module.png)

The AzureRM module must be uninstalled to prevent conflict

>*Requires PowerShell Run As Administrator*
>
>``Uninstall-AzureRm``

Removing the module rather than **uninstalling** will produce the following **WARNING** and **ERROR**

![Figure9](1.4/Media/figure9_error_azurerm_profile.png)
___
## Getting Help
The function has comment based help and will provide examples of how to use it.

> ``Get-Help New-AzVMClone -Full``
>
> ``Get-Help New-AzVMClone -Detailed``
>
> ``Get-Help New-AzVMClone -Examples``

## Requirements
- This Module requires the Az PowerShell module and will **NOT** work with AzureRM cmdlets
- This Module requires that the correct Virtual Machine object type is passed through the pipeline or from the parameter
    - ``Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine``
    - ``Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList``
        
        > ### Verify ObjectType
        > ``$myVM = Get-AzVM -ResourceGroupName TestRG -Name TestVM``
        >
        > `` $myVM | Get-Member``
        
            [PS] C:\WINDOWS\system32>$myVM | Get-Member

           ----> TypeName: Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine  <----

            Name                     MemberType Definition
            ----                     ---------- ----------
            Equals                   Method     bool Equals(System.Object obj)
            GetHashCode              Method     int GetHashCode()
            GetType                  Method     type GetType()
            ToString                 Method     string ToString()
            AdditionalCapabilities   Property   Microsoft.Azure.Management.Compute.Models.AdditionalCapabilities AdditionalCapab...
            AvailabilitySetReference Property   Microsoft.Azure.Management.Compute.Models.SubResource AvailabilitySetReference {...
            DiagnosticsProfile       Property   Microsoft.Azure.Management.Compute.Models.DiagnosticsProfile DiagnosticsProfile ...
            DisplayHint              Property   Microsoft.Azure.Commands.Compute.Models.DisplayHintType DisplayHint {get;set;}
            Extensions               Property   System.Collections.Generic.IList[Microsoft.Azure.Management.Compute.Models.Virtu...
            FullyQualifiedDomainName Property   string FullyQualifiedDomainName {get;set;}
            HardwareProfile          Property   Microsoft.Azure.Management.Compute.Models.HardwareProfile HardwareProfile {get;s...
            Id                       Property   string Id {get;set;}
            Identity                 Property   Microsoft.Azure.Management.Compute.Models.VirtualMachineIdentity Identity {get;s...
            InstanceView             Property   Microsoft.Azure.Management.Compute.Models.VirtualMachineInstanceView InstanceVie...
            LicenseType              Property   string LicenseType {get;set;}
            Location                 Property   string Location {get;set;}
            Name                     Property   string Name {get;set;}
            NetworkProfile           Property   Microsoft.Azure.Management.Compute.Models.NetworkProfile NetworkProfile {get;set;}
            OSProfile                Property   Microsoft.Azure.Management.Compute.Models.OSProfile OSProfile {get;set;}
            Plan                     Property   Microsoft.Azure.Management.Compute.Models.Plan Plan {get;set;}
            ProvisioningState        Property   string ProvisioningState {get;set;}
            ProximityPlacementGroup  Property   Microsoft.Azure.Management.Compute.Models.SubResource ProximityPlacementGroup {g...
            RequestId                Property   string RequestId {get;set;}
            ResourceGroupName        Property   string ResourceGroupName {get;}
            StatusCode               Property   System.Net.HttpStatusCode StatusCode {get;set;}
            StorageProfile           Property   Microsoft.Azure.Management.Compute.Models.StorageProfile StorageProfile {get;set;}
            Tags                     Property   System.Collections.Generic.IDictionary[string,string] Tags {get;set;}
            Type                     Property   string Type {get;set;}
            VmId                     Property   string VmId {get;set;}
            Zones                    Property   System.Collections.Generic.IList[string] Zones {get;set;}
