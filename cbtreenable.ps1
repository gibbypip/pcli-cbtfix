#This PowerShell Script will login to a vCenter Server, query for VM's that have CBT disabled
#as long as they're not Templates and vShield Edge devices, and will return a list of VMs (if found) to
#be selected to enable CBT automatically. PowerCLI code via VMware KB1031873.
#
# Author: Gibby|
# version: v.9
# Disclaimer: use at your own risk. Not liable for any issues.

#Get PowerCLI stuffs
Add-PSSnapin VMware.VimAutomation.Core 

#Ignore vCenter cert errors
Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false

$VISERVER= Read-Host 'Enter vCenter Server FQDN'
Connect-VIServer $VISERVER

do {
$global:i=0
#Get CBT disabled VM's and list them
Get-View -ViewType VirtualMachine -Filter @{"name" = "^(?!vse-).*$"; "Config.Template" = "false"} | Where-Object {$_.Config.ChangeTrackingEnabled -eq $false } | Select-Object Name |  Select @{Name="Item";Expression={$global:i++;$global:i}}, Name -outVariable menu | format-table -auto 
    if (-not $menu) {"All VM's have CBT enabled. Exiting..."}
    else {
        #verify input from user is numarical
        do {
            try { 
                $numOK = $true
                [int]$r = Read-Host "Select a VM to Enable CBT by number"
                }
            catch {$numOK = $false}
        }
        until (($r -ge 1 -and $r -lt 100) -and $numOK)
        #end number validation

        $cbtvm = $menu | where {$_.item -eq $r}
        Write-Host "Renabling CBT on $($cbtvm.name)"

        $vmtest = Get-vm $cbtvm.name| get-view
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

        $vmConfigSpec.changeTrackingEnabled = $false
        $vmtest.reconfigVM($vmConfigSpec)
        $snap=New-Snapshot $cbtvm.name -Name "Disable CBT"
        $snap | Remove-Snapshot -confirm:$false
        Write-Host "50% Complete"

        # enable ctk
        $vmConfigSpec.changeTrackingEnabled = $true
        $vmtest.reconfigVM($vmConfigSpec)
        $snap=New-Snapshot $cbtvm.name -Name "Enable CBT"
        $snap | Remove-Snapshot -confirm:$false 
        Write-Host "100% Complete"
        Set-Variable -name "i" -value "0" -Scope Global
        }
    } until (-not $menu)     