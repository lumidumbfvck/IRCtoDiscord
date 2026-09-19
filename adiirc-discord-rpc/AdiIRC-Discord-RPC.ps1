# AdiIRC -> Discord Rich Presence bridge
# Requires Windows PowerShell 5.1+ (included with Windows 10/11).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $Root 'config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$listenPort = [int]$config.listenPort
$clientId = [string]$config.clientId
$activityName = [string]$config.activityName
$maxStateLength = [int]$config.maxStateLength
$maxServers = [int]$config.maxServers
$maxChannelsPerServer = [int]$config.maxChannelsPerServer

if ([string]::IsNullOrWhiteSpace($clientId) -or $clientId -eq 'PASTE_YOUR_DISCORD_APPLICATION_ID_HERE') {
    Write-Host 'Set clientId in config.json first.' -ForegroundColor Yellow
    exit 2
}

$script:DiscordPipe = $null
$script:CurrentPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
$script:Nick = ''
$script:Servers = [ordered]@{}
$script:LastPayloadKey = ''

function Write-ExactBytes([System.IO.Stream]$stream, [byte[]]$bytes) {
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

function Read-ExactBytes([System.IO.Stream]$stream, [int]$count) {
    $buffer = New-Object byte[] $count
    $offset = 0
    while ($offset -lt $count) {
        $n = $stream.Read($buffer, $offset, $count - $offset)
        if ($n -le 0) { throw 'Discord IPC pipe closed.' }
        $offset += $n
    }
    return $buffer
}

function Send-IpcPacket([int]$opcode, [string]$json) {
    if ($null -eq $script:DiscordPipe -or -not $script:DiscordPipe.IsConnected) { return $false }
    $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
    $header = New-Object byte[] 8
    [Array]::Copy([BitConverter]::GetBytes([int32]$opcode), 0, $header, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes([int32]$payload.Length), 0, $header, 4, 4)
    try {
        Write-ExactBytes $script:DiscordPipe $header
        Write-ExactBytes $script:DiscordPipe $payload
        return $true
    } catch {
        Close-Discord
        return $false
    }
}

function Read-IpcPacket {
    if ($null -eq $script:DiscordPipe -or -not $script:DiscordPipe.IsConnected) { return $null }
    try {
        $script:DiscordPipe.ReadTimeout = 1500
        $header = Read-ExactBytes $script:DiscordPipe 8
        $opcode = [BitConverter]::ToInt32($header, 0)
        $length = [BitConverter]::ToInt32($header, 4)
        if ($length -lt 0 -or $length -gt 1048576) { throw 'Invalid Discord IPC packet length.' }
        $body = Read-ExactBytes $script:DiscordPipe $length
        $json = [System.Text.Encoding]::UTF8.GetString($body)
        return @{ Opcode = $opcode; Json = $json }
    } catch [System.TimeoutException] {
        return $null
    } catch {
        Close-Discord
        return $null
    }
}

function Close-Discord {
    if ($null -ne $script:DiscordPipe) {
        try { $script:DiscordPipe.Dispose() } catch {}
    }
    $script:DiscordPipe = $null
}

function Connect-Discord {
    Close-Discord
    for ($i = 0; $i -le 9; $i++) {
        $pipe = $null
        try {
            $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', "discord-ipc-$i", [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::None)
            $pipe.Connect(250)
            $pipe.ReadMode = [System.IO.Pipes.PipeTransmissionMode]::Byte
            $script:DiscordPipe = $pipe
            $handshake = @{ v = 1; client_id = $clientId } | ConvertTo-Json -Compress
            if (-not (Send-IpcPacket 0 $handshake)) { continue }
            [void](Read-IpcPacket)
            return $true
        } catch {
            if ($null -ne $pipe) { try { $pipe.Dispose() } catch {} }
            $script:DiscordPipe = $null
        }
    }
    return $false
}

function Get-ActivityState {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($serverName in $script:Servers.Keys) {
        $channels = @($script:Servers[$serverName])
        if ($channels.Count -eq 0) { continue }
        $shown = @($channels | Select-Object -First $maxChannelsPerServer)
        $text = ($shown -join ' • ')
        if ($channels.Count -gt $shown.Count) { $text += " • +$($channels.Count - $shown.Count) more" }
        $parts.Add("$serverName: $text")
        if ($parts.Count -ge $maxServers) { break }
    }
    if ($parts.Count -eq 0) { return 'No channels joined' }
    $state = $parts -join '  |  '
    if ($state.Length -gt $maxStateLength) { $state = $state.Substring(0, $maxStateLength - 1).TrimEnd() + '…' }
    return $state
}

function Update-DiscordPresence {
    $state = Get-ActivityState
    $key = "$($script:Nick)|$state"
    if ($key -eq $script:LastPayloadKey -and $null -ne $script:DiscordPipe -and $script:DiscordPipe.IsConnected) { return }
    $script:LastPayloadKey = $key

    if ($null -eq $script:DiscordPipe -or -not $script:DiscordPipe.IsConnected) {
        if (-not (Connect-Discord)) { return }
    }

    $activity = [ordered]@{
        name = $activityName
        details = if ([string]::IsNullOrWhiteSpace($script:Nick)) { 'IRC' } else { $script:Nick }
        state = $state
    }
    $packet = [ordered]@{
        cmd = 'SET_ACTIVITY'
        args = [ordered]@{ pid = $script:CurrentPid; activity = $activity }
        nonce = [guid]::NewGuid().ToString()
    } | ConvertTo-Json -Compress -Depth 8

    if (Send-IpcPacket 1 $packet) { [void](Read-IpcPacket) }
}

function Clear-DiscordPresence {
    if ($null -ne $script:DiscordPipe -and $script:DiscordPipe.IsConnected) {
        $packet = [ordered]@{
            cmd = 'SET_ACTIVITY'
            args = [ordered]@{ pid = $script:CurrentPid; activity = $null }
            nonce = [guid]::NewGuid().ToString()
        } | ConvertTo-Json -Compress -Depth 8
        [void](Send-IpcPacket 1 $packet)
    }
}

function Apply-Message([string]$line) {
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    $p = $line.Split("`t", 2)
    switch ($p[0]) {
        'NICK' {
            if ($p.Count -ge 2) { $script:Nick = $p[1] }
        }
        'CLEAR' {
            $script:Servers = [ordered]@{}
        }
        'CHANNEL' {
            if ($p.Count -lt 2) { return }
            $q = $p[1].Split("`t", 2)
            if ($q.Count -lt 2) { return }
            $server = $q[0]
            $channel = $q[1]
            if ([string]::IsNullOrWhiteSpace($server)) { $server = 'IRC' }
            if (-not $script:Servers.Contains($server)) { $script:Servers[$server] = New-Object System.Collections.ArrayList }
            if ($script:Servers[$server] -notcontains $channel) { [void]$script:Servers[$server].Add($channel) }
        }
        'END' {
            Update-DiscordPresence
        }
        'CLEAR_ACTIVITY' {
            Clear-DiscordPresence
        }
    }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $listenPort)
$listener.Start()
Write-Host "AdiIRC Discord RPC bridge listening on 127.0.0.1:$listenPort"
Write-Host 'Leave this window running. Close it to stop the bridge.'

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $false, 4096, $true)
            while ($client.Connected) {
                $line = $reader.ReadLine()
                if ($null -eq $line) { break }
                Apply-Message $line
            }
            Clear-DiscordPresence
        } catch {
            # The AdiIRC connection was lost; wait for it to reconnect.
        } finally {
            try { $reader.Dispose() } catch {}
            try { $stream.Dispose() } catch {}
            try { $client.Close() } catch {}
            $script:Nick = ''
            $script:Servers = [ordered]@{}
            $script:LastPayloadKey = ''
            Clear-DiscordPresence
        }
    }
} finally {
    Clear-DiscordPresence
    Close-Discord
    $listener.Stop()
}
