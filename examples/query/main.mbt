///|
async fn main {
  let file = @fs.open("tests/fixtures/ihp-sg13g2-typ.lib", mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if size < 0L || size > 16777216L {
    abort("fixture exceeds input budget")
  }
  let text = @utf8.decode(file.read_exactly_at(size.to_int(), position=0L))
  let library = @liberty.load_library(text) catch {
    error => abort(error.render())
  }
  let findings = @liberty.lint_library(library)
  @stdio.stdout.write(@liberty.lint_json(library).stringify(indent=2) + "\n")
  if findings.any(f => f.severity is Error) {
    abort("real library has lint errors")
  }
  let query = @liberty.query_timing(
    library, "sg13g2_inv_1", "Y", "A", "cell_rise", 1.0e-10, 2.0e-14,
  ) catch {
    error => abort(error.render())
  }
  @stdio.stdout.write(@liberty.query_json(query).stringify(indent=2) + "\n")
}
