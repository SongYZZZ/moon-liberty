///|
fn parse_error(
  text : String,
  limits~ : @liberty.Limits = @liberty.Limits::default(),
) -> String raise {
  try @liberty.parse_liberty(text, limits~) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected parser rejection")
  }
}

///|
test "named root and empty cell parse" {
  let root = @liberty.parse_liberty("library (chip) { cell (INV) {} }")
  assert_eq(root.name(), "chip")
  assert_eq(root.groups("cell")[0].name(), "INV")
}

///|
test "quoted group names preserve spaces and punctuation" {
  assert_eq(
    @liberty.parse_liberty("library (\"chip: typical\") {}").name(),
    "chip: typical",
  )
}

///|
test "simple quoted and numeric attributes remain distinguishable" {
  let root = @liberty.parse_liberty(
    "library (x) { a : \"1ns\"; b : -1.25e-3; }",
  )
  assert_true(root.attribute("a") is Some([@liberty.Text("1ns")]))
  assert_true(root.attribute("b") is Some([@liberty.Word("-1.25e-3")]))
}

///|
test "complex arguments are split at top-level commas only" {
  let root = @liberty.parse_liberty("library(x) { f(\"1, 2\", nested(a,b)); }")
  guard root.complex("f") is Some(args) else { fail("missing call") }
  assert_eq(args.length(), 2)
  assert_eq(@liberty.atoms_text(args[0]), "1, 2")
  assert_eq(@liberty.atoms_text(args[1]), "nested ( a , b )")
}

///|
test "unknown vendor groups and attributes are retained" {
  let root = @liberty.parse_liberty("library(x){ vendor(z){ mystery: true; } }")
  assert_eq(root.groups("vendor")[0].text("mystery"), Some("true"))
}

///|
test "nested cell pin and timing group hierarchy is retained" {
  let root = @liberty.parse_liberty(
    "library(x){cell(A){pin(Y){timing(){related_pin:\"A\";}}}}",
  )
  assert_eq(
    root.groups("cell")[0].groups("pin")[0].groups("timing")[0].text(
      "related_pin",
    ),
    Some("A"),
  )
}

///|
test "empty complex arguments are accepted" {
  assert_true(
    @liberty.parse_liberty("library(x){ custom(); }").complex("custom")
    is Some([]),
  )
}

///|
test "an empty document cannot become an empty library" {
  assert_eq(parse_error("/* empty */"), "MissingLibrary")
}

///|
test "root attributes cannot masquerade as libraries" {
  assert_eq(parse_error("library : x;"), "InvalidRoot")
}

///|
test "root must actually be named library" {
  assert_eq(parse_error("cell(x){}"), "InvalidRoot")
}

///|
test "root requires exactly one atomic library name" {
  assert_eq(parse_error("library(){}"), "InvalidRoot")
  assert_eq(parse_error("library(a,b){}"), "InvalidRoot")
}

///|
test "multiple libraries are explicitly rejected" {
  assert_eq(parse_error("library(a){} library(b){}"), "MultipleRoots")
}

///|
test "quoted keywords cannot become syntax" {
  assert_eq(parse_error("\"library\"(x){}"), "ExpectedName")
}

///|
test "attributes require a semicolon" {
  assert_eq(parse_error("library(x){ area: 3 }"), "MissingSemicolon")
}

///|
test "complex attributes require a semicolon" {
  assert_eq(parse_error("library(x){ values(\"1\") }"), "ExpectedSymbol")
}

///|
test "empty attribute values are rejected" {
  assert_eq(parse_error("library(x){ area:; }"), "MissingValue")
}

///|
test "missing closing braces are diagnosed" {
  assert_eq(parse_error("library(x){cell(A){}"), "UnclosedGroup")
}

///|
test "unclosed argument lists are diagnosed" {
  assert_eq(parse_error("library(x"), "UnclosedArguments")
}

///|
test "empty complex argument slots are rejected" {
  assert_eq(parse_error("library(x){ f(,a); }"), "EmptyArgument")
  assert_eq(parse_error("library(x){ f(a,); }"), "EmptyArgument")
}

///|
test "braces cannot be hidden in arguments" {
  assert_eq(parse_error("library(x){ f({); }"), "InvalidArgument")
}

///|
test "unbalanced parentheses in attribute expressions are refused" {
  assert_eq(parse_error("library(x){ f: ( a; }"), "UnbalancedValue")
  assert_eq(parse_error("library(x){ f: a ); }"), "UnbalancedValue")
}

///|
test "depth and node limits are enforced independently" {
  assert_eq(
    parse_error("library(x){cell(A){pin(Y){}}}", limits={
      ..@liberty.Limits::default(),
      max_depth: 2,
    }),
    "DepthLimit",
  )
  assert_eq(
    parse_error("library(x){a:1;b:2;}", limits={
      ..@liberty.Limits::default(),
      max_nodes: 2,
    }),
    "NodeLimit",
  )
}

///|
test "group closing semicolon is tolerated" {
  assert_eq(
    @liberty.parse_liberty("library(x){cell(A){};};").groups("cell").length(),
    1,
  )
}

///|
test "unquoted bus ranges preserve names and write back without inserting spaces" {
  let root = @liberty.parse_liberty(
    "library(x){cell(C){bus(DATA){pin(DATA[7:0]){capacitance:1;}}}}",
  )
  let name = root.groups("cell")[0].groups("bus")[0].groups("pin")[0].name()
  assert_eq(name, "DATA[7:0]")
  assert_true(@liberty.write_liberty(root).contains("pin (DATA[7:0])"))
}

///|
test "quoted structural words are ordinary data" {
  let root = @liberty.parse_liberty(
    "library(x){ comment:\"library\"; f(\"}\",\";\"); }",
  )
  assert_eq(root.text("comment"), Some("library"))
}

///|
test "deterministic writer preserves syntax semantics on a second round trip" {
  let root = @liberty.parse_liberty(
    "library(x){cell(\"A B\"){pin(Y){function:\"A & !B\";} values(\"1, 2\",\"3, 4\");}}",
  )
  let text = @liberty.write_liberty(root)
  assert_eq(@liberty.write_liberty(@liberty.parse_liberty(text)), text)
}

///|
test "writer escapes quotes and backslashes without changing string values" {
  let root = @liberty.parse_liberty("library(x){comment:\"a\\\"b\\\\c\";}")
  let again = @liberty.parse_liberty(@liberty.write_liberty(root))
  assert_eq(again.text("comment"), root.text("comment"))
}

///|
test "writer does not discard unknown records" {
  let root = @liberty.parse_liberty(
    "library(x){ vendor(one,two){ note:\"kept\";} }",
  )
  assert_eq(
    @liberty.parse_liberty(@liberty.write_liberty(root)).groups("vendor")[0].name(),
    "",
  )
  assert_true(@liberty.write_liberty(root).contains("kept"))
}

///|
test "duplicate attributes remain visible for semantic diagnostics" {
  let root = @liberty.parse_liberty("library(x){area:1;area:2;}")
  assert_eq(root.items.length(), 2)
}

///|
test "quoted NUL is refused before parsing" {
  assert_eq(parse_error("library(x){comment:\"\u0000\";}"), "InvalidCharacter")
}

///|
test "writer rejects a caller constructed value that injects another attribute" {
  let root = @liberty.parse_liberty("library(x){a:1;}")
  let pos = root.position
  let forged = {
    ..root,
    items: [@liberty.Attribute("a", [@liberty.Word("1; injected: true")], pos)],
  }
  try @liberty.write_liberty(forged) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidAst")
  } noraise {
    _ => fail("injected field must be rejected")
  }
}

///|
test "writer rejects caller constructed multi token bare atom" {
  let root = @liberty.parse_liberty("library(x){a:1;}")
  let forged = {
    ..root,
    items: [
      @liberty.Attribute("a", [@liberty.Word("two words")], root.position),
    ],
  }
  try @liberty.write_liberty(forged) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidAst")
  } noraise {
    _ => fail("atom identity must be preserved")
  }
}

///|
test "writer rejects caller constructed attribute name injection" {
  let root = @liberty.parse_liberty("library(x){a:1;}")
  let forged = {
    ..root,
    items: [
      @liberty.Attribute("extra:1; a", [@liberty.Word("1")], root.position),
    ],
  }
  try @liberty.write_liberty(forged) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidAst")
  } noraise {
    _ => fail("name injection must be rejected")
  }
}

///|
test "writer retains nested complex call atoms and quoted punctuation" {
  let root = @liberty.parse_liberty(
    "library(x){f(nested(a,b),\"; injected:1\");}",
  )
  let written = @liberty.write_liberty(root)
  assert_eq(@liberty.write_liberty(@liberty.parse_liberty(written)), written)
}

///|
test "missing separator cannot merge two simple attributes" {
  assert_eq(
    parse_error("library(x){cell(C){area:1\n dont_use:false;}}"),
    "MissingSemicolon",
  )
}

///|
test "writer budget includes escaping delimiters and indentation exactly" {
  let root = @liberty.parse_liberty(
    "library(x){cell(C){a:\"\\\"\\\\\";f(1,2);}}",
  )
  let output = @liberty.write_liberty(root)
  let limits = {
    ..@liberty.Limits::default(),
    max_input_chars: output.length(),
  }
  assert_eq(@liberty.write_liberty(root, limits~), output)
  try
    @liberty.write_liberty(root, limits={
      ..limits,
      max_input_chars: output.length() - 1,
    })
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InputLimit")
  } noraise {
    _ => fail("rendered budget ignored")
  }
}

///|
test "caller constructed large values are bounded before rendering" {
  let root = @liberty.parse_liberty("library(x){}")
  let large = {
    ..root,
    items: [
      @liberty.Attribute("a", [@liberty.Text("a".repeat(1000))], root.position),
    ],
  }
  try
    @liberty.write_liberty(large, limits={
      ..@liberty.Limits::default(),
      max_input_chars: 50,
    })
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InputLimit")
  } noraise {
    _ => fail("caller AST escaped output budget")
  }
}

///|
test "numeric attributes continued without preceding whitespace roundtrip" {
  for newline in ["\n", "\r\n"] {
    let root = @liberty.parse_liberty(
      "library(x){cell(C){area:1\\" + newline + ";}}",
    )
    assert_eq(root.groups("cell")[0].text("area"), Some("1"))
    let rendered = @liberty.write_liberty(root)
    assert_eq(
      @liberty.parse_liberty(rendered).groups("cell")[0].text("area"),
      Some("1"),
    )
  }
}

///|
test "leading BOM loads normally and deterministic output omits the signature" {
  let library = @liberty.load_library("\uFEFFlibrary(x){cell(C){area:1;}}")
  assert_eq(library.cells[0].area, Some(1.0))
  let rendered = @liberty.write_liberty(library.source)
  assert_true(rendered.has_prefix("library"))
  assert_eq(@liberty.load_library(rendered).cells[0].area, Some(1.0))
}
