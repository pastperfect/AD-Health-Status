## Domain Controller AD Health Report
## Created By: Ricky Burgess 

## Variables

# Report Settings
$ReportOutputPath = "C:\Scripts\ADHealthReport"
$ReportSuffex = "AcmeAdReport"

# Email Settings
$SMTPHOST = "SMTP HOST NAME" 
$From = "ReportSender@Acme.com" 
$To = "Rodger.R@Acme.com"
$Subject = "Active Directory Health Report - " + (Get-Date -Format dd.MM.yyyy) 

# Timeout value in seconds for the various checks, on high latency networks you may want to increase this.
$Timeout = "60"

# Number of reports to keep in the Output folder, once this number is reached it will start removing the oldest ones.
$ReportsKept = 2

## Prepare Report Folder

IF((!(Test-Path $ReportOutputPath))){ New-Item $ReportOutputPath -Type Directory }

$Reports = Get-ChildItem $ReportOutputPath -Filter *$ReportSuffex*.html

IF ($Reports.count -ge $ReportsKept) { $Reports | Sort CreationTime | Select -First 1 | Remove-Item }

## Create report HTML Header

$Report = @'
<html> 
<head> 
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>AD Status Report</title>
<STYLE TYPE="text/css">
 <!-- 
 td { 
 font-family: Tahoma;
  font-size: 11px;
  border-top: 1px solid #999999;
  border-right: 1px solid #999999;
  border-bottom: 1px solid #999999;
  border-left: 1px solid #999999;
  padding-top: 0px;
  padding-right: 0px;
  padding-bottom: 0px;
  padding-left: 0px;
  }
  body { 
  margin-left: 5px; 
  margin-top: 5px; 
  margin-right: 0px; 
  margin-bottom: 10px; 
  } 
  table {
  border: thin solid #000000; 
  }
  --> 
  </style> 
 </head>
 <body> 
  <table width='100%'>
  <tr bgcolor='Lavender'>
  <td colspan='7' height='25' align='center'>
  <font face='tahoma' color='#003399' size='4'><strong>Active Directory Health Check</strong></font>
  </td>
  </tr> 
  </table>
 
  <table width='100%'>
  <tr bgcolor='IndianRed'>
  <td width='10%' align='center'><B>DC</B></td>
  <td width='10%' align='center'><B>Ping</B></td>
  <td width='10%' align='center'><B>Netlogon</B></td>
  <td width='10%' align='center'><B>NTDS</B></td>
  <td width='10%' align='center'><B>DNS Status</B></td>
  <td width='10%' align='center'><B>Netlogons</B></td>
  <td width='10%' align='center'><B>Replication</B></td>
  <td width='10%' align='center'><B>Services</B></td>
  <td width='10%' align='center'><B>Advertising</B></td>
  <td width='10%' align='center'><B>FSMOCheck</B></td>
 
 </tr>
'@

## Get list of domain controllers to process

$getForest = [system.directoryservices.activedirectory.Forest]::GetCurrentForest()

$DCServers = $getForest.domains | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name}

$DCServers = $DCServers | Sort

## Run report

Foreach ($DC in $DCServers) {
        
    $Report += "<tr>"

    $Status = 0

    ## Connectivity Check ##

    IF ( Test-Connection -ComputerName $DC -Count 1 -Quiet -ErrorAction SilentlyContinue) {

        Write-Output "$DC : `t Ping Success"

        $Report += "<td bgcolor= 'GainsBoro' align=center><B>$DC</B></td>"
        $Report += "<td bgcolor= 'Aquamarine' align=center><B>Success</B></td>" }
    ELSE {
        Write-Output "$DC :`t Ping Fail"

        $Report += "<td bgcolor= 'GainsBoro' align=center><B>$DC</B></td>"
        $Report += "<td bgcolor= 'Crimson' align=center><B>Ping Fail</B></td>" 

        $Status = 1 }

    ## Netlogon Service Check ##

    IF ( $Status -eq 0 ) {

        $ServiceStatus = Start-Job -ScriptBlock {Get-Service -ComputerName $($args[0]) -Name "Netlogon" -ErrorAction SilentlyContinue} -ArgumentList $DC
        Wait-Job $serviceStatus -Timeout $timeout

        IF ($serviceStatus.state -like "Running") {
            Write-Output "$DC :`t Netlogon Service: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>NetlogonTimeout</B></td>"

            Stop-Job $serviceStatus 
            
            $Staus = 1 }
        ELSE {

            $SvcState = (Receive-Job $ServiceStatus).Status

            IF ($SvcState -eq "Running"){ $Report += "<td bgcolor= 'Aquamarine' align=center><B>$SvcState</B></td>" }
            ELSE { $Report += "<td bgcolor= 'Coral' align=center><B>$SvcState</B></td>" } 
            } 
    }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## NTDS Service Status ##

    IF ( $Status -eq 0 ) {

        $ServiceStatus = Start-Job -ScriptBlock {Get-Service -ComputerName $($args[0]) -Name "NTDS" -ErrorAction SilentlyContinue} -ArgumentList $DC
        Wait-Job $serviceStatus -Timeout $timeout

        IF ($serviceStatus.state -like "Running") {
            Write-Output "$DC :`t NTDS Service: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>NTDSTimeout</B></td>"

            Stop-Job $serviceStatus 
            
            $Staus = 1 }
        ELSE {

            $SvcState = (Receive-Job $ServiceStatus).Status

            IF ($SvcState -eq "Running"){ $Report += "<td bgcolor= 'Aquamarine' align=center><B>$SvcState</B></td>" }
            ELSE { $Report += "<td bgcolor= 'Coral' align=center><B>$SvcState</B></td>" } 
            }
    }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## DNS Service Status ##

    IF ( $Status -eq 0 ) {

        $ServiceStatus = Start-Job -ScriptBlock {Get-Service -ComputerName $($args[0]) -Name "DNS" -ErrorAction SilentlyContinue} -ArgumentList $DC
        Wait-Job $serviceStatus -Timeout $timeout

        IF ($serviceStatus.state -like "Running") {
            Write-Output "$DC :`t DNS Service: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>DNSTimeout</B></td>"

            Stop-Job $serviceStatus 
            
            $Staus = 1 }
        ELSE {

            $SvcState = (Receive-Job $ServiceStatus).Status

            IF ($SvcState -eq "Running"){ $Report += "<td bgcolor= 'Aquamarine' align=center><B>$SvcState</B></td>" }
            ELSE { $Report += "<td bgcolor= 'Coral' align=center><B>$SvcState</B></td>" } 
            }
        }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## Netlogon DCDiag Check ##

    IF ( $Status -eq 0 ) {

        $DiagCheck = start-job -scriptblock {dcdiag /test:netlogons /s:$($args[0])} -ArgumentList $DC

        Wait-Job $DiagCheck -Timeout $timeout
        
        IF ($DiagCheck.state -like "Running") {
            Write-Output "$DC :`t Diag Check Netlogon: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>JobTimeout</B></td>"

            Stop-Job $DiagCheck 
            
            $Staus = 1 }
        ELSE {
            
            $DiagCheckResult = Receive-job $DiagCheck

            IF ($DiagCheckResult -like "*passed test NetLogons*") { $Report += "<td bgcolor= 'Aquamarine' align=center><B>NetlogonsPassed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'Coral' align=center><B>NetlogonsFail</B></td>"} 
            }
    }             
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## Replications DCDiag Check ##

    IF ( $Status -eq 0 ) {

        $DiagCheck = start-job -scriptblock {dcdiag /test:Replications /s:$($args[0])} -ArgumentList $DC

        Wait-Job $DiagCheck -Timeout $timeout
        
        IF ($DiagCheck.state -like "Running") {
            Write-Output "$DC :`t Diag Check Replications: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>JobTimeout</B></td>"

            Stop-Job $DiagCheck 
            
            $Staus = 1 }
        ELSE {
            
            $DiagCheckResult = Receive-job $DiagCheck

            IF ($DiagCheckResult -like "*passed test Replications*") { $Report += "<td bgcolor= 'Aquamarine' align=center><B>ReplicationsPassed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'Coral' align=center><B>ReplicationsFail</B></td>"} 
            }               
    }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## Services DCDiag Check ##

    IF ( $Status -eq 0 ) {

        $DiagCheck = start-job -scriptblock {dcdiag /test:Services /s:$($args[0])} -ArgumentList $DC

        Wait-Job $DiagCheck -Timeout $timeout
        
        IF ($DiagCheck.state -like "Running") {
            Write-Output "$DC :`t Diag Check Services: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>JobTimeout</B></td>"

            Stop-Job $DiagCheck 
            
            $Staus = 1 }
        ELSE {
            
            $DiagCheckResult = Receive-job $DiagCheck

            IF ($DiagCheckResult -like "*passed test Services*") { $Report += "<td bgcolor= 'Aquamarine' align=center><B>ServicesPassed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'Coral' align=center><B>ServicesFail</B></td>"} 
            }               
    }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## Advertising DCDiag Check ##

    IF ( $Status -eq 0 ) {

        $DiagCheck = start-job -scriptblock {dcdiag /test:Advertising /s:$($args[0])} -ArgumentList $DC

        Wait-Job $DiagCheck -Timeout $timeout
        
        IF ($DiagCheck.state -like "Running") {
            Write-Output "$DC :`t Diag Check Advertising: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>JobTimeout</B></td>"

            Stop-Job $DiagCheck 
            
            $Staus = 1 }
        ELSE {
            
            $DiagCheckResult = Receive-job $DiagCheck

            IF ($DiagCheckResult -like "*passed test Advertising*") { $Report += "<td bgcolor= 'Aquamarine' align=center><B>AdvertisingPassed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'Coral' align=center><B>ServicesFail</B></td>"} 
            }               
    }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    ## FSMOCheck DCDiag Check ##

    IF ( $Status -eq 0 ) {

        $DiagCheck = start-job -scriptblock {dcdiag /test:FSMOCheck /s:$($args[0])} -ArgumentList $DC

        Wait-Job $DiagCheck -Timeout $timeout
        
        IF ($DiagCheck.state -like "Running") {
            Write-Output "$DC :`t Diag Check FSMOCheck: Time Out"

            $Report += "<td bgcolor= 'Yellow' align=center><B>JobTimeout</B></td>"

            Stop-Job $DiagCheck 
            
            $Staus = 1 }
        ELSE {
            
            $DiagCheckResult = Receive-job $DiagCheck

            IF ($DiagCheckResult -like "*passed test*") { $Report += "<td bgcolor= 'Aquamarine' align=center><B>FSMOCheckPassed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'Coral' align=center><B>FSMOCheckFail</B></td>"} 
            }               
    }
    ELSE { $Report += "<td bgcolor= 'Crimson' align=center><B>TimeoutJobNotRun</B></td>" }

    $Report += "</tr>"

}

# Prepare report HTML Footer

$Report += "</tr>"
$Report +=  "</table>" 
$Report += "</body>" 
$Report += "</html>" 

## Output results

# To file

$Filename = (get-date -Format dd.MM.yyyy) + "_" + $ReportSuffex + ".html"

$Report | Out-File $ReportOutputPath\$Filename

# Email
 
Send-MailMessage -From $From -To $To -Subject $Subject -Body $Report -BodyAsHtml -SmtpServer $SMTPHOST