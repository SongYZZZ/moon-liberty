///|
pub(all) enum TokenKind {
  Bare
  Quoted
  Symbol
  End
} derive(Eq, Debug)

///|
pub(all) struct Token {
  kind : TokenKind
  text : String
  position : Position
} derive(Eq, Debug)

///|
fn whitespace(code : UInt16) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13 || code == 12
}

///|
fn symbol(code : UInt16) -> Bool {
  [40, 41, 123, 125, 58, 59, 44].contains(code.to_int())
}

///|
priv struct Scanner {
  text : String
  limits : Limits
  mut index : Int32
  mut line : Int32
  mut column : Int32
}

///|
fn Scanner::position(self : Scanner) -> Position {
  { offset: self.index, line: self.line, column: self.column, }
}

///|
fn Scanner::advance(self : Scanner) -> Unit raise LibertyError {
  if self.text[self.index] == 0 {
    raise failure("InvalidCharacter", "NUL is not permitted", self.position())
  }
  if self.text[self.index] == 10 {
    self.line += 1
    self.column = 1
  } else {
    self.column += 1
  }
  self.index += 1
}

///|
fn Scanner::has(self : Scanner, first : UInt16, second : UInt16) -> Bool {
  self.index + 1 < self.text.length() &&
  self.text[self.index] == first &&
  self.text[self.index + 1] == second
}

///|
fn Scanner::skip(self : Scanner) -> Unit raise LibertyError {
  while self.index < self.text.length() {
    if whitespace(self.text[self.index]) {
      self.advance()
    } else if self.has(47, 47) {
      while self.index < self.text.length() && self.text[self.index] != 10 {
        self.advance()
      }
    } else if self.has(47, 42) {
      let pos = self.position()
      self.advance()
      self.advance()
      while self.index < self.text.length() && !self.has(42, 47) {
        self.advance()
      }
      if self.index == self.text.length() {
        raise failure("UnterminatedComment", "expected */", pos)
      }
      self.advance()
      self.advance()
    } else if self.text[self.index] == 92 &&
      self.index + 1 < self.text.length() &&
      (self.text[self.index + 1] == 10 || self.text[self.index + 1] == 13) {
      self.advance()
      if self.text[self.index] == 13 {
        self.advance()
        if self.index == self.text.length() || self.text[self.index] != 10 {
          raise failure(
            "InvalidContinuation",
            "CR continuation needs LF",
            self.position(),
          )
        }
      }
      self.advance()
    } else {
      break
    }
  }
}

///|
fn Scanner::quoted(self : Scanner) -> Token raise LibertyError {
  let pos = self.position()
  self.advance()
  let out = StringBuilder()
  let mut count = 0
  while self.index < self.text.length() {
    let code = self.text[self.index]
    if code == 0 {
      raise failure("InvalidCharacter", "NUL is not permitted", self.position())
    }
    if code == 34 {
      self.advance()
      return { kind: Quoted, text: out.to_string(), position: pos, }
    }
    if code == 10 || code == 13 {
      raise failure(
        "UnescapedNewline",
        "quoted newline needs continuation",
        self.position(),
      )
    }
    if code == 92 {
      self.advance()
      if self.index == self.text.length() {
        break
      }
      let escaped = self.text[self.index]
      if escaped == 0 {
        raise failure(
          "InvalidCharacter",
          "NUL is not permitted",
          self.position(),
        )
      }
      if escaped == 10 {
        self.advance()
        continue
      }
      if escaped == 13 {
        self.advance()
        if self.index == self.text.length() || self.text[self.index] != 10 {
          raise failure(
            "InvalidContinuation",
            "CR continuation needs LF",
            self.position(),
          )
        }
        self.advance()
        continue
      }
      if escaped == 34 || escaped == 92 {
        out.write_stringview(self.text[self.index:self.index + 1])
        self.advance()
      } else {
        // Preserve vendor/string escapes verbatim; do not silently reinterpret.
        out.write_string("\\")
        out.write_stringview(self.text[self.index:self.index + 1])
        self.advance()
        count += 1
      }
    } else {
      out.write_stringview(self.text[self.index:self.index + 1])
      self.advance()
    }
    count += 1
    if count > self.limits.max_token_chars {
      raise failure("TokenLimit", "quoted token too large", pos)
    }
  }
  raise failure("UnterminatedString", "expected closing quote", pos)
}

///|
pub fn tokenize(
  text : String,
  limits~ : Limits = Limits::default(),
) -> Array[Token] raise LibertyError {
  if limits.max_input_chars < 1 ||
    limits.max_tokens < 1 ||
    limits.max_token_chars < 1 ||
    limits.max_depth < 1 ||
    limits.max_depth > 512 ||
    limits.max_nodes < 1 {
    raise failure(
      "InvalidLimit",
      "limits must be positive; depth <= 512",
      no_position(),
    )
  }
  if text.length() > limits.max_input_chars {
    raise failure(
      "InputLimit",
      "input exceeds configured character limit",
      no_position(),
    )
  }
  // A leading Unicode encoding signature is transport metadata, not syntax.
  // It remains included in the input budget and original UTF-16 offsets.
  let start = if !text.is_empty() && text[0] == 0xFEFF { 1 } else { 0 }
  let scanner : Scanner = { text, limits, index: start, line: 1, column: 1, }
  let tokens = []
  while true {
    scanner.skip()
    if scanner.index == text.length() {
      break
    }
    if tokens.length() >= limits.max_tokens {
      raise failure(
        "TokenLimit",
        "token count exceeds limit",
        scanner.position(),
      )
    }
    let pos = scanner.position()
    let code = text[scanner.index]
    if code == 0 {
      raise failure("InvalidCharacter", "NUL is not permitted", pos)
    }
    if code == 34 {
      tokens.push(scanner.quoted())
    } else if symbol(code) {
      scanner.advance()
      tokens.push({
        kind: Symbol,
        text: text[pos.offset:scanner.index].to_owned(),
        position: pos,
      })
    } else {
      let mut brackets = 0
      while scanner.index < text.length() {
        let current = text[scanner.index]
        if whitespace(current) ||
          (symbol(current) && !(current == 58 && brackets > 0)) ||
          current == 34 ||
          scanner.has(92, 10) ||
          scanner.has(92, 13) ||
          scanner.has(47, 47) ||
          scanner.has(47, 42) {
          break
        }
        if current == 0 {
          raise failure(
            "InvalidCharacter",
            "NUL is not permitted",
            scanner.position(),
          )
        }
        if current == 91 {
          brackets += 1
        }
        if current == 93 && brackets > 0 {
          brackets -= 1
        }
        scanner.advance()
        if scanner.index - pos.offset > limits.max_token_chars {
          raise failure("TokenLimit", "bare token too large", pos)
        }
      }
      tokens.push({
        kind: Bare,
        text: text[pos.offset:scanner.index].to_owned(),
        position: pos,
      })
    }
  }
  tokens.push({ kind: End, text: "", position: scanner.position(), })
  tokens
}
