﻿<#############################################################################
The ScsmPx module facilitates automation with Microsoft System Center Service
Manager by auto-loading the native modules that are included as part of that
product and enabling automatic discovery of the commands that are contained
within the native modules. It also includes dozens of complementary commands
that are not available out of the box to allow you to do much more with your
PowerShell automation efforts using the platform.

Copyright (c) 2014 Provance Technologies.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License in the
license folder that is included in the ScsmPx module. If not, see
<https://www.gnu.org/licenses/gpl.html>.
#############################################################################>

# .ExternalHelp ScsmPx-help.xml
function Reset-ScsmPxCommandCache {
    [CmdletBinding()]
    param()
    try {
        if ($PSVersionTable.PSVersion -ge [System.Version]'3.0') {
            Get-Module -ListAvailable -Name ScsmPx -Refresh > $null
        } else {
            Write-Warning 'Reset-ScsmPxCommandCache is only necessary in PowerShell version 3.0 and later.'
        }
    } catch {
        throw
    }
}

Export-ModuleMember -Function Reset-ScsmPxCommandCache