Enum SPSRegistryVersion {
    V4 = 4
    V5 = 5
}
Enum SPSRegistryHive {
    HKEY_CLASSES_ROOT
    HKEY_CURRENT_USER
    HKEY_LOCAL_MACHINE
    HKEY_USERS
    HKEY_CURRENT_CONFIG
    HKEY_PERFORMANCE_DATA
    HKEY_DYN_DATA
}
Class SPSRegValue {
    [SPSRegHive]    ${Hive}
    [SPSRegKey]     ${Key}
    [String]        ${Name}
    [String]        ${Value}
    [Boolean]       ${Delete}
    SPSRegValue(){}
    SPSRegValue([Microsoft.Win32.RegistryKey] $Key,[String]$ValueName){
        $this.Name = $ValueName
        $this.Key = $Key
        $this.Hive = $this.Key.Hive
        Try {
            $this.Value = Get-ItemPropertyValue -Path $Key.Name -Name $ValueName -ErrorAction Stop
        }Catch{
            $Message = "Unable to read value '$($ValueName)' in '$($Key.Name)': $($_.Exception.Message)"
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileFormatException]::new($Message),
                'InvalidValue',
                [System.Management.Automation.ErrorCategory]::InvalidData,
                $ValueName
            )
            throw $ErrorRecord
        }
    }
}
Class SPSRegKey {
    [SPSRegHive]                                    ${Hive}     # The Hive of the Key   
    [String]                                        ${FullName} # The Path of the Key
    [String]                                        ${Name}     # The Name of the Key
    [System.Collections.Generic.List[SPSRegKey]]    ${Keys}     # The Keys of the Key
    [System.Collections.Generic.List[SPSRegValue]]  ${Values}   # The Values of the Key
    [System.Collections.Generic.List[String]]       ${Comments} = [System.Collections.Generic.List[String]]::New() # The comment lines of the Registry (only for files).
    [System.Collections.Generic.List[String]]       ${UnknowLines} = [System.Collections.Generic.List[String]]::New() # The unknown lines of the Registry (only for files). if strict is true no unknown lines are allowed.
    [Boolean]                                       ${Delete}
    SPSRegKey(){}
    SPSRegKey([Microsoft.Win32.RegistryKey]$Key) {
        $this.Hive = [SPSRegHive]::New($Key.Name)
        $this.FullName = $Key.Name
        $this.Name = $Key.Name.Split('\') | Select-Object -Last 1
        ForEach($ChildKey in $($Key.GetSubKeyNames())){
            $SubKey = "$($this.FullName)\$($ChildKey)"
            $this.Keys.Add([SPSRegKey]::New($SubKey))
        }
        ForEach($PropertyName in $($Key.Property)){
            $this.Values.Add([SPSRegValue]::New($This.Name,$PropertyName))
        }
    }
    SPSRegKey([Microsoft.Win32.RegistryKey]$Key,[String] $Value) {
        $this.Hive = [SPSRegHive]::New($Key.Name)
        $this.FullName = $Key.Name
        $this.Name = $Key.Name.Split('\') | Select-Object -Last 1
        $this.Values.Add([SPSRegValue]::New($This.Name,$Value))
    }
}
Class SPSRegHive {
    [SPSRegistryHive]                               ${Hive} = [SPSRegistryHive]::HKEY_LOCAL_MACHINE     # The Hive of the Key
    Hidden [String]                                 ${Drive}    # The hive as a drive letter (HKLM or HKCU)
    SPSRegHive(){
        $this.__build($null)
    }
    SPSRegHive([String] $Path){
        $this.__build($Path)
    }
    [void] __build($Path) {
        if ($Null -eq $Path){
            $this.Hive = [SPSRegistryHive]::HKEY_LOCAL_MACHINE
            $this.Drive = 'HKLM' 
        }Else{
            # Read the string to extract the hive.
            # The input can be a full path or just the hive.
            # The value can be in form HKLM:\Software or HKLM: (Drive)
            # Or in form HKEY_LOCAL_MACHINE\Software or HKEY_LOCAL_MACHINE (Hive)
            # Get the first part of the path.
            $Qualifier = $Path.Split('\') | Select-Object -First 1
            # Remove the colon from the qualifier if present.
            $Qualifier = $Qualifier.Replace(':','')
            # Get the format of the qualifier. (HKLM or HKEY_LOCAL_MACHINE)
            If ($Qualifier -like 'HKEY_*'){
                # The qualifier is in the long form.
                $ValidQualifiers = [SPSRegistryHive]::GetNames([SPSRegistryHive])
                If ($Qualifier -in $ValidQualifiers){
                    # The qualifier is valid.
                    $this.__parse($Qualifier)
                }Else{
                    # The qualifier is not valid.
                    $Message = "'$($Qualifier)' is not a valid Hive. It can be one of the following: $($ValidQualifiers -join ', ')"
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.IO.FileFormatException]::new($Message),
                        'InvalidHive',
                        [System.Management.Automation.ErrorCategory]::InvalidData,
                        $Qualifier
                    )
                    Throw $ErrorRecord
                }
            }ElseIf ($Qualifier -in @('HKLM','HKCU','HKCR','HKU','HKCC','HKPD','HKDD')){
                # The qualifier is in the short form.
                $this.__parse($Qualifier)
                Switch ($Qualifier) {
                    'HKLM' {
                        $this.Hive = [SPSRegistryHive]::HKEY_LOCAL_MACHINE
                        $this.Drive = 'HKLM'
                    }
                    'HKCU' {
                        $this.Hive = [SPSRegistryHive]::HKEY_CURRENT_USER
                        $this.Drive = 'HKCU'
                    }
                    'HKCR' {
                        $this.Hive = [SPSRegistryHive]::HKEY_CLASSES_ROOT
                        $this.Drive = 'HKCR'
                    }
                    'HKU' {
                        $this.Hive = [SPSRegistryHive]::HKEY_USERS
                        $this.Drive = 'HKU'
                    }
                    'HKCC' {
                        $this.Hive = [SPSRegistryHive]::HKEY_CURRENT_CONFIG
                        $this.Drive = 'HKCC'
                    }
                    'HKPD' {
                        $this.Hive = [SPSRegistryHive]::HKEY_PERFORMANCE_DATA
                        $this.Drive = 'HKPD'
                    }
                    'HKDD' {
                        $this.Hive = [SPSRegistryHive]::HKEY_DYN_DATA
                        $this.Drive = 'HKDD'
                    }
                }
            }Else{
                # The qualifier is not valid.
                $Message = "'$($Qualifier)' is not a valid Hive. It can be one of the following: HKLM, HKCU, HKCR, HKU, HKCC, HKPD, HKDD"
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.IO.FileFormatException]::new($Message),
                    'InvalidHive',
                    [System.Management.Automation.ErrorCategory]::InvalidData,
                    $Qualifier
                )
                Throw $ErrorRecord
            }
        }
    }
    [void] __parse([String] $Qualifier) {
        Switch ($Qualifier) {
            {$_ -in @('HKEY_CLASSES_ROOT','HKCR')} {
                $this.Hive = [SPSRegistryHive]::HKEY_CLASSES_ROOT
                $this.Drive = 'HKCR'
                BREAK
            }
            {$_ -in @('HKEY_CURRENT_USER','HKCU')} {
                $this.Hive = [SPSRegistryHive]::HKEY_CURRENT_USER
                $this.Drive = 'HKCU'
                BREAK
            }
            {$_ -in @('HKEY_LOCAL_MACHINE','HKLM')} {
                $this.Hive = [SPSRegistryHive]::HKEY_LOCAL_MACHINE
                $this.Drive = 'HKLM'
                BREAK
            }
            {$_ -in @('HKEY_USERS','HKU')} {
                $this.Hive = [SPSRegistryHive]::HKEY_USERS
                $this.Drive = 'HKU'
                BREAK
            }
            {$_ -in @('HKEY_CURRENT_CONFIG','HKCC')} {
                $this.Hive = [SPSRegistryHive]::HKEY_CURRENT_CONFIG
                $this.Drive = 'HKCC'
                BREAK
            }
            {$_ -in @('HKEY_PERFORMANCE_DATA','HKPD')} {
                $this.Hive = [SPSRegistryHive]::HKEY_PERFORMANCE_DATA
                $this.Drive = 'HKPD'
                BREAK
            }
            {$_ -in @('HKEY_DYN_DATA','HKDD')} {
                $this.Hive = [SPSRegistryHive]::HKEY_DYN_DATA
                $this.Drive = 'HKDD'
                BREAK
            }
            default {
                $this.Hive = [SPSRegistryHive]::HKEY_LOCAL_MACHINE
                $this.Drive = 'HKLM'
            }
        }
    }
    [String] ToString(){
        return $this.Drive
    }
}
Class SPSRegistry{
    [SPSRegistryVersion]                            ${Version} = [SPSRegistryVersion]::V5                               # The Version of the Registry
    [System.Collections.Generic.List[SPSRegKey]]    ${Keys} = [System.Collections.Generic.List[SPSRegKey]]::New()       # The Keys of the Registry
    [System.Collections.Generic.List[String]]       ${Comments} = [System.Collections.Generic.List[String]]::New()      # The comment lines of the Registry (only for files).
    [System.Collections.Generic.List[String]]       ${UnknownLines} = [System.Collections.Generic.List[String]]::New()  # The unknown lines of the Registry (only for files). if strict is true no unknown lines are allowed.
    [System.Text.Encoding]                          ${Encoding} = [System.Text.Encoding]::Default                       # The Encoding of the Registry file
    SPSRegistry(){}
    SPSRegistry([Object]$Path){
        $this.__build($Path,$Null,$True)
    }
    SPSRegistry([Object]$Path, [Boolean]$Strict){
        $this.__build($Path,$Null,$Strict)
    }
    SPSRegistry([Object]$Path, [String] $Value){
        $this.__build($Path,$Value,$True)
    }
    SPSRegistry([Object]$Path, [String] $Value, [Boolean]$Strict){
        $this.__build($Path,$Value,$Strict)
    }
    hidden [Void] __build([Object]$Path,[String] ${Value}, [Boolean]$Strict){
        Switch ($Path) {
            {$_ -is [System.IO.FileInfo]} {
                # The input is a file (so probably a reg file).
                $This.__buildFromFile($Path,$Strict)
                BREAK
            }
            {$_ -is [Microsoft.Win32.RegistryKey]} {
                # The input is a registry key returned by Get-Item.
                if ($Null -eq $Value){
                    $This.__buildFromKey($Path)
                }Else{
                    $This.__buildFromKeyValue($Path,$Value)
                }
                BREAK
            }
            {$_ -is [String]} {
                if ((Test-Path -Path $Path -ErrorAction Ignore) -ne $True){
                    $Message = "'$($Path)' does not exist."
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.IO.FileFormatException]::new($Message),
                        'InvalidPath',
                        [System.Management.Automation.ErrorCategory]::InvalidData,
                        $Path
                    )
                    Throw $ErrorRecord
                }Else{
                    # Convert into a FileInfo or RegistryKey object using Get-Item.
                    Try {
                        $Item = Get-Item -Path $Path -ErrorAction Stop
                    }Catch{
                        $Message = "'$($Path)' cannot be reached, $($_.Exception.Message)"
                            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                                [System.IO.FileFormatException]::new($Message),
                                'InvalidPath',
                                [System.Management.Automation.ErrorCategory]::InvalidData,
                                $Path
                            )
                            Throw $ErrorRecord
                    }
                    
                    Switch ($Item) {
                        {$_ -is [System.IO.FileInfo]} {
                            # The Path is a File (so probably a reg file).
                            $This.__buildFromFile($Item,$Strict)
                            BREAK
                        }
                        {$_ -is [Microsoft.Win32.RegistryKey]} {
                            # The Path is a Registry Key.
                            if ($Null -eq $Value){
                                $This.__buildFromKey($Path)
                            }Else{
                                $This.__buildFromKeyValue($Path,$Value)
                            }
                            BREAK
                        }
                        Default {
                            # The path is neither a file nor a registry key. (can be a Cert:\ or other provider)
                            $Message = "'$($Path)' is not a valid Registry File or Registry Key."
                            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                                [System.IO.FileFormatException]::new($Message),
                                'InvalidPath',
                                [System.Management.Automation.ErrorCategory]::InvalidData,
                                $Path
                            )
                            Throw $ErrorRecord
                        }
                    }
                }
            }
            Default {
                # The path is neither a file nor a registry key. (can be a Cert:\ or other provider)
                $Message = "'$($Path)' is not a valid Registry File or Registry Key."
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.IO.FileFormatException]::new($Message),
                    'InvalidRegistryFile',
                    [System.Management.Automation.ErrorCategory]::InvalidData,
                    $Path
                )
                Throw $ErrorRecord
            }
        }
    }
    hidden [Void] __buildFromFile([System.IO.FileInfo]$File, [Boolean]$Strict){

    }
    hidden [Void] __buildFromKey([Microsoft.Win32.RegistryKey]$Key){

    }
    hidden [Void] __buildFromKeyValue([Microsoft.Win32.RegistryKey]$Key, [String]$Value, [Boolean]$Strict){

    }
}