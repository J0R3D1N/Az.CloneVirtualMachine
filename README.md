# Clone Azure Virtual Machine (Az.CloneVirtualMachine)
> #### WARNING: This is a destructive function, but is safe guarded with continuation prompts.
## Overview
This module will install a function called *New-AzVMClone*.  The function will allow a user migrate to **OR** remove an Azure Virtual Machine from an Availability Set.  This process is mostly commonly used when Azure Virtual Machines are inadvertently placed into incorrect Availability Sets.  At the time, this code was developed Azure did not provide a way to remove a Virtual Machine from an Availability Set or could you move a Virtual Machine to a new Availability Set.

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
> ``Show-Menu`` : This is a function used to provide readable screen output
>
> ``New-AzVMClone`` : This is the primary function used to migrate **OR** remove a VM from an Availability Set

## Installation
The preferred method of installation is to *install* the module from the PowerShell Gallery.

>``Find-Module Az.CloneVirtualMachine | Install-Module -Force``

Once the module is installed, simply import the module

>``Import-Module Az.CloneVirtualMachine``

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
