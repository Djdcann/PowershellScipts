﻿param(
    # The text to Speak
    [parameter(ValueFromPipeline)]
    [String]
    $text = "Give me that pepperoni BAYBEEEEEEEEEEEEEEEEE"
)

[Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null 
#$phrases =  Get-Content $HOME\bin\prankphrases.txt
#$phrase = Get-Random $phrases
$object = New-Object System.Speech.Synthesis.SpeechSynthesizer 
$object.SelectVoiceByHints('Female')
$object.Speak($text)
