///|
async fn read_text(path : String) -> String {
  try {
    if path.contains_char('\u0000') {
      raise usage("input path contains NUL")
    }
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    if file.kind() != Regular {
      raise usage("input must be a regular file")
    }
    let size = file.size()
    if size < 0L || size > 16777216L {
      raise usage("input exceeds 16 MiB limit")
    }
    let bytes = file.read_exactly_at(size.to_int(), position=0L)
    if file.size() != size {
      raise usage("input length changed while being read")
    }
    @utf8.decode(bytes) catch {
      _ => raise usage("input is not valid UTF-8")
    }
  } catch {
    @liberty.LibertyError(code, message, position) =>
      raise @liberty.LibertyError(code, path + ": " + message, position)
    error => raise usage(path + ": " + error.to_string())
  }
}

///|
async fn load_file(path : String) -> @liberty.Library {
  let text = read_text(path)
  @liberty.load_library(text) catch {
    @liberty.LibertyError(code, message, position) =>
      raise @liberty.LibertyError(code, path + ": " + message, position)
  }
}

///|
fn random_suffix(bytes : Bytes) -> String {
  let alphabet = "0123456789abcdef"
  let out = StringBuilder()
  for byte in bytes {
    let value = byte.to_int()
    out.write_stringview(alphabet[value / 16:value / 16 + 1])
    out.write_stringview(alphabet[value % 16:value % 16 + 1])
  }
  out.to_string()
}

///|
async fn write_text(path : String, text : String, force : Bool) -> Unit {
  if path.is_empty() || path.contains_char('\u0000') {
    raise usage("invalid output path")
  }
  let bytes = @utf8.encode(text)
  if bytes.length() > 67108864 {
    raise usage("output exceeds 64 MiB limit")
  }
  if !force && @fs.exists(path) {
    raise usage("output exists; pass --force to replace: " + path)
  }
  let nonce = match @env.rand(12) {
    Some(bytes) => random_suffix(bytes)
    None => raise usage("secure temporary-name entropy unavailable")
  }
  let temporary = path + ".moonliberty-" + nonce + ".tmp"
  let mut created = false
  try {
    {
      let file = @fs.create(temporary, allow_existing=false, permission=0o644)
      created = true
      defer file.close()
      file.write(bytes)
      file.sync()
    }
    @fs.rename(temporary, path, replace=force)
  } catch {
    error => {
      try {
        if created && @fs.exists(temporary) {
          @fs.remove(temporary)
        }
      } catch {
        _ => ()
      }
      raise usage("cannot write " + path + ": " + error.to_string())
    }
  }
}
