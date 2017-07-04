$project = 'YourProjectNameHere'
$projectLogs = "${project}Logs"

# Get CloudWatch config into memory
$cloudWatch = Get-Content -Raw -Path "C:\Program Files\Amazon\SSM\Plugins\awsCloudWatch\AWS.EC2.Windows.CloudWatch.json" | ConvertFrom-Json

# If there's already a log element for this project, don't add it
if(($cloudwatch.engineconfiguration.components | where { $_.id -eq $projectLogs }) -ne $null){
	write-host "Found an element already called $projectLogs, so I'm doing nothing."
	return
}

# This is the section to be added to the file
$logsection = @"
{	"FullName":"AWS.EC2.Windows.CloudWatch.CustomLog.CustomLogInputComponent,AWS.EC2.Windows.CloudWatch",
	"Id":"$projectLogs",
	"Parameters": {
          "CultureName": "en-GB",
          "Encoding": "UTF-8",
          "Filter": "",
          "LineCount": "3",
          "LogDirectoryPath": "C:\\Logs\\$project\\W3SVC\\",
          "TimeZoneKind":  "UTC",
		  "TimestampFormat":  "yyyy-MM-dd HH:mm:ss"
         }
}
"@

Write-Host "Adding $project Logs section."
$cloudwatch.EngineConfiguration.components += (convertfrom-json -inputobject $logsection)

# If there's nothing in the Flows section that's pushing to CloudWatchLogsIIS, add it
if($cloudWatch.EngineConfiguration.Flows.Flows[1] -eq $null){
	
	$extraJson = "($projectLogs),CloudWatchLogsIIS"
	$newArray = $cloudWatch.EngineConfiguration.Flows.Flows += $extraJson
	$cloudWatch.EngineConfiguration.Flows.Flows = $newArray

} else {
# Or if it is in there, add the new one to the list
	$logList = $cloudWatch.EngineConfiguration.Flows.Flows[1].Split(',')[0]
	$logList = $logList.TrimEnd(')')
	$logList += ",$projectLogs),"
	$cloudWatch.EngineConfiguration.Flows.Flows[1] = $logList + $cloudWatch.EngineConfiguration.Flows.Flows[1].Split(',')[1]
}

Write-Host "Saving CloudWatch.json."
# Save the file back to the file system
$cloudWatch | ConvertTo-Json -depth 10 | Out-File "C:\Program Files\Amazon\SSM\Plugins\awsCloudWatch\AWS.EC2.Windows.CloudWatch.json"


# Restart the agent to pick up the changes
Restart-Service AmazonSSMAgent