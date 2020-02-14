Connect-AzAccount

#List CSP subscriptions that we have access to
$customers = Get-PartnerCustomer

$customerRecords = @()

$i = 0

foreach ($customer in $customers){

  $i+=1
  Write-Progress -Activity 'Querying CSP customers' -Status $customer.Name -PercentComplete (($i/$customers.Count)*100)
  <#
  $azureSubs = Get-AzSubscription -TenantId $customer.CustomerId
  $azureSubRecords = @()

  foreach ($azureSub in $azureSubs){
    $azureSubRecord = [pscustomobject]@{
      Id = $azureSub.Id
      Name 
    }
  }
  #>

  $customerRecord = [pscustomobject]@{
    Name = $customer.Name
    TenantId = $customer.CustomerId
    AzureSubscriptions = (Get-AzSubscription -TenantId $customer.CustomerId)
  }

  $customerRecords += $customerRecord
}

[pscustomobject]@{
  Name = $customer.Name
  TenantId = $customer.CustomerId
  AzureSubscriptions = (
    [pscustomobject]@{
      subscriptionId = $customer
    }
  )
}

$customersWithAzureSubs = $customerRecords | Where-Object {$_.AzureSubscriptions -ne $null}

$subsCSP = $customersWithAzureSubs.AzureSubscriptions

#Get non-CSP subscriptions that we have access to
$subsNonCSP = Get-AzSubscription

$subsAll = $subsCSP + $subsNonCSP

$enabledCSPSubs = $subsCSP | Where-Object {$_.State -eq 'enabled'}

$enabledSubs = $subsAll | Where-Object {$_.State -eq 'enabled'}

$VMs = @()
$i = 0

foreach ($enabledSub in $enabledSubs){
    $i+=1
    Write-Progress -Activity 'Getting VMs' -Status $enabledSub.Name -PercentComplete (($i/$enabledSubs.Count)*100)
    #Write-Host "SubscriptionID is $($enabledSub.Id), Tenant ID is $($enabledSub.TenantId)"
    Select-AzSubscription -Subscription $enabledSub.Id -Tenant $enabledSub.TenantId
    $VMs += Get-AzVM
}