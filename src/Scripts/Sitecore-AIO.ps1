function Get-Artificialized-Content {
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)] [ValidateNotNullOrEmpty()] 
        [string]$phrase,
        
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)] [ValidateNotNullOrEmpty()] 
        [string]$task,

        [Parameter(Position = 2, Mandatory = $false, ValueFromPipeline = $true)] [ValidateNotNullOrEmpty()] 
        [string]$language
    )
    
    $url = "https://api.openai.com/v1/chat/completions"
    $token = "MY-API-TOKEN"
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }
    
    $taskString = ""
    if($task -eq 1){
        $taskString = "Can you please fix the spelling and grammar of the following text: "+$phrase 
    }
    if($task -eq 2){
        $taskString = "Can you please translate the following text to " + $language + ": "+$phrase    
    }
    if($task -eq 3){
        $taskString = "Can you please rewrite the following text and make it proper: "+$phrase    
    }
    write-host $taskString

    $body = @{
        "model" = "gpt-3.5-turbo-0125"
        "messages"= @( 
            @{  
                "role" = "user" 
                "content"= $taskString
            }
        )
    } | ConvertTo-Json
    
    write-host '---------------------------Artificializing------------------------------'
    
    $response = Invoke-RestMethod -Uri $url -Method "POST" -Headers $headers -Body $body
    #$response | ConvertTo-Json
    write-host $response

    return $response.choices[0].message.content
}


# Get languages:
$Languages = @()
$availableLanguages = [Sitecore.Data.Managers.LanguageManager]::GetLanguages([Sitecore.Context]::ContentDatabase)
$availableLanguages | 
ForEach-Object {
    $Languages += $_.Name
}
write-host "Available Languages in this instance are: "$Languages

$radioOptions = [ordered]@{
    "Check and Fix Spelling" = 1
    "Translate Text Content" = 2
    "Rewrite Text Content" = 3
    "Generate missing alt text for images (not implemented)" = 4
    "Generate Content (not implemented)" = 5 #https://www.linkedin.com/pulse/how-i-used-ai-generate-orchestrate-composable-cloud-alex-doroshenko-ngfjc/
}

$props = @{    
    Parameters  = 
    @(
        @{ Name = "taskList"; Title = "What do you feel like doing today?"; Options = $radioOptions; Tooltip = "Select one or more options" }
        @{ Name = "rootItem"; Title = "Which items will you like to work with now?"; Editor = "droptree"; Source = "/sitecore/content"; Tooltip = "Select from dropdown tree"}
    )    
          
    Title       = "Make my content better"    
    Description = "Video Killed the Radio Star"    
    Width       = 600    
    Height      = 400    
    ShowHints   = $true
}
    
$dialogResult = Read-Variable @props
    
if ($dialogResult -ne "ok") {
    Write-Host "Content could not be king! The Coronation has been postponed. Check your checkboxes."
    Exit
}
    
Write-Host $taskList # 1 = fix, 2 = translate , 3 = rewrite

Write-Host "Selected in dropdown: " $rootItem.DisplayName
if ($rootItem -eq $null) {
    Write-Host "PLEASE SELECT A PARENT ITEM..."
    Exit
}
Write-Host "Path of selected in droptree: " $rootItem.FullPath
Write-Host "========================================================="

if($taskList -eq 1 -or $taskList -eq 3){
    $rootItem.Editing.BeginEdit()
    write-host "ITEM >> "$rootItem.Paths.FullPath
    ForEach ($field in $rootItem.Fields){
        if(!$field.Name.StartsWith("__") -and ($field.Type -eq "Single-Line Text" -or $field.Type -eq "Rich Text")) {
            write-host "FIELD >>"$field.Name
            write-host "OLD VALUE >> "$field.value
                        if (([string]::IsNullOrEmpty($field.value))){
                            write-host $field.Name "is empty. Nothing to do here"
                            continue
                        }
            $newText = Get-Artificialized-Content $field.value $taskList
                        if (([string]::IsNullOrEmpty($newText))){
                            write-host "AI Text is empty. Nothing to do here"
                            continue
                        }
            $rootItem.Fields[$field.Name].Value = $newText
            write-host "NEW VALUE >> "$newText
        }
    }
    $rootItem.Editing.EndEdit()
    Write-Log "Updated this fields value from this to this for this item"
    
    Get-ChildItem -path $rootItem.FullPath -Recurse | ForEach-Object { 
        write-host $_.Paths.FullPath 
        $_.Editing.BeginEdit()
        ForEach ($field in $_.Fields){
            if(!$field.Name.StartsWith("__") -and ($field.Type -eq "Single-Line Text" -or $field.Type -eq "Rich Text")) {
                write-host $field.value
                        if (([string]::IsNullOrEmpty($field.value))){
                            write-host $field.Name "is empty. Nothing to do here"
                            continue
                        }
                $newChildText = Get-Artificialized-Content $field.value $taskList
                $_.Fields[$field.Name].Value = $newChildText
            }
        }
        $_.Editing.EndEdit()
    }
}

if($taskList -eq 2){
    ForEach($language in $Languages){
        if($language -ne "en"){
            write-host $language
            
            Add-ItemLanguage -Path $rootItem.FullPath -TargetLanguage $language -IfExist Skip -Recurse | ForEach-Object { 
                write-host $_.Paths.FullPath 

                $_.Editing.BeginEdit()
                ForEach ($field in $_.Fields){
                    if(!$field.Name.StartsWith("__") -and ($field.Type -eq "Single-Line Text" -or $field.Type -eq "Rich Text")) {
                        write-host $field.value
                        if (([string]::IsNullOrEmpty($field.value))){
                            write-host $field.Name "is empty. Nothing to do here"
                            continue
                        }
                        $newChildText = Get-Artificialized-Content $field.value $taskList $language
                        $_.Fields[$field.Name].Value = $newChildText
                    }
                }
                $_.Editing.EndEdit()
            }
        }
    }
}

if($taskList -eq 4){
    write-host "This has not been implemented. I got the idea 4 in the morning when I woke up from my nap during Hackathon."
    write-host "But if I finish everything then what will you do. And I don't think 150$ and 15 seconds of online fame amounts to this much work ;P ."
    write-host "Yes, I am bitter. There are 15 inches outside my door and I am postponing shoveling."
}

if($taskList -eq 5){
    write-host "Alexandar has done this already. See details at https://www.linkedin.com/pulse/how-i-used-ai-generate-orchestrate-composable-cloud-alex-doroshenko-ngfjc/"
}