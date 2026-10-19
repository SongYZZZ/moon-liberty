///|
async fn main {
  let path = "tests/fixtures/ihp-sg13g2-typ.lib"
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let length = file.size()
  if length < 0L || length > 16777216L {
    abort("fixture exceeds input budget")
  }
  let text = @utf8.decode(file.read_exactly_at(length.to_int(), position=0L))
  let library = @liberty.load_library(text) catch {
    error => abort(error.render())
  }
  @stdio.stdout.write(
    @liberty.inventory_json(library).stringify(indent=2) + "\n",
  )
}
