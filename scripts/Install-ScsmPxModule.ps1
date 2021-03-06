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

# This script should only be invoked when you want to download the latest
# version of ScsmPx from the GitHub page where it is hosted.

[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='InCurrentLocation')]
[OutputType([System.Management.Automation.PSModuleInfo])]
param(
    [Parameter(ParameterSetName='ForCurrentUser')]
    [System.Management.Automation.SwitchParameter]
    $CurrentUser,

    [Parameter(ParameterSetName='ForAllUsers')]
    [System.Management.Automation.SwitchParameter]
    $AllUsers,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $PassThru
)
try {
    #region Fail fast if we are not meeting the prerequisite requirements.

    # Note, we go easy on the requirements checking so that users can install
    # the module in an environment that does not have all of the prerequisite
    # components installed, and then sneakernet the module over to a system
    # that has the requirements but that may not have internet connectivity.
    # The module itself handles prerequisite checking on the system where it
    # is loaded.
    Write-Progress -Activity 'Installing ScsmPx' -Status 'Verifying the PowerShell requirements.'
    if ($PSVersionTable.PSVersion -lt [System.Version]'3.0') {
        [System.String]$message = 'PowerShell 3.0 is required by the ScsmPx module. Install the Windows Management Framework 3.0 or later and then try again.'
        [System.Management.Automation.PSNotSupportedException]$exception = New-Object -TypeName System.Management.Automation.PSNotSupportedException -ArgumentList $message
        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'MissingPrerequisiteException',([System.Management.Automation.ErrorCategory]::NotInstalled),'Install-ScsmPxModule'
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    #endregion

    #region Identify the modules folders that may be used.

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Defining common Windows PowerShell modules folder paths.'
    $modulesFolders = @{
        CurrentUser = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments'))  -ChildPath WindowsPowerShell\Modules
           AllUsers = Join-Path -Path ([System.Environment]::GetFolderPath('ProgramFiles')) -ChildPath WindowsPowerShell\Modules
    }

    #endregion

    #region Get the currently installed module (if there is one).

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Looking for an installed ScsmPx module.'
    $module = Get-Module -ListAvailable | Where-Object {$_.Guid -eq [System.Guid]'2fb132d0-0eea-434f-9619-e8c134e12c57'}
    if ($module -is [System.Array]) {
        [System.String]$message = 'More than one version of ScsmPx (or ScsmLoader) are installed on this system. Manually remove the old versions and then try again.'
        [System.Management.Automation.SessionStateException]$exception = New-Object -TypeName System.Management.Automation.SessionStateException -ArgumentList $message
        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'SessionStateException',([System.Management.Automation.ErrorCategory]::InvalidOperation),'Install-ScsmPxModule'
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    #endregion

    #region Identify which modules folder will be used.

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Identifying the target modules folder.'
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('AllUsers') -and $AllUsers) {
        $modulesFolder = $modulesFolders.AllUsers
    } elseif ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('CurrentUser') -and $CurrentUser) {
        $modulesFolder = $modulesFolders.CurrentUser
    } elseif ($module) {
        # Grab the modules folder from the current installed location.
        $modulesFolder = $module.ModuleBase | Split-Path -Parent
    } else {
        $modulesFolder = $modulesFolders.CurrentUser
    }

    #endregion

    #region Create the modules folder and add it to PSModulePath if necessary.

    if (-not (Test-Path -LiteralPath $modulesFolder)) {
        Write-Progress -Activity 'Installing ScsmPx' -Status 'Creating modules folder.'
        New-Item -Path $modulesFolder -ItemType Directory -ErrorAction Stop > $null
    }
    if (@($env:PSModulePath -split ';') -notcontains $modulesFolder) {
        Write-Progress -Activity 'Installing ScsmPx' -Status 'Updating the PSModulePath environment variable.'
        if ($modulesFolder -match "^$([System.Text.RegularExpressions.RegEx]::Escape($env:USERPROFILE))") {
            $environmentVariableTarget = [System.EnvironmentVariableTarget]::User
        } else {
            $environmentVariableTarget = [System.EnvironmentVariableTarget]::Machine
        }
        $systemPSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath',$environmentVariableTarget) -as [System.String]
        if ($systemPSModulePath -notmatch ';$') {
            $systemPSModulePath += ';'
        }
        $systemPSModulePath += $modulesFolder
        [System.Environment]::SetEnvironmentVariable('PSModulePath',$systemPSModulePath,$environmentVariableTarget)
        if ($env:PSModulePath -notmatch ';$') {
            $env:PSModulePath += ';'
        }
        $env:PSModulePath += $modulesFolder
    }

    #endregion

    #region Download and unblock the latest release from GitHub.

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Downloading the latest version of ScsmPx.'
    $zipFilePath = Join-Path -Path $modulesFolder -ChildPath ScsmPx.zip
    $wc = New-Object -TypeName System.Net.WebClient
    $wc.DownloadFile('https://github.com/KirkMunro/ScsmPx/zipball/release',$zipFilePath)
    Unblock-File -LiteralPath $zipFilePath -ErrorAction Stop

    #endregion

    #region Extract the contents of the downloaded zip file into the modules folder.

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Extracting the ScsmPx zip file contents.'
    # Check to see if we have the System.IO.Compression.FileSystem assembly installed.
    # This comes as part of .NET 4.5 and later.
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    } catch {
    }
    if ('System.IO.Compression.ZipFile' -as [System.Type]) {
        # If we have .NET 4.5 installed, use the ExtractToDirectory static method
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $modulesFolder)
    } else {
        # Otherwise, use the CopyHere COM method (this is significantly slower)
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($zipFilePath)
        foreach($item in $zip.items()) {
            $shell.Namespace($modulesFolder).CopyHere($item)
        }
    }

    #endregion

    #region Remove the downloaded zip file.

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Removing the ScsmPx zip file.'
    Remove-Item -LiteralPath $zipFilePath

    #endregion

    #region Remove the old version (if one was installed).

    if ($module) {
        Write-Progress -Activity 'Installing ScsmPx' -Status 'Unloading and removing the installed ScsmPx module.'
        # Unload the module if it is currently loaded.
        if ($loadedModule = Get-Module | Where-Object {$_.Guid -eq $module.Guid}) {
            $loadedModule | Remove-Module -ErrorAction Stop
        }
        # Remove the currently installed module.
        Remove-Item -LiteralPath $module.ModuleBase -Recurse -Force -ErrorAction Stop
    }

    #endregion

    #region Rename the extracted zip file contents folder as the module name.

    Write-Progress -Activity 'Installing ScsmPx' -Status 'Installing the new ScsmPx module.'
    Join-Path -Path $modulesFolder -ChildPath KirkMunro-ScsmPx-* `
        | Get-Item `
        | Sort-Object -Property LastWriteTime -Descending `
        | Select-Object -First 1 `
        | Rename-Item -NewName ScsmPx

    #endregion

    #region Now return the updated module to the caller if they requested it.

    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
        Get-Module -ListAvailable -Name ScsmPx
    }

    #endregion
} catch {
    throw
}