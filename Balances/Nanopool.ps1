﻿param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash";        symbol = "ETC";  port = 19999; fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"; useemail = $true}
    [PSCustomObject]@{coin = "Ethereum";        algo = "Ethash";        symbol = "ETH";  port = 9999;  fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"; useemail = $true}
    [PSCustomObject]@{coin = "Zcash";           algo = "Equihash";      symbol = "ZEC";  port = 6666;  fee = 1; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"; useemail = $true}
    [PSCustomObject]@{coin = "Monero";          algo = "CrypotnightR";  symbol = "XMR";  port = 14444; fee = 1; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"; useemail = $true}
    [PSCustomObject]@{coin = "Electroneum";     algo = "Cryptonight";   symbol = "ETN";  port = 13333; fee = 2; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"; useemail = $true}
    [PSCustomObject]@{coin = "RavenCoin";       algo = "X16r";          symbol = "RVN";  port = 12222; fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"; useemail = $true}
    [PSCustomObject]@{coin = "PascalCoin";      algo = "Randomhash";    symbol = "PASC"; port = 15556; fee = 2; divisor = 1;   ssl = $false; protocol = "stratum+tcp"; useemail = $true}
    [PSCustomObject]@{coin = "Grin";            algo = "Cuckarood29";   symbol = "GRIN"; port = 12111; fee = 2; divisor = 1;   ssl = $false; protocol = "stratum+tcp"; useemail = $false; walletsymbol = "GRIN29"}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_User = $Config.Pools.$Name.Wallets.$Pool_Currency
    $Pool_Wallet = Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.' -asobject
    if ($Pool_Currency -eq "PASC") {$Pool_Wallet.wallet = "$($Pool_Wallet.wallet -replace "-\d+")$(if (-not $Pool_Wallet.paymentid) {".0"})"}
    try {
        #$Request = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/user/$($Pool_Wallet.wallet)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200
        $Request = Invoke-RestMethodAsync "https://$($Pool_Currency.ToLower()).nanopool.org/api/v1/load_account/$($Pool_Wallet.wallet)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200
        $Count++
        if (-not $Request.status) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned $($Request.error). "
        } else {
            $Balance = [Math]::Max([Decimal]$Request.data.userParams.balance,0)
            $Pending = [Decimal]$Request.data.userParams.balance_uncomfirmed
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Balance
                Pending     = [Decimal]$Pending
                Total       = [Decimal]$Balance + [Decimal]$Pending
                Paid        = [Decimal]$Request.data.userParams.e_sum
                Earned      = [Decimal]0
                Payouts     = @(try {Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/payments/$($Pool_Wallet.wallet)/0/50" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200 | Where-Object status | Select-Object -ExpandProperty data} catch {})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
