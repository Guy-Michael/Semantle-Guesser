param(
	[Parameter(Mandatory=$true, HelpMessage="Please enter the minimum score of guesses you'd like to keep")] [float] $threshold,
	[int] $numberOfGoodGuesses=20
)

Write-Host "Started with threshold of ${threshold} and looking for ${numberOfGoodGuesses} good guesses"
$dictionaryPath = "./dictionary.txt"
Write-Host "loading words.."
$lines = Get-Content $dictionaryPath
Write-Host "finished loading words"
$guessesFilePath = "./goodGuesses.txt"
$badWordsPath = "./badWords.txt"

# Ensure files exist before starting the loop
if (-not (Test-Path $guessesFilePath)) { New-Item -ItemType File -Path $guessesFilePath | Out-Null }
if (-not (Test-Path $badWordsPath)) { New-Item -ItemType File -Path $badWordsPath | Out-Null }

Write-Host "iterating"
$counter = 1
while((Get-Content $guessesFilePath).count -le $numberOfGoodGuesses) {
	$randomLine = Get-Random -InputObject $lines
	$reversedWord = -join ($randomLine.ToCharArray() | ForEach-Object { $_ })[-1..-($randomLine.Length)]
	$urlEncodedWord = [System.Net.WebUtility]::UrlEncode($randomLine)
	try {
		$response = Invoke-WebRequest -Uri "https://semantle.ishefi.com/api/distance?word=$urlEncodedWord" -Method Get -ErrorAction Stop
		$statusCode = $response.StatusCode
		if ($statusCode -eq 200) {
			$json = $response.Content | ConvertFrom-Json
			if ($json.Count -gt 0) {
				$lastObj = $json[-1]
				$similarity = $lastObj.similarity
				if($similarity -ge $threshold) {
					"guess: ${randomLine},`tsimilarity: ${similarity}" | Out-File -Append $guessesFilePath
					Write-Host "Iteration ${counter}: FOUND ONE! guess: ${reversedWord},`tsimilarity: ${similarity}"
					# $successfulGuesses += [PSCustomObject]@{ guess = $reversedWord; similarity = $similarity }
				}
				Write-Host "Iteration ${counter}, guess: ${reversedWord},`tsimilarity: ${similarity}"
			}
		}
	} catch {
		$statusCode = $_.Exception.Response.StatusCode.Value__
		if($statusCode -eq 400 -or $statusCode -eq 422) {
			Write-Host "Iteration ${counter}: failed. guess is: ${reversedWord},`tstatusCode: ${statusCode}. Adding word to bad word list"
			$randomLine | out-File -Append $badWordsPath
		}
	}
	if ($statusCode -eq 429) {
		Write-Host "Received 429 Too Many Requests. Sleeping for 10 seconds..."
		Start-Sleep -Seconds 10
	} else {
		Start-Sleep -Milliseconds 400
	}
	$counter = $counter + 1
}

Write-Host "Successful guesses (status 200), sorted by similarity:"
$successfulGuesses | Sort-Object similarity | ForEach-Object { Write-Host ("Guess: {0}, Similarity: {1}" -f $_.guess, $_.similarity) }

Write-Host "Filtered guesses (similarity > 46.29 and < 53.0):"
$successfulGuesses | Where-Object { $_.similarity -gt $threshold -and $_.similarity -lt 53.0 } | ForEach-Object { Write-Host ("Guess: {0}, Similarity: {1}" -f $_.guess, $_.similarity) }
