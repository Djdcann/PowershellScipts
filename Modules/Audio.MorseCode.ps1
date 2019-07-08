#region PSLinker imports (no compact)

Function ConvertTo-StringToken
{
    <#
        .Synopsis
               Parses a string into an array of tokens.
    
        .DESCRIPTION
               This command parses the supplied string into a token array.
    
            Delimiter (separators) and qualifier (quotation) symbols may be customized.
    
            Limitations:
            * No multi character support
            * No qualifier pair
            * No conditional delimiter
    
        .PARAMETER String
               The string to be parsed.
            
            If a string array is passed in, each element of the array is treated as a separate line.
    
            If a single string containing embedded `r and/or `n characters.
    
        .PARAMETER Delimiter
               A delimiter is the character that separates each token.
    
            You may specify more than one delimiter.
    
            The default delimiters are spaces and tabs.
    
        .PARAMETER Qualifier
            If a token contains a delimiter character, it must be qualified (quoted).
                
            As with delimiters, you may be specify more than one qualifier.
    
            The default quanlifier is double quotation marks.
    
        .PARAMETER Escape
            If a token contains a qualifier character, it must be preceded by an escape character.
        
            By default, there is no escape character.
    
            Use the 'NoDoubleQualifiers' switch if you want to escape a qualifier by preceding that qualifier with itself.

            If an escape character is NOT followed by the active qualifier, that escape character will be included in the token.
    
        .PARAMETER LineDelimiter
               If the 'Span' switch is used, and if the opening and closing qualifers of a token are found in different elements of the array specified by the 'String' parameter, the string specified by 'LineDelimiter' will be injected into the token.
    
            The default is [Environment]::NewLine
    
        .PARAMETER NoDoubleQualifier
               By default, this command treats two consecutive qualifiers as one embedded qualifier character in a token.
    
            For example: "a ""token"" string" is parsed as:
            * ' a'
            * '"token"'
            * ' string'
    
            Using the 'NoDoubleQualifier' switch disables this behavior, causing only the 'Escape' characters to be allowed for embedding qualifiers in a token.
    
        .PARAMETER IgnoreConsecutiveDelimiters
               By default, if this command finds consecutive delimiters, it will output empty strings as tokens.
    
            Use this switch to treat consecutive delimiters as one (effectively only returning non-empty tokens, unless the empty string is qualified/quoted).
    
        .PARAMETER Span
               Using this switch allows qualified tokens to contain embedded end-of-line characters.
    
        .PARAMETER GroupLines
               Using this switch causes this command to return an object for each line of input.
    
            If the 'Span' switch is also used, multiple lines of text from the input may be merged into one output object.
    
               Each output object will have a Tokens collection.
    
        .INPUTS
           [System.String]
    
        .OUTPUTS
               [System.String] - One string for each token.
               [PSObject] - If the 'GroupLines' switch is used, outputs custom objects with a Tokens property. The Tokens property is of type string array (i.e. [String[]]).

        .EXAMPLE
             @('key1=value1', 'key2 =value2', '"key 3"=value3', "'key 4'= value4", '"key`"5`""="value=5"') | ConvertTo-StringToken -Delimiter '=', ' ' -Qualifier '"', "'" -Escape '`' -IgnoreConsecutiveDelimiters -NoDoubleQualifier
            key1
            value1
            key2
            value2
            key 3
            value3
            key 4
            value4
            key "5"
            value=5
    
        .EXAMPLE
               ConvertTo-StringToken -String @("Line 1", "Line`t 2", '"Line 3"') | % { Write-Host "'$_'" }
            'Line'
            '1'
            'Line'
            ''
            '2'
            'Line 3'

            Description
            -----------
            Tokenizes an array of strings using the command's default behavior:
            * Spaces and tabs as delimiters
            * double quotation marks as a qualifier
            * consecutive delimiters produces an empty token
    
            In this example, six tokens will be output.

        .EXAMPLE
               $strings | ConvertTo-StringToken -Delimiter ',' -Qualifier '"' -Span

            Description
            -----------
               Pipes a string or string collection to ConvertTo-StringToken.
    
            Text is parsed in the CSV format: comma-delimited, with double quotation qualifiers, and qualified tokens may span multiple lines.
    
        .EXAMPLE
               $strings | ConvertTo-StringToken -Qualifier '"' -IgnoreConsecutiveDelimeters -Escape '\' -NoDoubleQualifier

            Description
            -----------
            Pipes a string or string collection to ConvertTo-StringToken.
    
            Uses the default delimiters of tab and space.
    
            Double quotes are used as qualifier, and embedded quotes must be escaped with a backslash.
    
            Placing two consecutive double quotes is disabled by the 'NoDoubleQualifier' switch.
    
            Consecutive delimiters are ignored.
    #>
    
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [System.String[]]$String,
    
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNull()]
        [System.String[]]$Delimiter = @("`t", ' '),
    
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNull()]
        [System.String[]]$Qualifier = @('"'),
        <#
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNull()]
        [System.Collections.Hashtable]$Qualifier = @{ '"' = '"' },
        #>
    
        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateNotNull()]
        [System.String[]]$Escape = @(),
    
        [Parameter(Mandatory = $false, Position = 5)]
        [ValidateNotNull()]
        [System.String]$LineDelimiter = [Environment]::NewLine,
    
        [Parameter(Mandatory = $false)]
        [Alias('NoQuals')]
        [Switch]$NoDoubleQualifier,
    
        [Parameter(Mandatory = $false)]
        [Switch]$Span,
    
        [Parameter(Mandatory = $false)]
        [Alias('Group')]
        [Switch]$GroupLines,
    
        [Parameter(Mandatory = $false)]
        [Alias('NoDelims')]
        [Switch]$IgnoreConsecutiveDelimiters
    )
    
    Begin
    {
        $currentToken = New-Object System.Text.StringBuilder
        $currentQualifer = $null
        
        $delimiters = @{ }
        ForEach ($item in $Delimiter)
        {
            ForEach ($character in $item.GetEnumerator())
            {
                $delimiters[$character] = $true
                Write-Verbose ("Added delimiter character: '$character'")
            }
        }
        
        $qualifiers = @{ }
        ForEach ($item in $Qualifier)
        {
            ForEach ($character in $item.GetEnumerator())
            {
                $qualifiers[$character] = $true
                Write-Verbose ("Added qualifier character: $character")
            }
        }
        
        <#
        $Qualifier.Keys | ForEach-Object {
            $qualifiers[$_] = $Qualifier[$_]
            Write-Verbose ("Added qualifier: {$_, $($qualifiers[$_])}")
        }
        #>
        
        $escapeChars = @{ }
        ForEach ($item in $Escape)
        {
            ForEach ($character in $item.GetEnumerator())
            {
                $escapeChars[$character] = $true
                Write-Verbose ("Added escape character: $character")
            }
        }
        
        If ($NoDoubleQualifier)
        {
            $doubleQualifierIsEscape = $false
        }
        Else
        {
            $doubleQualifierIsEscape = $true
        }
        
        $lineGroup = New-Object System.Collections.ArrayList
    }
    
    Process
    {
        ForEach ($str in $String)
        {
            Write-Verbose "Parsing line: $str"
            
            # If the last $str value was in the middle of building a token when the end of the string was reached,
            # handle it before parsing the current $str.
            If ($currentToken.Length -gt 0)
            {
                If (($null -ne $currentQualifer) -and $Span)
                {
                    $null = $currentToken.Append($LineDelimiter)
                }
                Else
                {
                    If ($GroupLines)
                    {
                        $null = $lineGroup.Add($currentToken.ToString())
                    }
                    Else
                    {
                        Write-Output $currentToken.ToString()
                    }
                    
                    $currentToken.Length = 0
                    $currentQualifer = $null
                }
            }
            
            If ($GroupLines -and ($lineGroup.Count -gt 0))
            {
                Write-Output (New-Object PSCustomObject -Property @{
                    Tokens = $lineGroup.ToArray()
                })
                
                $lineGroup.Clear()
            }
            
            For ($i = 0; $i -lt $str.Length; $i++)
            {
                $currentChar = $str.Chars($i)
                
                If ($currentQualifer)
                {
                    # line breaks in qualified token.
                    If ((($currentChar -eq "`n") -or ($currentChar -eq "`r")) -and
                    (-not $Span))
                    {
                        If (($currentToken.Length -gt 0) -or (-not $IgnoreConsecutiveDelimiters))
                        {
                            If ($GroupLines)
                            {
                                $null = $lineGroup.Add($currentToken.ToString())
                            }
                            Else
                            {
                                Write-Output $currentToken.ToString()
                            }
                            
                            $currentToken.Length = 0
                            $currentQualifer = $null
                        }
                        
                        If ($GroupLines -and ($lineGroup.Count -gt 0))
                        {
                            Write-Output (New-Object PSCustomObject -Property @{
                                Tokens = $lineGroup.ToArray()
                            })
                            
                            $lineGroup.Clear()
                        }
                        
                        # we're not including the line breaks in the token, so eat the rest of the consecutive line break characters.
                        While ((($i + 1) -lt $str.Length) -and (($str.Chars($i + 1) -eq "`r") -or ($str.Chars($i + 1) -eq "`n")))
                        {
                            $i++
                        }
                    }
                    # embedded, escaped qualifiers
                    ElseIf (($escapeChars.ContainsKey($currentChar) -or (($currentChar -eq $currentQualifer) -and $doubleQualifierIsEscape)) -and
                    (($i + 1) -lt $str.Length) -and
                    ($str.Chars($i + 1) -eq $currentQualifer))
                    {
                        $null = $currentToken.Append($currentQualifer)
                        $i++
                    }
                    # closing qualifier
                    ElseIf ($currentChar -eq $currentQualifer)
                    {
                        If ($GroupLines)
                        {
                            $null = $lineGroup.Add($currentToken.ToString())
                        }
                        Else
                        {
                            Write-Output $currentToken.ToString()
                        }
                        
                        $currentToken.Length = 0
                        $currentQualifer = $null
                        
                        # Eat any non-delimiter, non-EOL text after the closing qualifier, plus the next delimiter.
                        # Sets the loop up to begin processing the next token (or next consecutive delimiter) next time through.
                        # End-of-line characters are left alone, because eating them can interfere with the GroupLines switch behavior.
                        While ((($i + 1) -lt $str.Length) -and ($str.Chars($i + 1) -ne "`r") -and ($str.Chars($i + 1) -ne "`n") -and (-not $delimiters.ContainsKey($str.Chars($i + 1))))
                        {
                            $i++
                        }
                        
                        If ((($i + 1) -lt $str.Length) -and ($delimiters.ContainsKey($str.Chars($i + 1))))
                        {
                            $i++
                        }
                    }
                    # token content
                    Else
                    {
                        $null = $currentToken.Append($currentChar)
                    }
                } # end if ($currentQualifier)
                Else
                {
                    Write-Verbose ("* '$currentChar'")
                    
                    # opening qualifier
                    If (($currentToken.ToString() -match '^\s*$') -and ($qualifiers.ContainsKey($currentChar)))
                    {
                        # currentToken is '' or white spaces only
                        #$currentQualifer = $qualifiers[$currentChar]
                        $currentQualifer = $currentChar
                        $currentToken.Length = 0
                        Write-Verbose "Set current qualifier: '$currentQualifer'"
                    }
                    # delimiter
                    ElseIf ($delimiters.ContainsKey($currentChar))
                    {
                        If (($currentToken.Length -gt 0) -or (-not $IgnoreConsecutiveDelimiters))
                        {
                            If ($GroupLines)
                            {
                                $null = $lineGroup.Add($currentToken.ToString())
                            }
                            Else
                            {
                                Write-Output $currentToken.ToString()
                            }
                            
                            $currentToken.Length = 0
                            $currentQualifer = $null
                        }
                    }
                    # line breaks (not treated quite the same as delimiters)
                    ElseIf (($currentChar -eq "`n") -or ($currentChar -eq "`r"))
                    {
                        If ($currentToken.Length -gt 0)
                        {
                            If ($GroupLines)
                            {
                                $null = $lineGroup.Add($currentToken.ToString())
                            }
                            Else
                            {
                                Write-Output $currentToken.ToString()
                            }
                            
                            $currentToken.Length = 0
                            $currentQualifer = $null
                        }
                        
                        If ($GroupLines -and ($lineGroup.Count -gt 0))
                        {
                            Write-Output (New-Object PSCustomObject -Property @{
                                Tokens = $lineGroup.ToArray()
                            })
                            
                            $lineGroup.Clear()
                        }
                    }
                    # token content
                    Else
                    {
                        $null = $currentToken.Append($currentChar)
                    }
                } # -not $currentQualifier
            } # end for $i = 0 to $str.Length
        } # end foreach $str in $String
    }
    
    End
    {
        If ($currentToken.Length -gt 0)
        {
            If ($GroupLines)
            {
                $null = $lineGroup.Add($currentToken.ToString())
            }
            Else
            {
                Write-Output $currentToken.ToString()
            }
        }
        
        If ($GroupLines -and $lineGroup.Count -gt 0)
        {
            Write-Output (New-Object PSCustomObject -Property @{
                Tokens = $lineGroup.ToArray()
            })
        }
    }
}

#endregion

Function ConvertTo-MorseCode
{
    <#
        .SYNOPSIS
            Converts text to Morse code.
    
        .DESCRIPTION
            International morse code supports only a subset of ASCII symbols. Lower case letters will be converted to upper case. Unsupported symbols will be lost in the conversion.
    
            Each member in 'InputObject' will be treated as a line. The prosign 'AA' is appended to the end of each line.

            You can specify prosigns by using the prepending its code with an exclamation symbol (e.g. '!SOS'). Here is a list of supported prosigns:
            # AA, New line
            # AR, End of message
            # AS, Wait
            # BK, Break
            # BT , New paragraph
            # CL, Going off the air ("clear")
            # CT, Start copying
            # DO, Change to wabun code
            # KN, Invite a specific station to transmit
            # SK, End of transmission
            # SN, Understood
            # VE, Unterstood
            # SOS, Distress message
    
            The AA and AR prosigns are automatically appended to the end of each member of 'InputObject' and the end of message respectively.

            Use the 'Binary' switch to output as a byte array.
    
        .LINK
            http://morsecode.scphillips.com/morse.html
    
        .EXAMPLE
            'hello world' | ConvertTo-MorseCode | ConvertFrom-MorseCode
            
        .EXAMPLE
            'bye world !sos' | ConvertTo-MorseCode | ConvertFrom-MorseCode
            BYE WORLD [Distress]
    
            Description
            -----------
            Use a prosign by prepending its code with an exclamation ('!') mark.
    
        .EXAMPLE
            'hello world' | ConvertTo-MorseCode -Binary | Start-PlayMorseCode
    
            Description
            -----------
            Output to binary and play on your speaker.
    #>
    
    [CmdletBinding(DefaultParameterSetName = 'FromContent')]
    Param
    (
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ParameterSetName = 'FromContent')]
        [AllowEmptyString()]
        [String[]]$InputObject,
    
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'FromFile')]
        [String]$Path,
    
        [Parameter(Mandatory = $false)]
        [Switch]$Binary
    )
    
    Begin
    {
        If ($PSCmdlet.ParameterSetName -eq 'FromContent')
        {
            # pipeline workaround
            [String[]]$procValue = @()
        }
        
        # data
        $letters = @{
            'A' = '.-'
            'B' = '-...'
            'C' = '-.-.'
            'D' = '-..'
            'E' = '.'
            'F' = '..-.'
            'G' = '--.'
            'H' = '....'
            'I' = '..'
            'J' = '.---'
            'K' = '-.-'
            'L' = '.-..'
            'M' = '--'
            'N' = '-.'
            'O' = '---'
            'P' = '.--.'
            'Q' = '--.-'
            'R' = '.-.'
            'S' = '...'
            'T' = '-'
            'U' = '..-'
            'V' = '...-'
            'W' = '.--'
            'X' = '-..-'
            'Y' = '-.--'
            'Z' = '--..'
            'Ä' = '.-.-'
            'Á' = '.--.-'
            'Å' = '.--.-'
            'Ch' = '----'
            'É' = '..-..'
            'Ñ' = '--.--'
            'Ö' = '---.'
            'Ü' = '..--'
        }
        $digits = @{
            '0' = '-----'
            '1' = '.----'
            '2' = '..---'
            '3' = '...--'
            '4' = '....-'
            '5' = '.....'
            '6' = '-....'
            '7' = '--...'
            '8' = '---..'
            '9' = '----.'
        }
        $punc = @{		
            "." = ".-.-.-"
            "," = "--..--"
            ":" = "---..."
            "?" = "..--.."
            "'" = ".----."
            "-" = "-....-"
            "/" = "-..-."
            "(" = "-.--.-"
            ")" = "-.--.-"
            '"' = ".-..-."
            "@" = ".--.-."
            "=" = "-...-"
        }
        $prosign = @{
            #!XX = morse, subschar
            'AA' = '.-.-'
            'AR' = '.-.-.'
            'AS' = '.-...'
            'BK' = '-...-.-'
            'BT' = '-...-'
            'CL' = '-.-..-..'
            'CT' = '-.-.-'
            'DO' = '-..---'
            'KN' = '-.--.'
            'SK' = '...-.-'
            'SN' = '...-.'
            'VE' = '...-.'
            'SOS' = '...---...'
        }
        $phrase = @{
            'over' = 'K'
            'roger' = 'R'
            'see you later' = 'CUL'
            'be seeing you' = 'BCNU'
            "you're" = 'UR'
            'signal report' = 'RST'
            'best regards' = '73'
            'loves and kisses' = '88'
        }
        $qcode = @{
            'i acknowledge receipt' = 'QSL'
            'do you acknowledge?' = 'QSL?'
            'wait' = 'QRX'
            'should i wait?' = 'QRX?'
            'ready to copy' = 'QRV'
            'ready to copy?' = 'QRV?'
            'frequency in use' = 'QRL'
            'frequency in use?' = 'QRL?'
            'my location is' = 'QTH'
            'your location?' = 'QTH?'
        }
        $letterSeparator = '   '
        $wordSeparator = '       '
    }
    
    Process
    {
        If ($PSCmdlet.ParameterSetName -eq 'FromFile')
        {
            $Path = (Resolve-Path $Path -ErrorAction Stop).Path
            $procValue = Get-Content $Path
        }
        ElseIf ($PSCmdlet.ParameterSetName -eq 'FromContent')
        {
            $procValue += $InputObject
        }
    }
    
    End
    {
        $output = ''
        ForEach ($line in $procValue)
        {
            If ($line -eq '') { Continue }
            $line = $line.ToUpper()
            $lineBuilder = '';
            
            # phrase and qcode
            $phrase.Keys | ForEach-Object {
                If ($line.Contains($_.ToUpper()))
                {
                    $line = $line.Replace($_.ToUpper(), $phrase[$_])
                }
            }
            $qcode.Keys | ForEach-Object {
                If ($line.Contains($_.ToUpper()))
                {
                    $line = $line.Replace($_.ToUpper(), $qcode[$_])
                }
            }
            
            # prosign
            $prosign.Keys | ForEach-Object {
                If ($line.Contains("!$_"))
                {
                    # make prosign a single char word
                    #$line = $line.Replace("!$_", (' ' + $prosign[$_][1] + ' '))
                    $line = $line.Replace("!$_", " !$_ ")
                }
            }
            
            ForEach ($word in ($line | ConvertTo-StringToken -IgnoreConsecutiveDelimiters))
            {
                If ($word.StartsWith('!') -and $prosign.ContainsKey($word.Substring(1)))
                {
                    $lineBuilder += $prosign[$word.Substring(1)]
                    
                    # this will make 10 units between words. we'll deal with them later.
                    $lineBuilder += $letterSeparator
                }
                Else
                {
                    For ($i = 0; $i -lt $word.Length; $i++)
                    {
                        [String]$wordChar = $word[$i]
                        
                        If ($letters.ContainsKey($wordChar))
                        {
                            $lineBuilder += $letters[$wordChar]
                        }
                        ElseIf ($digits.ContainsKey($wordChar))
                        {
                            $lineBuilder += $digits[$wordChar]
                        }
                        ElseIf ($punc.ContainsKey($wordChar))
                        {
                            $lineBuilder += $punc[$wordChar]
                        }
                        
                        # 3 units long between letters
                        $lineBuilder += $letterSeparator
                    }
                }
                
                # 7 units long between words
                $lineBuilder += $wordSeparator
            }
            
            # 10 blank spaces -> 7 blank spaces
            $lineBuilder = $lineBuilder.Replace($wordSeparator + $letterSeparator, $wordSeparator)
            
            # add line break
            $lineBuilder += $prosign['AA']
            
            # append
            $output += $lineBuilder
        }
        
        # add terminator
        $output += $prosign['AR']
        
        # done if not bin
        If (-not $Binary) { Return $output }
        
        # binary converter
        $binout = [Byte[]]@()
        For ($i = 0; $i -lt $output.Length; $i++)
        {
            If ($output[$i] -eq ' ')
            {
                $binout += 0
            }
            ElseIf ($output[$i] -eq '.')
            {
                $binout += 1
                $binout += 0
            }
            ElseIf ($output[$i] -eq '-')
            {
                $binout += 1
                $binout += 1
                $binout += 1
                $binout += 0
            }
        }
        
        Return $binout
    }
}

Function ConvertFrom-MorseCode
{
    <#
        .SYNOPSIS
            Converts morse code to text.
    
        .LINK
            ConvertTo-MorseCode
    #>
    
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [String]$InputObject
    )
    
    Begin
    {
        # generated from convertto command:
        # $letters.Keys | sort | % { write-host ("'{0}' = '{1}'" -f $letters[$_], $_) }
        $letters = @{
            '.-' = 'A'
            '.--.-' = 'Á'
            '.-.-' = 'Ä'
            '-...' = 'B'
            '-.-.' = 'C'
            '----' = 'Ch'
            '-..' = 'D'
            '.' = 'E'
            '..-..' = 'É'
            '..-.' = 'F'
            '--.' = 'G'
            '....' = 'H'
            '..' = 'I'
            '.---' = 'J'
            '-.-' = 'K'
            '.-..' = 'L'
            '--' = 'M'
            '-.' = 'N'
            '--.--' = 'Ñ'
            '---' = 'O'
            '---.' = 'Ö'
            '.--.' = 'P'
            '--.-' = 'Q'
            '.-.' = 'R'
            '...' = 'S'
            '-' = 'T'
            '..-' = 'U'
            '..--' = 'Ü'
            '...-' = 'V'
            '.--' = 'W'
            '-..-' = 'X'
            '-.--' = 'Y'
            '--..' = 'Z'
        }
        $digits = @{
            '-----' = '0'
            '.----' = '1'
            '..---' = '2'
            '...--' = '3'
            '....-' = '4'
            '.....' = '5'
            '-....' = '6'
            '--...' = '7'
            '---..' = '8'
            '----.' = '9'
        }
        $punc = @{
            '.----.' = "'"
            '-....-' = '-'
            '.-..-.' = '"'
            '-.--.-' = '('
            '--..--' = ','
            '.-.-.-' = '.'
            '-..-.' = '/'
            '---...' = ':'
            '..--..' = '?'
            '.--.-.' = '@'
            '-...-' = '='
        }
        $prosign = @{
            #!XX = morse, subschar
            'AA' = '.-.-'
            'AR' = '.-.-.'
            'AS' = '.-...'
            'BK' = '-...-.-'
            'BT' = '-...-'
            'CL' = '-.-..-..'
            'CT' = '-.-.-'
            'DO' = '-..---'
            'KN' = '-.--.'
            'SK' = '...-.-'
            'SN' = '...-.'
            'VE' = '...-.'
            'SOS' = '...---...'
        }
        $prosignInverse = @{
            '.-.-' = 'Newline'
            '.-.-.' = 'End'
            '.-...' = 'Wait'
            '-...-.-' = 'Break'
            '-...-' = 'Paragraph'
            '-.-..-..' = 'Clear'
            '-.-.-' = 'Start copying'
            '-..---' = 'Switch to Wabun code'
            '-.--.' = 'Invite transmit'
            '...-.-' = 'End transmit'
            '...-.' = 'Understood'
            '...---...' = 'Distress'
        }
        $phrase = @{
            'over' = 'K'
            'roger' = 'R'
            'see you later' = 'CUL'
            'be seeing you' = 'BCNU'
            "you're" = 'UR'
            'signal report' = 'RST'
            'best regards' = '73'
            'loves and kisses' = '88'
        }
        $qcode = @{
            'i acknowledge receipt' = 'QSL'
            'do you acknowledge?' = 'QSL?'
            'wait' = 'QRX'
            'should i wait?' = 'QRX?'
            'ready to copy' = 'QRV'
            'ready to copy?' = 'QRV?'
            'frequency in use' = 'QRL'
            'frequency in use?' = 'QRL?'
            'my location is' = 'QTH'
            'your location?' = 'QTH?'
        }
        $letterSeparator = '   '
        $wordSeparator = '       '
    }
    
    Process
    {
        [String[]]$output = @()
        
        # trim ENDOFMESSAGE AR
        If ($InputObject.EndsWith($prosign['AR']))
        {
            $InputObject = $InputObject.Substring(0, $InputObject.Length - $prosign['AR'].Length)
        }
        Else
        {
            Write-Warning 'End of message terminator not found.'
        }
        
        ForEach ($codeLine in ($InputObject -split ($wordSeparator + $prosign['AA'])))
        {
            If ($codeLine -eq '') { Continue }
            
            $line = ''
            ForEach ($word in ($codeLine -split ($wordSeparator)))
            {
                # a word may be a prosign
                If ($prosignInverse.ContainsKey($word))
                {
                    $line += ('[' + $prosignInverse[$word] + '] ')
                    Continue
                }
                
                # not a prosign
                $word -split ($letterSeparator) | ForEach-Object {
                    [String]$codeChar = $_
                    
                    If ($letters.ContainsKey($codeChar))
                    {
                        $line += $letters[$codeChar]
                    }
                    ElseIf ($digits.ContainsKey($codeChar))
                    {
                        $line += $digits[$codeChar]
                    }
                    ElseIf ($punc.ContainsKey($codeChar))
                    {
                        $line += $punc[$codeChar]
                    }
                    Else
                    {
                        Write-Verbose "Ignoring unknown character code: '$codeChar'."
                    }
                }
                
                # space between words
                $line += ' '
            }
            
            # append. remove last space
            $output += $line.Substring(0, $line.Length - 1)
        }
        
        Return $output
    }
}

Function Start-PlayMorseCode
{
    <#
        .SYNOPSIS
            Plays morse code on the board speaker.
    
        .PARAMETER TimeUnit
            The smallest time unit in milliseconds. This is the period for a dot '.' or silence.
    
            This parameter will determine how fast the morse code will be played.
    
        .PARAMETER Frequency
            Sets the speaker frequency. Higher freqency will dim down faster over distance.
    #>
    
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ParameterSetName = 'FromContent')]
        [Byte[]]$InputObject,
    
        [Parameter(Mandatory = $false)]
        [ValidateRange(50, 500)]
        [Int32]$TimeUnit = 125,
    
        [Parameter(Mandatory = $false)]
        [ValidateRange(37, 32767)]
        [Int32]$Frequency = 500
    
    )
    
    Process
    {
        $InputObject | ForEach-Object {
            If ($_ -ne 0)
            {
                [Console]::Beep($Frequency, $TimeUnit)
            }
            Else
            {
                Start-Sleep -Milliseconds $TimeUnit
            }
        }
    }
}