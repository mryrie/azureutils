<#
.SYNOPSIS
Creates snapshots of all VMs

.DESCRIPTION
Iterates through all VMs in a subscription and makes snapshots of all of them into the specified RG

.PARAMETER resourceGroupName
The name of the resource group to create snapshots in

.EXAMPLE
New-MRAZSnapshots -resourceGroupName 'production'

.NOTES
General notes
#>
function New-MRAZSnapshots {

    param (
        [Parameter(Mandatory=$true)]
        [string]$resourceGroupName
    )

    #$resourceGroupName = 'production' 
    #$location = 'centralus' 
    
    #New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

    #shut down the VMs
    $VMs = Get-AzVm
    $VMs | Stop-AzVM -Force
    
    foreach ($vm in $VMs){
        $osSnapshotConfig = New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $vm.Location -CreateOption copy
        New-AzSnapshot -SnapshotName ($vm.StorageProfile.OsDisk.Name + "-snap") -Snapshot $osSnapshotConfig -ResourceGroupName $resourceGroupName
        
        foreach ($dataDiskId in $vm.StorageProfile.DataDisks.ManagedDisk.Id){
            $dataSnapshotConfig = New-AzSnapshotConfig -SourceUri $dataDiskId -Location $vm.location -CreateOption copy
            New-AzSnapshot -SnapshotName ($dataDiskId.Split("/")[-1] + "-snap") -Snapshot $dataSnapshotConfig -ResourceGroupName $resourceGroupName
        }
    }
}

function Copy-MRAZSnapshots {

    param (
        [Parameter(Mandatory=$true)]
        [string]$resourceGroupName,
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Commands.Common.Storage.LazyAzureStorageContext]$storageContext,
        [string]$azStorageContainerName="migrate"
    )

    #hardcode the SAS expiration to 10 hours for now
    $sasExpiryDuration = "36000"

    #check if the appropriate storage container exists, if not, create it
    If ($null -eq (Get-AzStorageContainer -Context $storageContext -Name $azStorageContainerName -ErrorAction SilentlyContinue)){
        New-AzStorageContainer -Context $storageContext -Name $azStorageContainerName
    }

    foreach ($snap in Get-AzSnapshot -ResourceGroupName $resourceGroupName){
        $sas = $snap | Grant-AzSnapshotAccess -DurationInSecond $sasExpiryDuration -Access Read
        Start-AzStorageBlobCopy -DestContext $storageContext -AbsoluteUri $sas.AccessSAS -DestContainer $azStorageContainerName -DestBlob $snap.Name
    }
}

#Create disks from snapshots
function New-MRAZDisksFromVHDs {

    param (
        [Parameter(Mandatory=$true)]
        [string]$resourceGroupName,
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Commands.Common.Storage.LazyAzureStorageContext]$storageContext,
        [string]$azStorageContainerName="migrate"
    )

    foreach ($blob in (Get-AzStorageBlob -Context $storageContext -Container $azStorageContainerName)){
        New-AzDisk -DiskName $blob.Name.Replace(".vhd", "")
    }
}


$diskName = 'azdc01-os'
$resourceGroup = 'production'
$location = 'South Central US'

$diskconfig = New-AzDiskConfig -Location $location -SkuName Standard_LRS -OsType Windows -CreateOption Upload -UploadSizeInBytes 34359738880
New-AzDisk -ResourceGroupName $resourceGroup -DiskName $diskName -Disk $diskconfig
$diskSas = Grant-AzDiskAccess -ResourceGroupName $resourceGroup -DiskName $diskName -DurationInSecond 86400 -Access 'Write'
#$disk = Get-AzDisk -ResourceGroupName $resourceGroup 'ResourceGroup01' -DiskName $diskName
# $disk.DiskState == 'ReadyToUpload'

AzCopy /Source:https://propetromigrate.blob.core.windows.net/migrate/azdc01_DataDisk_0-snap /Dest:$diskSas
#$disk = Get-AzDisk -ResourceGroupName 'ResourceGroup01' -DiskName 'Disk01'
# $disk.DiskState == 'ActiveUpload'
Revoke-AzDiskAccess -ResourceGroupName $resourceGroup -DiskName $diskName