<#############################################################################
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
function New-ScsmPxObject {
    [CmdletBinding(DefaultParameterSetName='FromClassObjectAndManagementGroupConnection',SupportsShouldProcess=$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FromClassObjectAndManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FromClassObjectAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPackClass]
        $Class,

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromClassNameAndManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromClassNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ClassName,

        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('PropertyValues')]
        [System.Collections.Hashtable]
        $Property,

        [Parameter(ParameterSetName='FromClassObjectAndManagementGroupConnection')]
        [Parameter(ParameterSetName='FromClassNameAndManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(Mandatory=$true, ParameterSetName='FromClassObjectAndComputerName')]
        [Parameter(Mandatory=$true, ParameterSetName='FromClassNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(ParameterSetName='FromClassObjectAndComputerName')]
        [Parameter(ParameterSetName='FromClassNameAndComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            $outBuffer = $null
            if ($PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and ($Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                $PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > $null
            }

            #endregion

            #region Look up the command being proxied.

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('New-SCClassInstance', [System.Management.Automation.CommandTypes]::Cmdlet)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not $wrappedCmd) {
                [System.String]$message = $PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList ($message -f 'New-SCClassInstance')
                $exception.CommandName = 'New-SCClassInstance'
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'New-SCClassInstance'
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }

            #endregion

            #region Identify the class that will be used in the query.

            switch -regex ($PSCmdlet.ParameterSetName) {
                '^FromClassObject' {
                    # Nothing to do in this case
                    break
                }
                '^FromClassName' {
                    # This parameter set allows for easy lookup using a class name. It facilitates working
                    # with SCSM data when you don't need to actually access the class object itself.
                    $remotingParameters = @{}
                    foreach ($remotingParameterName in @('SCSession','ComputerName','Credential')) {
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($remotingParameterName)) {
                            $remotingParameters[$remotingParameterName] = $PSCmdlet.MyInvocation.BoundParameters.$remotingParameterName
                        }
                    }
                    $PSCmdlet.MyInvocation.BoundParameters['Class'] = $Class = Get-SCClass -Name $ClassName @remotingParameters
                    $PSCmdlet.MyInvocation.BoundParameters.Remove('ClassName') > $null
                    break
                }
                default {
                    throw 'This should never happen.'
                }
            }

            #endregion

            #region Identify key properties, required properties, and create a property map.

            $keyProperties = @()
            $requiredProperties = @()
            $propertyMap = @{}
            foreach ($classItem in @($Class) + @($Class.GetBaseTypes())) {
                foreach ($propertyItem in $classItem.PropertyCollection) {
                    if ($propertyItem.Key) {
                        $keyProperties += $propertyItem.Name
                    } elseif ($propertyItem.Required) {
                        $requiredProperties += $propertyItem.Name
                    }
                    $propertyMap[$propertyItem.Name] = $propertyItem
                }
            }

            #endregion

            #region If a key property was not provided in the Property table, throw an error.

            foreach ($propertyName in $keyProperties) {
                if (-not $Property.ContainsKey($propertyName)) {
                    [System.String]$message = "Property '${propertyName}' was not found. Property '${propertyName}' is a primary key property and must be included in the Property parameter."
                    [System.Management.Automation.PropertyNotFoundException]$exception = New-Object -TypeName System.Management.Automation.PropertyNotFoundException -ArgumentList $message
                    [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'MissingPrimaryKeyPropertyException',([System.Management.Automation.ErrorCategory]::InvalidData),'New-ScsmPxObject'
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }

            #endregion

            #region If a required property was not provided in the Property table, throw an error.

            foreach ($propertyName in $requiredProperties) {
                if (-not $Property.ContainsKey($propertyName)) {
                    [System.String]$message = "Property '${propertyName}' was not found. Property '${propertyName}' is a required property and must be included in the Property parameter."
                    [System.Management.Automation.PropertyNotFoundException]$exception = New-Object -TypeName System.Management.Automation.PropertyNotFoundException -ArgumentList $message
                    [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'MissingRequiredPropertyException',([System.Management.Automation.ErrorCategory]::InvalidData),'New-ScsmPxObject'
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }

            #endregion

            #region Convert the properties that were passed in into their appropriate types (unboxing).

            foreach ($propertyName in @($Property.Keys)) {
                if ($propertyMap[$propertyName].SystemType -eq [System.Enum]) {
                    $propertyType = [Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration]
                } else {
                    $propertyType = $propertyMap[$propertyName].SystemType
                }
                $Property[$propertyName] = $Property[$propertyName] -as $propertyType
                # If a property value will not properly convert to the expected type, throw an error
                if ($Property[$propertyName] -eq $null) {
                    [System.String]$message = "Failed to convert the value provided for property '$propertyName' to type '${propertyType}'. The value provided for property '${propertyName}' must be compatible with type '${propertyType}' in order to create this object."
                    [System.Management.Automation.PSInvalidCastException]$exception = New-Object -TypeName System.Management.Automation.PSInvalidCastException -ArgumentList $message
                    [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'InvalidTypeException',([System.Management.Automation.ErrorCategory]::InvalidType),'New-ScsmPxObject'
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }

            #endregion

            #region Create the proxy command script block.

            $scriptCmd = {& $wrappedCmd @PSBoundParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)

            #endregion
        } catch {
            throw
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            $steppablePipeline.Process($_)

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            $steppablePipeline.End()

            #endregion
        } catch {
            throw
        }
    }
}

Export-ModuleMember -Function New-ScsmPxObject