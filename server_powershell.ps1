$port=4444

# Create server
$endpoint = New-Object System.Net.IPEndPoint([System.Net.IpAddress]::Any, $port)
$listener = New-Object System.Net.Sockets.TcpListener($endpoint)
$listener.Start()
Write-Host 'Listening on port'$port'...'

# Wait for connection
$client = $listener.AcceptTcpClient()
$stream = $client.GetStream()
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
Write-Host [ -NoNewline;Write-Host * -Fore Green -NoNewline;Write-Host ] Connection established !

# Interact with the client
while($true) {
    $cmd = Read-Host
    $writer.WriteLine($cmd)
    $writer.Flush()
    if ($cmd -eq 'exit') {
        break
    }
    $output = $reader.ReadLine()
    echo $output
    ""
}

# Cleanup
$reader.Close()
$writer.Close()
$client.Close()
$listener.Stop()
