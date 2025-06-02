$filePath = "./words.txt"
$lines = Get-Content $filePath
$successfulGuesses = @()

for ($i = 1; $i -le 200; $i++) {
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
				$successfulGuesses += [PSCustomObject]@{ guess = $reversedWord; similarity = $similarity }
				Write-Host "guess: ${reversedWord}, similarity: ${similarity}"
			}
		}
	} catch {
		$statusCode = $_.Exception.Response.StatusCode.Value__
	}
	if ($statusCode -eq 429) {
		Write-Host "Received 429 Too Many Requests. Sleeping for 10 seconds..."
		Start-Sleep -Seconds 10
	} else {
		Start-Sleep -Milliseconds 150
	}
}

Write-Host "Successful guesses (status 200), sorted by similarity:"
$successfulGuesses | Sort-Object similarity | ForEach-Object { Write-Host ("Guess: {0}, Similarity: {1}" -f $_.guess, $_.similarity) }

Write-Host "Filtered guesses (similarity > 46.29 and < 53.0):"
$successfulGuesses | Where-Object { $_.similarity -gt 46.29 -and $_.similarity -lt 53.0 } | ForEach-Object { Write-Host ("Guess: {0}, Similarity: {1}" -f $_.guess, $_.similarity) }
