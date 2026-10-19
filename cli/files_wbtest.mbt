///|
async fn test_directory() -> String {
  let directory = "artifacts/test-files-" +
    random_suffix(@env.rand(12).unwrap())
  @fs.mkdir(directory, recursive=true)
  directory
}

///|
async test "staged writes refuse overwrite and preserve prior bytes" {
  let path = test_directory() + "/result.lib"
  write_text(path, "first", false)
  try write_text(path, "second", false) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "Usage")
    error => fail("unexpected error: " + error.to_string())
  } noraise {
    _ => fail("existing output replaced without force")
  }
  assert_eq(read_text(path), "first")
}

///|
async test "explicit force replaces only the designated output" {
  let directory = test_directory()
  let path = directory + "/result.lib"
  write_text(directory + "/other.lib", "keep", false)
  write_text(path, "before", false)
  write_text(path, "after", true)
  assert_eq(read_text(path), "after")
  assert_eq(read_text(directory + "/other.lib"), "keep")
}

///|
async test "invalid UTF-8 is refused before syntax parsing" {
  let path = test_directory() + "/bad.lib"
  {
    let file = @fs.create(path, allow_existing=false)
    defer file.close()
    file.write(b"\xFF")
  }
  try read_text(path) catch {
    @liberty.LibertyError(_, message, _) =>
      assert_true(message.contains("UTF-8"))
    error => fail(error.to_string())
  } noraise {
    _ => fail("invalid UTF-8 accepted")
  }
}

///|
async test "directory input and NUL paths are rejected" {
  for path in [test_directory(), "a\u0000b.lib"] {
    try read_text(path) catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "Usage")
      error => fail(error.to_string())
    } noraise {
      _ => fail("invalid file input accepted")
    }
  }
}

///|
async test "syntax diagnostics retain input path and source location" {
  let path = test_directory() + "/bad.lib"
  write_text(path, "library(x){\narea\n}", false)
  try load_file(path) catch {
    @liberty.LibertyError(_, message, position) => {
      assert_true(message.contains(path))
      assert_true(position.line >= 2)
    }
    error => fail(error.to_string())
  } noraise {
    _ => fail("invalid syntax accepted")
  }
}
