; AdiIRC -> Discord Rich Presence
; Shows only your nick and the IRC networks/channels you are currently in.
;
; Requires AdiIRC's scripting/socket support and the companion
; AdiIRC-Discord-RPC.ps1 helper listening on 127.0.0.1:48921.

alias adr_send {
  if (!$sock(ADIRPC)) {
    sockopen -4 ADIRPC 127.0.0.1 48921
    return
  }
  sockwrite -n ADIRPC $1-
}

alias adr_update {
  if (!$sock(ADIRPC)) {
    sockopen -4 ADIRPC 127.0.0.1 48921
    return
  }

  var %oldcid = $cid
  var %nick = $me

  sockwrite -n ADIRPC NICK $+ $chr(9) $+ %nick
  sockwrite -n ADIRPC CLEAR

  var %s = 1
  while (%s <= $scon(0)) {
    var %targetcid = $scon(%s)
    scon %targetcid

    if ($status == connected) {
      var %network = $network
      if (!%network) { %network = $server }

      var %i = 1
      while (%i <= $chan(0)) {
        if ($chan(%i).status == Joined) {
          if (%network) {
            sockwrite -n ADIRPC CHANNEL $+ $chr(9) $+ %network $+ $chr(9) $+ $chan(%i)
          }
        }
        inc %i
      }
    }

    inc %s
  }

  if (%oldcid) { scon %oldcid }
  sockwrite -n ADIRPC END
}


on *:START:{
  .timerADRPC_START 1 2 adr_update
}

on *:LOAD:{
  .timerADRPC_LOAD 1 2 adr_update
}

on *:CONNECT:{
  .timerADRPC_CONNECT 1 2 adr_update
}

on *:DISCONNECT:{
  if ($sock(ADIRPC)) {
    sockwrite -n ADIRPC CLEAR
  }
  .timerADRPC_DISCONNECT 1 1 adr_update
}

on *:JOIN:*:{
  if ($nick == $me) { adr_update }
}

on *:PART:*:{
  if ($nick == $me) { adr_update }
}

on *:KICK:*:{
  if ($knick == $me) { adr_update }
}

on *:NICK:{
  if ($nick == $me) { adr_update }
}

on *:QUIT:{
  if ($nick == $me) { adr_update }
}

on *:CLOSE:{
  .timerADRPC_CLOSE 1 1 adr_update
}

on *:SOCKOPEN:ADIRPC:{
  adr_update
}

on *:SOCKCLOSE:ADIRPC:{
  .timerADRPC_RECONNECT 1 2 adr_update
}
