## HMAC secret key generator for nitter
## TODO: Test
## TODO: Add to nitter-service.nix

import std/[
  os,
  sysrand,
  strformat,
  strutils
]
import base32

template withFile(f: File, body: untyped) =
  try:
    body
  finally:
    f.close()

func toByteSeq*(str: string): seq[byte] {.inline.} =
  ## Converts a string to the corresponding byte sequence.
  @(str.toOpenArrayByte(0, str.high))

func toString*(bytes: openArray[byte]): string {.inline.} =
  ## Converts a byte sequence to the corresponding string.
  let length = bytes.len
  if length > 0:
    result = newString(length)
    copyMem(result.cstring, bytes[0].unsafeAddr, length)

proc main() =
  let 
    params = commandLineParams()
    config_filename = params[0]
    state_dir = getEnv "STATE_DIRECTORY"
    secret_filename = state_dir / "hmac"
    nitter_conf_filename = state_dir / "nitter.conf"

  var 
    secret: string
    secret_file: File

  if not existsFile(secret_filename):
    secret = urandom(32).encode()
    secret_file = open(secret_filename, fmWrite)

    withFile secret_file:
      secret_file.write(secret)
  else:
    secret_file = open(secret_filename, fmRead) 
    withFile secret_file:
      secret = secret_file.readAll()
  
  let 
    config_file = open(config_filename)    
    nitter_conf_file = open(nitter_conf_filename, fmWrite)
  
  withFile config_file:
    withFile nitter_conf_file:
      let 
        old_config = config_file.readAll()
        secret_str = secret 
        new_config = old_config.replace("@hmac@", secret_str)

      nitter_conf_file.write(new_config)

when isMainModule:
  main()