# Clone Azure Virtual Machine (Az.CloneVirtualMachine)
## Overview
This module will install a function called *New-AzVMClone*.  The function will allow a user migrate to **OR** remove an Azure Virtual Machine from an Availability Set.  This process is mostly commonly used when Azure Virtual Machines are inadvertently placed into incorrect Availability Sets.  At the time, this code was developed Azure did not provide a way to remove a Virtual Machine from an Availability Set or could you move a Virtual Machine to a new Availability Set.

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
- The function requires that the correct Virtual Machine object type is passed through the pipeline or from the parameter
    - ``Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine``
    - ``Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList``
