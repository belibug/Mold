param($MoldData)
$NewNameLeaf = $($MoldData.StudenName -replace ' ', '_') + '.txt'
Rename-Item -Path 'Letter.txt' -NewName $NewNameLeaf