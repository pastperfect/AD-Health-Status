﻿## Domain Controller AD Health Report
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

IF ($Reports.count -ge $ReportsKept) { $Reports | Sort-Object CreationTime | Select-Object -First 1 | Remove-Item }

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
  <font face='tahoma' color='#003399' size='4'><strong>Active Directory Health Status Report</strong></font>
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

$DomainInfo = Get-ADDomain
$DNSRoot = $DomainInfo.DNSRoot
$DomainControllers = $DomainInfo.ReplicaDirectoryServers | Sort-Object

## Run report

Foreach ($DC in $DomainControllers) {

    $DCShortName = $DC -replace ".$DNSRoot",""
        
    $Report += "<tr>"

    $Report += "<td bgcolor= 'GainsBoro' align=center><B>$DCShortName</B></td>"

    $Status = 0

    ## Connectivity Check ##

    IF ( Test-Connection -ComputerName $DC -Count 4 -Quiet -ErrorAction SilentlyContinue) {

        Write-Output "$DC : `t Ping Success"

        $Report += "<td bgcolor= 'LightGreen' align=center><B>Responsive</B></td>" }
    ELSE {
        Write-Output "$DC :`t Ping Fail"

        $Report += "<td bgcolor= 'GainsBoro' align=center><B>$DC</B></td>"
        $Report += "<td bgcolor= 'Crimson' align=center><B>Unresponsive</B></td>" 

        $Status = 1 }

    IF ( $Status -eq 0 ) {

        ## Checking the status of the NetLogon, NTDS and DNS Services on a DC
         
        $ServiceStatus = Start-Job -ScriptBlock { Get-Service -ComputerName $($args[0]) -Name "netlogon","NTDS","DNS" -ErrorAction SilentlyContinue } -ArgumentList $DC
        Wait-Job $serviceStatus -Timeout $timeout

        IF ($serviceStatus.state -like "Running") {
            Write-Output "$DC :`t Service Check timed out"

            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"
            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"
            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"

            Stop-Job $serviceStatus }
        ELSE {
            
            $SvcState = Receive-Job $ServiceStatus

            $NetlogonState = $SvcState | Where-Object {$_.Name -eq "NetLogon"} 
            IF ($NetlogonState.status -eq "Running") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE  { $Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>" }

            $NTDSState = $SvcState | Where-Object {$_.Name -eq "NTDS"}
            IF ($NTDSState.status -eq "Running") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE  { $Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>" }

            $DNSState = $SvcState | Where-Object {$_.Name -eq "DNS"} 
            IF ($DNSState.status -eq "Running") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE  { $Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>" }

            }

        ## Checking the DCDIAG status of the specified tests on a DC

        $DiagCheck = start-job -scriptblock { DCDIAG /test:Advertising /test:NetLogons /test:Replications /test:Services /test:FSMOCheck /s:$($args[0])} -ArgumentList $DC
        Wait-Job $DiagCheck -Timeout $Timeout

        IF ( $DiagCheck.state -like "Running" ) {
            Write-Output "$DC :`t DCDIAG Tests timed out"

            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"
            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"
            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"
            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"
            $Report += "<td bgcolor= 'Crimson' align=center><B>Timeout</B></td>"

            Stop-Job $serviceStatus }
        ELSE {
            
            $DiagCheckResult = Receive-job $DiagCheck
            
            IF ($DiagCheckResult -like "*passed test NetLogons*") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>"}

            IF ($DiagCheckResult -like "*passed test Replications*") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>"}

            IF ($DiagCheckResult -like "*passed test Services*") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>"} 

            IF ($DiagCheckResult -like "*passed test Advertising*") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>"} 

            IF ($DiagCheckResult -like "*$DNSRoot passed test*") { $Report += "<td bgcolor= 'LightGreen' align=center><B>Passed</B></td>" }
            ELSE {$Report += "<td bgcolor= 'LightCoral' align=center><B>Failed</B></td>"} 
            
            }
    }
    ELSE {
        
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        $Report += "<td bgcolor= 'PapayaWhip' align=center><B>-</B></td>"
        }

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