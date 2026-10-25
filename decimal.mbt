///|
/// Exact decimal identity for audit only. It never rounds through binary floats.
/// Extremely large exponents fall back to original spelling instead of overflowing.
fn decimal_identity(text : String) -> String? {
  if text.is_empty() {
    return None
  }
  let mut i = 0
  let negative = text[0] == 45
  if text[0] == 43 || text[0] == 45 {
    i += 1
  }
  let digits = StringBuilder()
  let mut seen_digit = false
  let mut point = false
  let mut fractional = 0
  while i < text.length() {
    let c = text[i]
    if c >= 48 && c <= 57 {
      seen_digit = true
      digits.write_stringview(text[i:i + 1])
      if point {
        fractional += 1
      }
    } else if c == 46 && !point {
      point = true
    } else {
      break
    }
    i += 1
  }
  if !seen_digit {
    return None
  }
  let mut exponent = 0
  if i < text.length() && (text[i] == 101 || text[i] == 69) {
    i += 1
    let mut exponent_negative = false
    if i < text.length() && (text[i] == 43 || text[i] == 45) {
      exponent_negative = text[i] == 45
      i += 1
    }
    let begin = i
    while i < text.length() && text[i] >= 48 && text[i] <= 57 {
      if exponent > 1000000 {
        return None
      }
      exponent = exponent * 10 + text[i].to_int() - 48
      i += 1
    }
    if i == begin {
      return None
    }
    if exponent_negative {
      exponent = -exponent
    }
  }
  if i != text.length() {
    return None
  }
  let coefficient = digits.to_string()
  let mut first = 0
  while first < coefficient.length() && coefficient[first] == 48 {
    first += 1
  }
  if first == coefficient.length() {
    return Some("0")
  }
  let mut last = coefficient.length()
  while last > first && coefficient[last - 1] == 48 {
    last -= 1
  }
  exponent = exponent - fractional + coefficient.length() - last
  Some(
    (if negative { "-" } else { "" }) +
    coefficient[first:last].to_owned() +
    "e" +
    exponent.to_string(),
  )
}
