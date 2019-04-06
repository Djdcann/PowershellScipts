param(
    [Parameter(Mandatory=$true)][string]$string,
    [string]$fg = ":heart:",
    [string]$bg = ":_:"
)

$gridLength = 5

$bgEmote = $bg
$fgEmote = $fg


$dict = @{
    'a' = "*##*`n#**#`n####`n#**#`n#**#";
    'b' = "####*`n#***#`n####*`n#***#`n####*";
    'c' = "*###*`n#****`n#****`n#****`n*###*";
    'd' = "####*`n#***#`n#***#`n#***#`n####*";
    'e' = "####`n#***`n###*`n#***`n####";
    'f' = "####`n#***`n###*`n#***`n#***";
    'g' = "#####`n#****`n#*###`n#***#`n#####";
    'h' = "#**#`n#**#`n####`n#**#`n#**#";
    'i' = "###`n*#*`n*#*`n*#*`n###";
    'j' = "#####`n***#*`n***#*`n#**#*`n####*";
    'k' = "#**#*`n#*#**`n##***`n#*#**`n#**#*";
    'l' = "#***`n#***`n#***`n#***`n####";
    'm' = "#***#`n##*##`n#*#*#`n#***#`n#***#";
    'n' = "#***#`n##**#`n#*#*#`n#**##`n#***#";
    'o' = "*###*`n#***#`n#***#`n#***#`n*###*";
    'p' = "####`n#**#`n####`n#***`n#***";
    'q' = "*###*`n#***#`n#*#*#`n#**#*`n*##*#";
    'r' = "####*`n#***#`n#####`n#**#*`n#***#";
    's' = "#####`n#****`n#####`n****#`n#####";
    't' = "#####`n**#**`n**#**`n**#**`n**#**";
    'u' = "#***#`n#***#`n#***#`n#***#`n#####";
    'v' = "#***#`n#***#`n#***#`n*#*#*`n**#**";
    'w' = "#***#`n#***#`n#***#`n#*#*#`n*#*#*";
    'x' = "#***#`n*#*#*`n**#**`n*#*#*`n#***#";
    'y' = "#***#`n*#*#*`n**#**`n**#**`n**#**";
    'z' = "####`n**#*`n*#**`n#***`n####";
    '_' = "*#*#*`n#*#*#`n#***#`n*#*#*`n**#**";
    '-' = "***`n***`n###`n***`n***";
    '!' = "*#*`n*#*`n*#*`n***`n*#*";
    '?' = "####`n***#`n*###`n****`n*#**";
}


if($string)
{
    foreach($word in $string.Split())
    {
        for($i=0;$i -lt $gridLength;$i++)
        {
            $line = ""
            foreach($x in $word.ToCharArray())
            {
                $line += "*" + $dict["$x"].Split("`n")[$i]
            }
            $line += "*"
            if($i -eq 0){
                $space = $bgEmote*$line.Length
                Write-Output ($bgEmote*$line.Length)
            }
            Write-Output $line.Replace('*', $bgEmote).Replace('#', $fgEmote)
        }
    }
    Write-Output ($bgEmote*$line.Length)
}
