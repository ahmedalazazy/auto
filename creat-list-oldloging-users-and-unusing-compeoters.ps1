import-module activedirectory  

#$domain = "(your.fqdn)"  
$domain = "google.com"
$DaysInactive = 90  

$time = (Get-Date).Adddays(-($DaysInactive)) 
#to creat var for path saveing csv files
$inactivecomp = '${env:UserProfile}\ad-reports\inactivecomputers.csv'

$inactiveuser = '${env:UserProfile}\ad-reports\inactiveusers.csv' 


#to remove if the path have a old csv file in in path
#Remove-Item -Path $inactivecomp -Force

#Remove-Item -Path $inactiveuser -Force

  
# To test if this path not created 
If ((Test-Path ${env:UserProfile}\AD-Reports) -eq $false){
#if path not created the create path
New-Item -ItemType Directory -Path ${env:UserProfile}\ -Name ad-reports

}
# Get inactive computers report
Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -Properties LastLogonTimeStamp |
select-object Name,@{Name="LastSeen"; Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp)}} | 

sort -Property LastSeen |

export-csv $inactivecomp -notypeinformation -Force

#Get inactive AD user report

Get-ADUser -Filter {LastLogonDate -lt $time} -Properties LastLogonDate |

Select Name, Enabled, LastLogonDate |

Sort LastLogonDate |

Export-Csv -Path $inactiveuser -NoTypeInformation -Force

#if you need to schadualing script and make it send for you CSV files in mail 
#Send-MailMessage -To your@emal.com -From do_not_reply@email.com -Subject "Inactive Computer and User Accounts" -Body "Users and computers that have not been #seen in the last 30 days" -SmtpServer (your_smtp_ip) -Attachments $inactivecomp, $inactiveuser
