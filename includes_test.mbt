///|
fn expanded(
  text : String,
  name : String,
  body : String,
) -> @liberty.Group raise @liberty.LibertyError {
  @liberty.parse_liberty_sources(text, Map([(name, body)]))
}

///|
fn include_error(
  text : String,
  sources : Map[String, String],
  limits? : @liberty.Limits = @liberty.Limits::default(),
) -> String raise {
  try @liberty.parse_liberty_sources(text, sources, limits~) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected include rejection")
  }
}

///|
test "include body is inserted at the statement location" {
  let root = expanded(
    "library(x){cell(C){include_file(pins);area:2;}}", "pins", "pin(A){direction:input;}pin(Y){direction:output;function:\"!A\";}",
  )
  assert_eq(root.groups("cell")[0].groups("pin").length(), 2)
  assert_eq(root.groups("cell")[0].text("area"), Some("2"))
}

///|
test "include preserves unknown fields and quoted names" {
  let root = expanded(
    "library(x){include_file(\"data.inc\");}", "data.inc", "vendor(foo){opaque:\"a;b{}\";}cell(\"C.1\"){}",
  )
  assert_eq(root.groups("vendor")[0].text("opaque"), Some("a;b{}"))
  assert_eq(root.groups("cell")[0].name(), "C.1")
}

///|
test "multiple includes may use the same source without mutation" {
  let root = expanded(
    "library(x){cell(A){include_file(p);}cell(B){include_file(p);}}", "p", "pin(X){direction:input;}",
  )
  assert_eq(root.groups("cell").map(g => g.groups("pin").length()), [1, 1])
}

///|
test "missing include source is never ignored" {
  assert_eq(
    include_error("library(x){include_file(missing);}", Map([])),
    "MissingInclude",
  )
}

///|
test "included files cannot themselves include another source" {
  assert_eq(
    include_error(
      "library(x){include_file(a);}",
      Map([("a", "include_file(b);"), ("b", "cell(C){}")]),
    ),
    "NestedInclude",
  )
}

///|
test "nested include hidden in a child group is rejected" {
  assert_eq(
    include_error(
      "library(x){include_file(a);}",
      Map([("a", "cell(C){include_file(a);}")]),
    ),
    "NestedInclude",
  )
}

///|
test "include fragments cannot close the containing group" {
  assert_eq(
    include_error(
      "library(x){cell(C){include_file(a);}}",
      Map([("a", "}cell(injected){")]),
    ),
    "ExpectedName",
  )
}

///|
test "include fragment must close all its own groups" {
  assert_eq(
    include_error("library(x){include_file(a);}", Map([("a", "cell(C){")])),
    "UnclosedGroup",
  )
}

///|
test "include cannot introduce another library root" {
  assert_eq(
    include_error("library(x){include_file(a);}", Map([("a", "library(y){}")])),
    "IncludeBoundary",
  )
}

///|
test "include takes one name only" {
  assert_eq(
    include_error("library(x){include_file(a,b);}", Map([])),
    "IncludeArguments",
  )
}

///|
test "include path traversal and absolute paths are rejected" {
  for name in ["../x", "a/b", "a\\b", "D:x", ".."] {
    let source = "library(x){include_file(\"" + name + "\");}"
    assert_eq(include_error(source, Map([])), "IncludeName")
  }
}

///|
test "include aggregate character budget includes repeated content" {
  let text = "library(x){include_file(a);include_file(a);}"
  let body = "cell(abcdefghijk){}"
  assert_eq(
    include_error(text, Map([("a", body)]), limits={
      ..@liberty.Limits::default(),
      max_input_chars: text.length() + body.length(),
    }),
    "InputLimit",
  )
}

///|
test "include expanded nesting respects caller depth" {
  assert_eq(
    include_error(
      "library(x){cell(C){include_file(a);}}",
      Map([("a", "pin(Y){timing(){}}")]),
      limits={ ..@liberty.Limits::default(), max_depth: 3, },
    ),
    "DepthLimit",
  )
}

///|
test "include aggregate nodes are bounded" {
  assert_eq(
    include_error(
      "library(x){include_file(a);include_file(a);}",
      Map([("a", "cell(A){}cell(B){}cell(C){}")]),
      limits={ ..@liberty.Limits::default(), max_nodes: 5, },
    ),
    "NodeLimit",
  )
}

///|
test "expanded output has no unresolved include and reparses" {
  let root = expanded("library(x){include_file(a);}", "a", "cell(A){}")
  let text = @liberty.write_liberty(root)
  assert_false(text.contains("include_file"))
  assert_eq(@liberty.parse_liberty(text).groups("cell").length(), 1)
}

///|
test "empty complete include fragment is allowed" {
  assert_eq(
    expanded("library(x){include_file(a);}", "a", "/*none*/").items.length(),
    0,
  )
}

///|
test "plain parser preserves an unresolved include as syntax" {
  assert_true(
    @liberty.parse_liberty("library(x){include_file(a);}").complex(
      "include_file",
    )
    is Some(_),
  )
}

///|
test "fragment parser supports simple complex and group statements" {
  assert_eq(
    @liberty.parse_fragment("a:1;define(foo,cell,string);cell(C){}").length(),
    3,
  )
}

///|
test "root and supplied include fragments each accept a leading BOM" {
  let text = "\uFEFFlibrary(x){include_file(c.inc);}"
  let body = "\uFEFFcell(C){area:1;vendor:\"a\uFEFFb\";}"
  let root = expanded(text, "c.inc", body)
  assert_eq(root.groups("cell")[0].text("vendor"), Some("a\uFEFFb"))
  assert_eq(root.groups("cell")[0].text("area"), Some("1"))
  assert_eq(
    include_error(text, Map([("c.inc", body)]), limits={
      ..@liberty.Limits::default(),
      max_input_chars: text.length() + body.length() - 1,
    }),
    "InputLimit",
  )
}
