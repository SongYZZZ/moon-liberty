///|
pub struct Config {
  command : String
  inputs : Array[String]
  options : Map[String, String]
  flags : Array[String]
}

///|
pub(all) enum Request {
  Help(String)
  Version
  Run(Config)
}

///|
fn usage(message : String) -> @liberty.LibertyError {
  @liberty.LibertyError("Usage", message, { offset: 0, line: 1, column: 1, })
}

///|
fn positive_integer(
  value : String,
  maximum : Int,
) -> Int raise @liberty.LibertyError {
  let start = if value.has_prefix("+") { 1 } else { 0 }
  if value.length() == start {
    raise usage("expected positive decimal integer <= \{maximum}")
  }
  for i = start; i < value.length(); i = i + 1 {
    if value[i] < 48 || value[i] > 57 {
      raise usage("expected positive decimal integer <= \{maximum}")
    }
  }
  let number = @liberty.finite_number(value)
  if number < 1.0 ||
    number > maximum.to_double() ||
    number != number.to_int().to_double() {
    raise usage("expected positive integer <= \{maximum}")
  }
  number.to_int()
}

///|
pub fn parse_arguments(
  args : Array[String],
) -> Request raise @liberty.LibertyError {
  if args.is_empty() || args[0] == "--help" || args[0] == "-h" {
    return Help("")
  }
  if args[0] == "--version" {
    return Version
  }
  let command = args[0]
  if ![
      "inspect", "lint", "query", "diff", "normalize", "extract", "truth", "compat",
      "expand",
    ].contains(command) {
    raise usage("unknown command: " + command)
  }
  let valued = [
    "--cell", "--pin", "--related", "--table", "--slew", "--load", "--policy", "--when",
    "--cells", "--output", "-o", "--max-changes", "--max-inputs", "--standard", "--sources",
  ]
  let options : Map[String, String] = Map([])
  let flags = []
  let inputs = []
  let mut literal = false
  let mut i = 1
  while i < args.length() {
    let argument = args[i]
    if literal {
      inputs.push(argument)
      i += 1
      continue
    }
    if argument == "--" {
      literal = true
      i += 1
      continue
    }
    if argument == "--help" || argument == "-h" {
      return Help(command)
    }
    let pair = argument.split_once("=")
    let key = match pair {
      Some((key, _)) => key.to_owned()
      None => argument
    }
    if valued.contains(key) {
      let key = if key == "-o" { "--output" } else { key }
      if options.contains(key) {
        raise usage("duplicate option: " + key)
      }
      let value = match pair {
        Some((_, value)) => value.to_owned()
        None => {
          i += 1
          if i >= args.length() || args[i].has_prefix("--") {
            raise usage("missing value for " + key)
          }
          args[i]
        }
      }
      if value.is_empty() {
        raise usage("empty value for " + key)
      }
      options[key] = value
    } else if key == "--json" || key == "--force" {
      if pair != None {
        raise usage("flag does not take a value: " + key)
      }
      if flags.contains(key) {
        raise usage("duplicate flag: " + key)
      }
      flags.push(key)
    } else if argument.has_prefix("-") {
      raise usage("unknown option: " + argument)
    } else {
      inputs.push(argument)
    }
    i += 1
  }
  let required = if command == "diff" { 2 } else { 1 }
  if inputs.length() != required {
    raise usage("\{command} needs \{required} input argument(s)")
  }
  let writes = command == "normalize" ||
    command == "extract" ||
    command == "expand"
  if writes && !options.contains("--output") {
    raise usage("use --output PATH for normalize/extract/expand")
  }
  if flags.contains("--force") && !writes {
    raise usage("--force only applies to normalize/extract/expand")
  }
  for key, _ in options {
    let allowed = match key {
      "--standard" | "--sources" => command == "compat" || command == "expand"
      "--output" => writes
      "--cells" => command == "extract"
      "--max-changes" => command == "diff"
      "--max-inputs" => command == "truth"
      _ => command == "query"
    }
    if !allowed {
      raise usage(key + " is not valid for " + command)
    }
  }
  if command == "compat" || command == "expand" {
    guard options.get("--standard") is Some(standard) else {
      raise usage("compat/expand requires --standard 2017.06")
    }
    ignore(@liberty.parse_standard(standard))
  }
  if command == "query" {
    for key in ["--cell", "--pin", "--related", "--table", "--slew", "--load"] {
      if !options.contains(key) {
        raise usage("query requires " + key)
      }
    }
    for key in ["--slew", "--load"] {
      if @liberty.finite_number(options[key]) < 0.0 {
        raise usage(key + " must be nonnegative")
      }
    }
    if options.get("--policy") is Some(policy) &&
      !["reject", "clamp", "extrapolate"].contains(policy) {
      raise usage("policy must be reject, clamp or extrapolate")
    }
  }
  if command == "extract" && !options.contains("--cells") {
    raise usage("extract requires --cells NAME,NAME")
  }
  if options.get("--max-changes") is Some(value) {
    ignore(positive_integer(value, 100000))
  }
  if options.get("--max-inputs") is Some(value) {
    ignore(positive_integer(value, 16))
  }
  Run({ command, inputs, options, flags, })
}

///|
pub fn help(command : String) -> String {
  let prefix = "MoonLiberty 0.4.2\n"
  let body = match command {
    "compat" =>
      "Usage: moon-liberty compat FILE --standard 2017.06 [--sources JSON] [--json]\nReport implemented format checks, roundtrip and evaluation coverage. No complete conformance claim.\n"
    "expand" =>
      "Usage: moon-liberty expand FILE --standard 2017.06 [--sources JSON] -o OUTPUT [--force] [--json]\nExpand include_file from an explicit JSON source-text map; no implicit file reads.\n"
    "inspect" =>
      "Usage: moon-liberty inspect FILE [--json]\nInventory cells, directly declared scalar pins (shared names expanded), arcs, tables and unit scales. Bus/bundle omissions are reported as warnings.\n"
    "lint" =>
      "Usage: moon-liberty lint FILE [--json]\nCheck model structure, references, functions and supported lookup tables. Exit 1 for findings at error level.\n"
    "query" =>
      "Usage: moon-liberty query FILE --cell NAME --pin NAME --related NAME --table KIND --slew SECONDS --load FARADS [--when EXACT_EXPR] [--policy reject|clamp|extrapolate] [--json]\nKIND: cell_rise, cell_fall, rise_transition, fall_transition. Defaults to refusing out-of-range or ambiguous queries.\n"
    "diff" =>
      "Usage: moon-liberty diff LEFT RIGHT [--max-changes N] [--json]\nCompare group/attribute semantics, numeric spelling and Boolean operators; unknown attributes remain visible. Exit 1 for changes. Not electrical equivalence or STA signoff.\n"
    "normalize" =>
      "Usage: moon-liberty normalize FILE -o OUTPUT [--force] [--json]\nDeterministic syntax serialization; does not certify semantic correctness.\n"
    "extract" =>
      "Usage: moon-liberty extract FILE --cells NAME,NAME -o OUTPUT [--force] [--json]\nKeep selected cells and all library-level context. Unknown cells are errors.\n"
    "truth" =>
      "Usage: moon-liberty truth EXPR [--max-inputs N] [--json]\nEvaluate a Liberty Boolean expression over all input assignments; default maximum inputs is 12.\n"
    _ =>
      "Usage: moon-liberty COMMAND [OPTIONS]\nCommands: inspect, lint, query, diff, normalize, extract, truth, compat, expand\nUse COMMAND --help. File writes require an explicit output and never overwrite without --force.\n"
  }
  prefix +
  body +
  "Exit 0: success/no differences; 1: lint/compat errors or diff changes; 2: usage, parsing, unsupported query or IO error.\n"
}
